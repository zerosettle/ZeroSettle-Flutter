package com.zerosettle.flutter.handlers

import android.util.Log
import com.zerosettle.flutter.ext.fabricateCheckoutDidBeginEvent
import com.zerosettle.flutter.ext.fabricateCheckoutDidCancelEvent
import com.zerosettle.flutter.ext.fabricateCheckoutDidCompleteEvent
import com.zerosettle.flutter.ext.fabricateCheckoutDidFailEvent
import com.zerosettle.flutter.ext.sendError
import com.zerosettle.flutter.ext.toFlutterMap
import com.zerosettle.sdk.ZeroSettle
import com.zerosettle.sdk.models.ZeroSettleError
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.launch

/**
 * F10 — purchase + payment-sheet domain handler.
 *
 * Owns six methods Dart calls on the main `zerosettle` channel:
 *   - `purchase` — web checkout via Custom Tab; returns `CheckoutTransaction`
 *   - `purchaseViaPlayBilling` — Android peer of iOS `purchaseViaStoreKit`;
 *     routes through the Play Billing dialog and returns `CheckoutTransaction`
 *   - `purchaseViaStoreKit` — iOS-only; returns `not_implemented`
 *   - `presentPaymentSheet` — iOS-only; returns `not_implemented`
 *     (Android has no native payment sheet; web checkout is the only route)
 *   - `preloadPaymentSheet` — validates args then no-ops with `success(null)`
 *   - `warmUpPaymentSheet` — validates args then no-ops with `success(null)`
 *
 * Wire shapes mirror `ios/zerosettle/Sources/zerosettle/ZeroSettlePlugin.swift`
 * (cases at lines 462-571). Dart's parsers in
 * `lib/zerosettle_method_channel.dart` (lines 134-185) see one contract
 * regardless of platform.
 *
 * ## `purchase` — deferred-bridge SDK
 *
 * Phase 1 A2 changed `ZeroSettle.purchase(activity, productId)` to suspend
 * over the Custom Tab launch + deep-link return and return
 * `Result<CheckoutTransaction>`. This handler launches the call on
 * [HandlerDependencies.scope] and folds the Result into a Flutter wire
 * response. The intermediate `transactionId` is an implementation detail
 * (the SDK refetches the hydrated record before returning).
 *
 * ### F25 — checkout-event fabrication
 *
 * In addition to the wire response, the handler emits four fabricated
 * events on the `zerosettle/checkout_events` EventChannel via
 * [HandlerDependencies.checkoutEventEmitter]:
 *
 *   - `checkoutDidBegin` — synchronously, before the suspend purchase call.
 *     Adopters use it to show a spinner.
 *   - `checkoutDidComplete` — on `Result.success`, carries the full
 *     hydrated `CheckoutTransaction.toFlutterMap()`.
 *   - `checkoutDidCancel` — on `Result.failure(PurchaseCancelled)`.
 *   - `checkoutDidFail` — on any other `Result.failure` AND on unexpected
 *     SDK throws caught by the outer `runCatching`.
 *
 * Fabrication is the right strategy here (vs collecting `ZeroSettle.events`)
 * because the SDK's `PurchaseSucceeded` event carries only
 * `productId + transactionId`, but iOS's wire shape carries the full
 * hydrated `CheckoutTransaction`. Re-hydrating from the SDK event stream
 * would require an extra server round-trip; the handler already has the
 * transaction from `Result.success`. See `ext/EventToFlutterMap.kt` for
 * the wire-shape definitions.
 *
 * Concurrent calls fail with [com.zerosettle.sdk.models.ZeroSettleError.CheckoutInFlight] —
 * mapped to wire code `checkout_in_flight` via the shared `sendError`
 * extension (defined alongside F8). Dart adopters can pattern-match this
 * code to surface "another checkout already running" UX.
 *
 * ### Activity requirement
 *
 * `ZeroSettle.purchase` takes an `Activity` as its first arg — Custom Tab
 * launch from a non-Activity context throws `ActivityNotFoundException`.
 * If the plugin has no Activity attached (engine running headless or
 * post-detach), we error `activity_required` rather than passing through
 * to the SDK and surfacing a generic `sdk_error` from the exception.
 *
 * ### `presentation` arg — silently dropped
 *
 * iOS's `purchase()` accepts an optional `presentation: CheckoutType`
 * (raw string `"sheet"`/`"browser"`) that picks between the in-app sheet
 * and an external browser tab. The Android SDK has no equivalent knob —
 * the only checkout route is a Custom Tab (with `launchExternalBrowser`
 * fallback resolved server-side via `checkoutPresentation`). Dart's
 * `purchase({productId, presentation?})` keeps the iOS-shaped signature
 * for cross-platform code reuse, so we accept the arg without
 * validating its value. Logging on every call would be noisy and
 * uninformative — the contract is "iOS-only, drop on Android."
 *
 * ## `preloadPaymentSheet` / `warmUpPaymentSheet` — no-ops
 *
 * iOS implements both as in-app `CheckoutSheet.preload(...)` /
 * `CheckoutSheet.warmUp(...)` — these prime a hidden WebView so the
 * presentation tap shows content instantly. The Android SDK has no
 * runtime preload analogue; the only knob is configure-time
 * [com.zerosettle.sdk.ZeroSettleConfig.preloadCheckout] (driven by F8's
 * `configure` handler). Runtime preload calls are therefore best-effort
 * no-ops: validate `productId` (matching iOS's arg validation so a
 * caller who omits it sees the same `INVALID_ARGUMENTS` error on both
 * platforms), log once, then `result.success(null)`. This preserves the
 * iOS wire contract — preload is documented as an optimization hint,
 * not a requirement, so a no-op on Android is the right semantic.
 *
 * ## `purchaseViaStoreKit` / `presentPaymentSheet` — iOS-only
 *
 * `purchaseViaStoreKit` is the iOS peer of [purchaseViaPlayBilling]
 * (which D1 wires through to `ZeroSettle.purchaseViaPlayBilling`). The
 * Dart facade exposes both methods; each platform returns
 * `not_implemented` for the other's wire name. Returning `not_implemented`
 * lets Dart's `_wrap` surface a `PlatformException` adopters can
 * pattern-match on.
 *
 * `presentPaymentSheet` is the iOS-only imperative "show the in-app
 * sheet now" entry. Android has no native payment sheet — the only
 * checkout route is `purchase()` (web). Same `not_implemented` contract.
 *
 * ## `purchaseViaPlayBilling` — no checkout-event fabrication
 *
 * Unlike `purchase()` (web Custom Tab) we do NOT fabricate
 * `checkoutDidBegin/Complete/Cancel/Fail` events for the Play Billing
 * path. Parity is with iOS `purchaseViaStoreKit`, which also doesn't
 * emit those events — the checkout-event channel exists for the
 * web flow specifically (Custom Tab hides Flutter and the host needs
 * spinner/lifecycle signals). Play Billing's dialog drives its own
 * UX, same as StoreKit.
 */
