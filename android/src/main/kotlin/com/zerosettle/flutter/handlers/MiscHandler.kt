package com.zerosettle.flutter.handlers

import android.util.Log
import com.zerosettle.flutter.ext.sendError
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
 * | `fetchTransactionHistory`  | `not_implemented` (SDK returns raw JSON)     | **yes**         |
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
 * ## `fetchTransactionHistory` — `not_implemented` (force-unwrap blocker)
 *
 * The Dart wire is `Future<List<Map<String, dynamic>>>` with a
 * `result!.map(...)` force-unwrap. iOS returns
 * `[CheckoutTransaction].map { $0.toFlutterMap() }` — typed and parsed.
 * The Android SDK currently returns `Result<String>` (raw JSON, see
 * `ZeroSettle.fetchTransactionHistory()` at
 * `ZeroSettle-Android/core/src/main/kotlin/com/zerosettle/sdk/ZeroSettle.kt:342-346`,
 * docstring: "The typed model lands in a later phase").
 *
 * Returning `success(null)` would throw an uncatchable Dart `_TypeError`;
 * returning the raw JSON string as a Map would fail the cast in
 * `Map<String, dynamic>.from(e as Map)`. The honest answer is
 * `not_implemented` until the SDK lands the typed `CheckoutTransaction`
 * model and this handler can parse + encode it. Tracked as a deviation
 * from the F16 plan; commit message points at the SDK file:line.
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
            "handleUniversalLink" -> handleUniversalLink(result)
            "getRemoteConfig" -> result.success(null)
            "getDetectedJurisdiction" -> result.success(null)
            "getPendingCheckout" -> getPendingCheckout(result)
            "setBaseUrlOverride" -> setBaseUrlOverride(call, result)
            "trackEvent" -> result.success(null)
            "trackMigrationConversion" -> trackMigrationConversion(result)
            "resetMigrateTipState" -> result.success(null)
            "fetchTransactionHistory" -> fetchTransactionHistory(result)
            else -> return false
        }
        return true
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

    // ── fetchTransactionHistory (force-unwrap blocker — not_implemented) ─

    private fun fetchTransactionHistory(result: MethodChannel.Result) {
        // SDK returns Result<String> (raw JSON) — Dart expects
        // Future<List<Map<String, dynamic>>> with a force-unwrap on the
        // result. success(null) would NPE; returning the raw JSON String
        // would fail Dart's `Map<String, dynamic>.from(e as Map)` cast.
        // Tracked as a deviation from the F16 plan until the SDK lands the
        // typed CheckoutTransaction model (see ZeroSettle-Android
        // core/src/main/kotlin/com/zerosettle/sdk/ZeroSettle.kt:342-346,
        // docstring: "The typed model lands in a later phase").
        result.error(
            "not_implemented",
            "fetchTransactionHistory is pending the SDK's typed " +
                "CheckoutTransaction model. The current SDK surface returns " +
                "raw JSON (Result<String>) which the Dart wire " +
                "(Future<List<Map<String, dynamic>>>) cannot decode.",
            null,
        )
    }
}
