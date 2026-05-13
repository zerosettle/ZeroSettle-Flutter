package com.zerosettle.flutter.handlers

import com.zerosettle.flutter.ext.sendError
import com.zerosettle.sdk.ZeroSettle
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.launch

/**
 * F12 — subscription management method-channel handler.
 *
 * Owns nine methods Dart calls on the main `zerosettle` channel. The 1.3.0
 * Kit dropped the customer-portal / manage-subscription surface and the
 * Save-the-Sale headless API was never exposed on Android per user
 * direction — so only three of the nine forward to a real SDK call; the
 * remaining six return `not_implemented` for parity with iOS.
 *
 * | Dart method                  | Android route                              |
 * | ---------------------------- | ------------------------------------------ |
 * | `cancelSubscription`         | `ZeroSettle.cancelSubscription(...)`       |
 * | `pauseSubscription`          | `ZeroSettle.pauseSubscription(...)`        |
 * | `resumeSubscription`         | `ZeroSettle.resumeSubscription(...)`       |
 * | `openCustomerPortal`         | `not_implemented` (matches iOS)            |
 * | `showManageSubscription`     | `not_implemented` (matches iOS)            |
 * | `acceptSaveOffer`            | `not_implemented` (Save-the-Sale iOS-only) |
 * | `submitCancelFlowResponse`   | `not_implemented` (Save-the-Sale iOS-only) |
 * | `getCancelFlowConfig`        | `not_implemented` (Save-the-Sale iOS-only) |
 * | `fetchCancelFlowConfig`      | `not_implemented` (Save-the-Sale iOS-only) |
 *
 * Wire shapes mirror `ios/zerosettle/Sources/zerosettle/ZeroSettlePlugin.swift`
 * (cases at lines 596-818). Dart's parsers in
 * `lib/zerosettle_method_channel.dart` (lines 212-421) see one contract
 * regardless of platform.
 *
 * ## `openCustomerPortal` / `showManageSubscription` — match iOS not_implemented
 *
 * Both APIs were removed from ZeroSettleKit when the cancel-flow headless
 * surface landed (see iOS dispatch at line 596-603: "openCustomerPortal /
 * showManageSubscription were removed; use presentCancelFlow for cancel,
 * or StoreKit directly for Apple billing management"). The Android SDK
 * never exposed an analogue either — there is no `ZeroSettle.openCustomerPortal`
 * or `ZeroSettle.showManageSubscription` method to forward to. We return
 * `not_implemented` so the wire contract is symmetric on both platforms.
 *
 * A Play-Store-subscriptions deep link (`https://play.google.com/store/account/subscriptions`)
 * is a possible future Android-only divergence, but that's a product call
 * that warrants its own task — not a silent add in F12.
 *
 * ## Save-the-Sale headless surface — iOS-only per user direction
 *
 * `acceptSaveOffer`, `submitCancelFlowResponse`, `getCancelFlowConfig`, and
 * `fetchCancelFlowConfig` are the headless save-the-sale API. Per the user
 * direction recorded in the F12 brief, save-the-sale is iOS-only on
 * Android — the Android SDK has no headless cancel-flow surface. These
 * four return `not_implemented` permanently, matching the iOS-only stub
 * pattern from F10's `purchaseViaStoreKit` / `presentPaymentSheet`.
 *
 * ## Mutation methods — suspend dispatch
 *
 * `cancelSubscription`, `pauseSubscription`, `resumeSubscription` all
 * suspend on the SDK side (POST + DataStore + entitlement poll restart).
 * They launch on [HandlerDependencies.scope] and fold the SDK
 * `Result` into a Flutter wire response via the shared `sendError`
 * extension defined alongside F8's [IdentityHandler].
 *
 * ## userId arg — silently dropped
 *
 * iOS's mutation methods accept an optional `userId` and route to a
 * userId-arg overload; the Android SDK only has the no-userId variants
 * (it resolves `currentUserId` internally via `currentUserIdOrNull()`).
 * Dart's `cancelSubscription({productId, userId, immediate})` keeps the
 * iOS-shaped signature for cross-platform code reuse; we accept the arg
 * without using it. If `currentUserId` is null the SDK returns
 * `Result.failure(UserNotIdentified)` — mapped to wire code
 * `user_not_identified` for Dart pattern-matching, identical UX to a
 * caller-supplied stale userId.
 *
 * ## `pauseSubscription` arg shape
 *
 * Dart sends `pauseDurationDays` (new) OR `pauseOptionId` (legacy 1.2.x
 * arg name treated as duration days for backward compat). iOS does the
 * same fallback at line 682; we mirror it. The SDK returns
 * `Result<String?>` — `resumesAt` is an already-formatted ISO-8601
 * timestamp from the backend (no `Date` to format like iOS), so the
 * String passes through to `result.success(...)` unchanged.
 */