internal class PurchaseHandler(private val deps: HandlerDependencies) {

    /**
     * Dispatch [call] if this handler owns its method. Returns `true` if
     * the call was consumed (a [result] callback has been issued or is
     * pending from a launched coroutine), `false` if the method is not in
     * this handler's surface so the plugin can fall through.
     */
    fun handle(call: MethodCall, result: MethodChannel.Result): Boolean {
        when (call.method) {
            "purchase" -> purchase(call, result)
            "purchaseViaPlayBilling" -> purchaseViaPlayBilling(call, result)
            "purchaseViaStoreKit" ->
                result.error(
                    "not_implemented",
                    "purchaseViaStoreKit is iOS-only; use purchaseViaPlayBilling() on Android",
                    null,
                )
            "presentPaymentSheet" ->
                result.error(
                    "not_implemented",
                    "presentPaymentSheet is iOS-only; Android uses web checkout via Custom Tabs",
                    null,
                )
            "preloadPaymentSheet" -> preloadPaymentSheet(call, result)
            "warmUpPaymentSheet" -> warmUpPaymentSheet(call, result)
            else -> return false
        }
        return true
    }

    // ── purchase ───────────────────────────────────────────────────────

    private fun purchase(call: MethodCall, result: MethodChannel.Result) {
        val productId = call.argument<String>("productId")
        if (productId == null) {
            result.error("INVALID_ARGUMENTS", "productId is required", null)
            return
        }
        // `presentation` arg is iOS-only — drop silently (see class doc).
        val activity = deps.activityProvider()
        if (activity == null) {
            // No checkout actually started — don't fabricate a begin or fail
            // event for this guard-path. Matches iOS, which never enters its
            // delegate path until the in-app sheet is presented.
            result.error(
                "activity_required",
                "Foreground Activity required for purchase (Custom Tab launch)",
                null,
            )
            return
        }
        // F25 — fabricate checkout-event lifecycle for the
        // `zerosettle/checkout_events` EventChannel. Begin fires synchronously
        // before the suspend purchase() so adopters can show a spinner; the
        // remaining three events fold off the SDK Result. The Android SDK's
        // `PurchaseSucceeded` event carries only productId+transactionId, but
        // iOS's `checkoutDidComplete` wire shape carries the full hydrated
        // CheckoutTransaction — fabrication from this handler's
        // `Result<CheckoutTransaction>` context matches the iOS shape exactly
        // (see `ext/EventToFlutterMap.kt`).
        deps.checkoutEventEmitter(fabricateCheckoutDidBeginEvent(productId))
        deps.scope.launch {
            val sdkResult = runCatching { ZeroSettle.purchase(activity, productId) }
            sdkResult.fold(
                onSuccess = { res ->
                    res.fold(
                        onSuccess = { transaction ->
                            deps.checkoutEventEmitter(
                                fabricateCheckoutDidCompleteEvent(transaction)
                            )
                            result.success(transaction.toFlutterMap())
                        },
                        onFailure = { err ->
                            // Cancel vs fail split matches iOS's
                            // checkoutDidCancel / checkoutDidFail delegate
                            // pair. Cancel carries productId only; fail
                            // carries productId + the localized error
                            // message (or class-name fallback).
                            if (err is ZeroSettleError.PurchaseCancelled) {
                                deps.checkoutEventEmitter(
                                    fabricateCheckoutDidCancelEvent(productId)
                                )
                            } else {
                                deps.checkoutEventEmitter(
                                    fabricateCheckoutDidFailEvent(productId, err)
                                )
                            }
                            result.sendError(err)
                        },
                    )
                },
                onFailure = { err ->
                    // Unexpected SDK throw — also fail to keep the channel
                    // event stream complete.
                    deps.checkoutEventEmitter(
                        fabricateCheckoutDidFailEvent(productId, err)
                    )
                    result.sendError(err)
                },
            )
        }
    }

