package com.zerosettle.flutter.handlers

import android.util.Log
import com.zerosettle.flutter.ext.sendError
import com.zerosettle.flutter.ext.toFlutterMap
import com.zerosettle.flutter.ext.toFlutterUserOfferMap
import com.zerosettle.sdk.ZeroSettle
import com.zerosettle.sdk.models.UserOffer
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.launch

/**
 * F16 — miscellaneous method-channel handler.
 *
 * Owns nine methods Dart calls on the main `zerosettle` channel that don't
 * fit any of the prior domain handlers: deep-link handling, remote config,
 * jurisdiction detection, pending-checkout state, base URL override,
 * telemetry, migration-tip dismissal, and transaction history.
 *
 * Wire shapes are mirrored from `lib/zerosettle_method_channel.dart` and
 * `ios/zerosettle/Sources/zerosettle/ZeroSettlePlugin.swift`. The Android
 * SDK is *much* sparser than iOS for this group — only two of the nine
 * methods have a real underlying SDK surface (`getPendingCheckout` reads a
 * StateFlow; `trackMigrationConversion` posts to `/iap/migration-converted/`).
 * The other seven either don't exist on Android (`handleUniversalLink`,
 * `getRemoteConfig`, `getDetectedJurisdiction`, `trackEvent`,
 * `resetMigrateTipState`) or have a constructor-only counterpart
 * (`setBaseUrlOverride`) or sit behind an in-flight typed-model task
 * (`fetchTransactionHistory`).
 *
 * The "force-unwrap rule" applies (lifted from F15
 * [ApplePayStubsHandler]): any Dart `Future<NonNullable>` caller that
 * does `result!.map(...)` or `return result!;` MUST get either a real
 * value or a `not_implemented` error — `success(null)` would throw an
 * uncatchable `_TypeError` on the Dart side.
 *
 * | Dart method                | Android route                                | Force-unwrap? |
 * | -------------------------- | -------------------------------------------- | ------------- |
 * | `handleUniversalLink`      | `success(false)` (no SDK API)                | no (`?? false`) |
 * | `getRemoteConfig`          | `success(null)` (no SDK API)                 | no (Map?)       |
 * | `getDetectedJurisdiction`  | `success(null)` (no SDK API)                 | no (String?)    |
 * | `getPendingCheckout`       | `ZeroSettle.pendingCheckout.value`           | no (`?? false`) |
 * | `setBaseUrlOverride`       | log + `success(null)` (constructor-only)     | n/a             |
 * | `trackEvent`               | `success(null)` (no SDK API; Dart swallows)  | n/a             |
 * | `trackMigrationConversion` | `ZeroSettle.trackMigrationConversion(...)`   | n/a             |
 * | `resetMigrateTipState`     | `success(null)` (no SDK API)                 | n/a             |
 * | `fetchTransactionHistory`  | `ZeroSettle.fetchTransactionHistory()`        | no (typed list) |
 *
 * ## `handleUniversalLink` — false instead of true on Android
 *
 * iOS's `ZeroSettle.shared.handleUniversalLink(url)` is a deep-link router
 * for `/checkout-success` / `/checkout-cancel` paths that map back to the
 * in-flight checkout deferred. The Android SDK doesn't currently expose an
 * analogue — Android's web-checkout flow uses Custom Tabs + an explicit
 * scheme intent filter handled by `ZeroSettleHostActivity` (F5), not a
 * universal-link interception path. Returning `false` is the honest
 * answer: "I did not handle this URL." The Dart caller's `?? false`
 * unwrap tolerates this; the host app's deep-link router falls through to
 * its own handling.
 *
 * ## `getRemoteConfig` / `getDetectedJurisdiction` — `null` placeholder
 *
 * iOS surfaces `ZeroSettle.shared.remoteConfig` and `detectedJurisdiction`
 * for jurisdiction-aware UI gating (Korea, EU, etc.). The Android SDK
 * hasn't shipped these yet. Both Dart return types are nullable
 * (`Map<String, dynamic>?` / `String?`) so `success(null)` is in-contract
 * and Dart callers already gate on null. When the Android SDK adds these
 * APIs, this handler swaps the `null` returns for real values without
 * touching the wire.
 *
 * ## `setBaseUrlOverride` — log, don't silent no-op
 *
 * iOS exposes `ZeroSettle.baseURLOverride: URL?` as a `#if DEBUG`-gated
 * static setter — dev/staging override pointing at ngrok / local backend.
 * On Android, `ZeroSettleConfig.baseUrlOverride` is a constructor property
 * on the config passed to `ZeroSettle.configure(...)` — there's no
 * dynamic setter. Silently no-op'ing here is a footgun: a developer
 * points the wire at ngrok in test, sees `success(null)`, then can't
 * figure out why their build talks to prod. We log a clear `Log.i`
 * pointing developers to set it via the next `configure()` call.
 *
 * ## `trackEvent` — silent no-op, matches Dart's fire-and-forget
 *
 * Dart's `ZeroSettle.trackEvent(...)` wraps the platform call in a
 * `try { ... } catch (_) { /* silent */ }` block ("fire-and-forget
 * analytics" — see `lib/zerosettle.dart:847`). The Android SDK has no
 * public `trackEvent` / funnel-analytics surface. We return
 * `success(null)` so the Dart try/catch is a no-op rather than firing
 * a PlatformException that gets swallowed anyway — same net effect, but
 * cleaner wire log on the Flutter side. No arg validation (no SDK to
 * validate against).
 *
 * ## `trackMigrationConversion` — Android = Play, source baked in
 *
 * The Android SDK's `trackMigrationConversion(source: SourceStorefront)`
 * requires an explicit storefront enum because the Kit was designed
 * cross-platform from the start. On Android, the only migration source is
 * Play Billing — there's no StoreKit on Android. We always pass
 * `UserOffer.SourceStorefront.PLAY_STORE`. The Dart wire's
 * `userId` arg is silently dropped (Dart kept the arg for iOS parity;
 * Android SDK resolves currentUserId internally — same pattern as
 * `SubscriptionMgmtHandler.cancelSubscription`).
 *
 * Errors propagate via `sendError` — Dart's `_wrap` surfaces these as
 * `PlatformException`s callers can pattern-match.
 *
 * ## `resetMigrateTipState` — no-op (deliberately not `resetOfferDismissedState`)
 *
 * iOS has TWO distinct dismissal stores: `MigrationManager.resetDismissedState()`
 * (the Switch & Save tip) and `ZSOfferManagerStatics.resetDismissedState()`
 * (the offer-card surface). On Android, only `OfferDismissalStore` exists
 * (`ZeroSettle.resetOfferDismissedState()`, called by F19's
 * `OfferManagerStaticHandler`). Wiring this Dart method through to
 * `resetOfferDismissedState()` would conflate the two iOS surfaces and
 * accidentally reset offer dismissals on developers who only meant to
 * reset migration-tip state. No-op is honest. When the Android SDK adds
 * a migration-tip dismissal store, this handler swaps in.
 *
 * ## `fetchTransactionHistory` — typed list pass-through
 *
 * The Dart wire is `Future<List<Map<String, dynamic>>>` with a
 * `result!.map(...)` force-unwrap. iOS returns
 * `[CheckoutTransaction].map { $0.toFlutterMap() }`. The Android SDK
 * now returns `Result<List<CheckoutTransaction>>` (see
 * `ZeroSettle.fetchTransactionHistory()` in
 * `ZeroSettle-Android/core/src/main/kotlin/com/zerosettle/sdk/ZeroSettle.kt`),
 * so we just map each entry via [CheckoutTransaction.toFlutterMap] —
 * same shape as iOS. Failures (UserNotIdentified / NotConfigured /
 * BackendError) flow through `sendError` like every other suspend
 * handler in this file.
 */
internal class MiscHandler(private val deps: HandlerDependencies) {

    /**
     * Dispatch [call] if this handler owns its method. Returns `true` if
     * the call was consumed (a [result] callback has been issued or is
     * pending from a launched coroutine), `false` if the method is not in
     * this handler's surface so the plugin can fall through.
     */
    fun handle(call: MethodCall, result: MethodChannel.Result): Boolean {
        when (call.method) {
            "getSdkVersion" -> result.success(ZeroSettle.sdkVersion)
            "getIsUcbEnabled" -> result.success(ZeroSettle.isUcbEnabled.value)
            "releasePendingCheckout" -> {
                ZeroSettle.releasePendingCheckout()
                result.success(null)
            }
            "handleUniversalLink" -> handleUniversalLink(result)
            "getRemoteConfig" -> result.success(null)
            "getDetectedJurisdiction" -> result.success(null)
            "getPendingCheckout" -> getPendingCheckout(result)
            "setBaseUrlOverride" -> setBaseUrlOverride(call, result)
            "setEclAvailabilityOverride" -> setEclAvailabilityOverride(call, result)
            "setSwitchAndSaveTestMode" -> setSwitchAndSaveTestMode(call, result)
            "trackEvent" -> result.success(null)
            "trackMigrationConversion" -> trackMigrationConversion(result)
            "reportOfferViewed" -> reportOfferViewed(call, result)
            "resetMigrateTipState" -> result.success(null)
            "fetchTransactionHistory" -> fetchTransactionHistory(result)
            "fetchUserOffer" -> fetchUserOffer(result)
            else -> return false
        }
        return true
    }

    // ── setEclAvailabilityOverride ──────────────────────────────────────

    /**
     * Testing hook for the Switch & Save offer's ECL availability gate.
     * `true`/`false` forces [ZeroSettle.eclAvailabilityOverride]; a missing
     * `override` arg clears it (`null` → the real Play Billing query).
     *
     * Deprecated alongside the SDK property — Dart callers receive a deprecation
     * warning on `setEclAvailabilityOverride`. The bridge keeps forwarding so
     * existing apps that haven't migrated yet continue to work; new code should
     * use `setSwitchAndSaveTestMode` for end-to-end Switch & Save testing.
     */
    @Suppress("DEPRECATION") // bridge for the soft-deprecated Dart API
    private fun setEclAvailabilityOverride(call: MethodCall, result: MethodChannel.Result) {
        ZeroSettle.eclAvailabilityOverride = call.argument<Boolean>("override")
        result.success(null)
    }

    // ── setSwitchAndSaveTestMode ────────────────────────────────────────

    /**
     * Testing hook for the full Switch & Save flow. When `enabled` is `true`,
     * the entire flow runs on a non-ECL device — the Play ECL plumbing is
     * faked while the backend session mint and the web checkout run for real.
     * Also implies ECL-available, so the Switch & Save offer tip surfaces.
     */
    private fun setSwitchAndSaveTestMode(call: MethodCall, result: MethodChannel.Result) {
        ZeroSettle.switchAndSaveTestMode = call.argument<Boolean>("enabled") ?: false
        result.success(null)
    }

    // ── handleUniversalLink ────────────────────────────────────────────

    private fun handleUniversalLink(result: MethodChannel.Result) {
        // Android web-checkout uses Custom Tabs + an explicit scheme intent
        // filter (see ZeroSettleHostActivity / F5). There's no universal-link
        // interception path on the SDK. Return `false` so the Dart caller's
        // host-app router falls through to its own deep-link handling.
        result.success(false)
    }

    // ── getPendingCheckout (synchronous StateFlow read) ────────────────

    private fun getPendingCheckout(result: MethodChannel.Result) {
        // Mirrors iOS `ZeroSettle.shared.pendingCheckout` — both platforms
        // expose this as the canonical "is a web checkout in-flight?" flag.
        // StateFlow `.value` is non-suspending; no coroutine launch needed.
        result.success(ZeroSettle.pendingCheckout.value)
    }

    // ── setBaseUrlOverride (constructor-only on Android) ───────────────

    private fun setBaseUrlOverride(call: MethodCall, result: MethodChannel.Result) {
        val url = call.argument<String>("url")
        // iOS exposes this as a `#if DEBUG`-gated mutable static
        // (`ZeroSettle.baseURLOverride`). Android's `ZeroSettleConfig` is
        // immutable, so we stage the override in BaseUrlOverrideStore and
        // pick it up inside IdentityHandler.configure(). The Dart facade
        // documents the contract: setBaseUrlOverride must be called before
        // configure().
        BaseUrlOverrideStore.set(url)
        Log.i("ZeroSettle", "setBaseUrlOverride staged url=$url (applied on next configure())")
        result.success(null)
    }

    // ── trackMigrationConversion (suspend SDK call) ────────────────────

    private fun trackMigrationConversion(result: MethodChannel.Result) {
        // Dart's `userId` arg silently dropped — SDK uses internal
        // currentUserId; UserNotIdentified surfaces as wire code
        // `user_not_identified` via sendError. Same pattern as F12 cancel/pause/resume.
        //
        // Android = Play migration, always. iOS Kit's API has no source arg
        // because StoreKit is implicit there; Android SDK's API requires it
        // because the Kit was designed cross-platform.
        deps.scope.launch {
            val sdkResult = runCatching {
                ZeroSettle.trackMigrationConversion(
                    source = UserOffer.SourceStorefront.PLAY_STORE,
                )
            }
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

    // ── reportOfferViewed (fire-and-forget impression report) ──────────

    /**
     * Bridges the Dart `reportOfferViewed` call to the SDK's fire-and-forget
     * impression report. `productId` is resolved from the call args, falling
     * back to `ZeroSettle.currentOffer.value?.productId` so callers that rely
     * on the auto-resolved current offer don't have to pass it. If no product
     * can be resolved, we just `result.success(null)` (nothing to report).
     *
     * The SDK's [ZeroSettle.reportOfferViewed] is a plain (non-suspend) fun
     * that launches its own background work, so — unlike
     * [trackMigrationConversion] — there's no coroutine to launch here; we
     * call it directly, mirroring the synchronous `trackEvent` stub.
     */
    private fun reportOfferViewed(call: MethodCall, result: MethodChannel.Result) {
        val productId = call.argument<String>("productId")
            ?: ZeroSettle.currentOffer.value?.productId
        if (productId != null) {
            ZeroSettle.reportOfferViewed(
                productId = productId,
                variantId = call.argument<Int>("variantId"),
                flowType = call.argument<String>("flowType") ?: "migration",
            )
        }
        result.success(null)
    }

    // ── fetchUserOffer (Task 9) ────────────────────────────────────────

    private fun fetchUserOffer(result: MethodChannel.Result) {
        // SDK returns Result<UserOffer.Response>; encode via toFlutterUserOfferMap()
        // so the wire shape matches Dart's UserOfferResponse.fromMap.
        // UserNotIdentified / NotConfigured / BackendError → sendError.
        deps.scope.launch {
            val sdkResult = runCatching { ZeroSettle.fetchUserOffer() }
            sdkResult.fold(
                onSuccess = { res ->
                    res.fold(
                        onSuccess = { response ->
                            result.success(response.toFlutterUserOfferMap())
                        },
                        onFailure = { result.sendError(it) },
                    )
                },
                onFailure = { result.sendError(it) },
            )
        }
    }

    // ── fetchTransactionHistory (typed list pass-through) ──────────────

    private fun fetchTransactionHistory(result: MethodChannel.Result) {
        // SDK returns Result<List<CheckoutTransaction>>; encode each entry
        // via the existing toFlutterMap so the wire shape matches iOS.
        // UserNotIdentified / NotConfigured / BackendError → sendError.
        deps.scope.launch {
            val sdkResult = runCatching { ZeroSettle.fetchTransactionHistory() }
            sdkResult.fold(
                onSuccess = { res ->
                    res.fold(
                        onSuccess = { txns ->
                            result.success(txns.map { it.toFlutterMap() })
                        },
                        onFailure = { result.sendError(it) },
                    )
                },
                onFailure = { result.sendError(it) },
            )
        }
    }
}