internal class SubscriptionMgmtHandler(private val deps: HandlerDependencies) {

    /**
     * Dispatch [call] if this handler owns its method. Returns `true` if
     * the call was consumed (a [result] callback has been issued or is
     * pending from a launched coroutine), `false` if the method is not in
     * this handler's surface so the plugin can fall through.
     */
    fun handle(call: MethodCall, result: MethodChannel.Result): Boolean {
        when (call.method) {
            "cancelSubscription" -> cancelSubscription(call, result)
            "pauseSubscription" -> pauseSubscription(call, result)
            "resumeSubscription" -> resumeSubscription(call, result)
            "openCustomerPortal",
            "showManageSubscription" ->
                result.error(
                    "not_implemented",
                    "${call.method} was removed from ZeroSettleKit and has no Android analogue. " +
                        "Use presentCancelFlow for cancel, or open the Play Store subscriptions " +
                        "page directly from your app for billing management.",
                    null,
                )
            "acceptSaveOffer",
            "submitCancelFlowResponse",
            "getCancelFlowConfig",
            "fetchCancelFlowConfig" ->
                result.error(
                    "not_implemented",
                    "${call.method} is iOS-only; the headless save-the-sale surface is not " +
                        "exposed on Android per product decision.",
                    null,
                )
            else -> return false
        }
        return true
    }

    // ── cancelSubscription ─────────────────────────────────────────────

    private fun cancelSubscription(call: MethodCall, result: MethodChannel.Result) {
        val productId = call.argument<String>("productId")
        if (productId == null) {
            result.error("INVALID_ARGUMENTS", "productId is required", null)
            return
        }
        // iOS-only `userId` arg silently dropped — SDK uses internal
        // currentUserId; UserNotIdentified surfaces if no user identified.
        val immediate = call.argument<Boolean>("immediate") ?: false
        deps.scope.launch {
            val sdkResult = runCatching { ZeroSettle.cancelSubscription(productId, immediate) }
            sdkResult.fold(
                onSuccess = { res ->
                    res.fold(
                        onSuccess = { result.success(null) },
                        onFailure = { result.sendError(it) },
                    )
                },
                onFailure = { result.sendError(it) },
            )
        }
    }

    // ── pauseSubscription ──────────────────────────────────────────────

    private fun pauseSubscription(call: MethodCall, result: MethodChannel.Result) {
        val productId = call.argument<String>("productId")
        if (productId == null) {
            result.error("INVALID_ARGUMENTS", "productId is required", null)
            return
        }
        // Kit 1.3.0 takes `pauseDurationDays: Int?`. Accept either the new
        // arg name or the legacy `pauseOptionId` (treated as duration days
        // for backward compat with the old Flutter API surface) — mirrors
        // iOS dispatch at line 682.
        val pauseDurationDays = call.argument<Int>("pauseDurationDays")
            ?: call.argument<Int>("pauseOptionId")
        deps.scope.launch {
            val sdkResult = runCatching {
                ZeroSettle.pauseSubscription(productId, pauseDurationDays)
            }
            sdkResult.fold(
                onSuccess = { res ->
                    res.fold(
                        // SDK returns Result<String?> — resumesAt is an
                        // already-formatted ISO-8601 timestamp from the
                        // backend (no Date formatting needed unlike iOS).
                        onSuccess = { resumesAt -> result.success(resumesAt) },
                        onFailure = { result.sendError(it) },
                    )
                },
                onFailure = { result.sendError(it) },
            )
        }
    }

    // ── resumeSubscription ─────────────────────────────────────────────

    private fun resumeSubscription(call: MethodCall, result: MethodChannel.Result) {
        val productId = call.argument<String>("productId")
        if (productId == null) {
            result.error("INVALID_ARGUMENTS", "productId is required", null)
            return
        }
        deps.scope.launch {
            val sdkResult = runCatching { ZeroSettle.resumeSubscription(productId) }
            sdkResult.fold(
                onSuccess = { res ->
                    res.fold(
                        onSuccess = { result.success(null) },
                        onFailure = { result.sendError(it) },
                    )
                },
                onFailure = { result.sendError(it) },
            )
        }
    }
}