    // ── purchaseViaPlayBilling ─────────────────────────────────────────

    private fun purchaseViaPlayBilling(call: MethodCall, result: MethodChannel.Result) {
        val productId = call.argument<String>("productId")
        if (productId == null) {
            result.error("INVALID_ARGUMENTS", "productId is required", null)
            return
        }
        val activity = deps.activityProvider()
        if (activity == null) {
            // Same guard as `purchase()` — the SDK's Play Billing launch
            // needs a foreground Activity to attach its dialog to.
            result.error(
                "activity_required",
                "Foreground Activity required for purchaseViaPlayBilling (Play Billing dialog launch)",
                null,
            )
            return
        }
        // No checkout-event fabrication on this path — see class doc.
        // Parity is with iOS `purchaseViaStoreKit`, not the web `purchase()`
        // flow that fires `checkoutDidBegin/Complete/Cancel/Fail`.
        deps.scope.launch {
            val sdkResult = runCatching {
                ZeroSettle.purchaseViaPlayBilling(activity, productId)
            }
            sdkResult.fold(
                onSuccess = { res ->
                    res.fold(
                        onSuccess = { transaction ->
                            result.success(transaction.toFlutterMap())
                        },
                        onFailure = { err -> result.sendError(err) },
                    )
                },
                onFailure = { err -> result.sendError(err) },
            )
        }
    }

    // ── preloadPaymentSheet (no-op with arg validation) ────────────────

    private fun preloadPaymentSheet(call: MethodCall, result: MethodChannel.Result) {
        val productId = call.argument<String>("productId")
        if (productId == null) {
            result.error("INVALID_ARGUMENTS", "productId is required", null)
            return
        }
        // No runtime preload on Android — see class doc. Log once at info
        // level so adopters can see the call landed but understand it's a
        // no-op. Configure-time preload runs via ZeroSettleConfig.preloadCheckout.
        Log.i(
            "ZeroSettle",
            "preloadPaymentSheet: no-op on Android (web checkout uses Custom Tabs; configure-time preloadCheckout drives prep)",
        )
        result.success(null)
    }

    // ── warmUpPaymentSheet (no-op with arg validation) ─────────────────

    private fun warmUpPaymentSheet(call: MethodCall, result: MethodChannel.Result) {
        val productId = call.argument<String>("productId")
        if (productId == null) {
            result.error("INVALID_ARGUMENTS", "productId is required", null)
            return
        }
        Log.i(
            "ZeroSettle",
            "warmUpPaymentSheet: no-op on Android (web checkout uses Custom Tabs; configure-time preloadCheckout drives prep)",
        )
        result.success(null)
    }
}
