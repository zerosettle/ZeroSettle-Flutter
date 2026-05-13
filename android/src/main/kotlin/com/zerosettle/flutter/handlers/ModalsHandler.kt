package com.zerosettle.flutter.handlers

import com.zerosettle.flutter.ext.sendError
import com.zerosettle.flutter.ext.toFlutterMap
import com.zerosettle.sdk.ZeroSettle
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.launch

/**
 * F13 — modal-presentation method-channel handler.
 *
 * Owns three methods Dart calls on the main `zerosettle` channel:
 *
 * | Dart method                | Android route                                       |
 * | -------------------------- | --------------------------------------------------- |
 * | `presentCancelFlow`        | `not_implemented` (save-the-sale modal is iOS-only) |
 * | `presentUpgradeOffer`      | `not_implemented` (use OfferManager / MigrationTipView) |
 * | `fetchUpgradeOfferConfig`  | `ZeroSettle.fetchUpgradeOfferConfig(productId)`     |
 *
 * Wire shapes mirror `ios/zerosettle/Sources/zerosettle/ZeroSettlePlugin.swift`
 * — cases at lines 635-672 (`presentCancelFlow`) and 952-988
 * (`presentUpgradeOffer` / `fetchUpgradeOfferConfig`).
 *
 * ## `presentCancelFlow` / `presentUpgradeOffer` — not exposed on Android
 *
 * Neither method has an Android route today, but for different reasons:
 *
 *   - `presentCancelFlow` is the imperative save-the-sale modal — iOS-only
 *     forever per product decision. Adopters on Android either build their
 *     own cancel UX or fall back to the headless config fetch.
 *   - `presentUpgradeOffer` is being deprecated platform-wide. The canonical
 *     way to surface upgrade offers is the Unified Offer System
 *     (`OfferManager` headless API + `MigrationTipView` / `OfferTip`
 *     PlatformViews); the imperative one-shot API will not be exposed on
 *     Android.
 *
 * Both return `not_implemented` (rather than the tagged
 * `zerosettle_phase2_wip` task-ID error) so adopters get a deterministic
 * "won't ship" signal at the call site.
 *
 * ## `fetchUpgradeOfferConfig` — real SDK forward
 *
 * Pure backend fetch: `GET /v1/iap/upgrade-offer/?user_id=…[&product_id=…]`.
 * The handler forwards to `ZeroSettle.fetchUpgradeOfferConfig(productId)`
 * (which resolves `currentUserId` internally) and encodes via
 * `UpgradeOffer.Config.toFlutterMap()`.
 *
 * **Decode-fragility caveat.** The Android SDK's `UpgradeOffer.Config`
 * (`from_product_id` / `to_product_id` / `savings_percent` / `display`) is
 * the chunk-4 placeholder and may not decode today's backend response —
 * `UpgradeOffer.kt` carries a `TODO(chunk-5)` to align. When decode fails,
 * the SDK returns `Result.failure(NetworkError(...))` and the handler
 * surfaces it as wire code `network_error` via the shared `sendError`
 * extension. Wiring is correct; runtime success depends on chunk-5
 * landing. Tests cover both success and failure paths regardless.
 *
 * ## userId arg — silently dropped (matches F12)
 *
 * iOS's `fetchUpgradeOfferConfig` accepts an optional `userId` and routes
 * to a userId-arg overload; the Android SDK only has the no-userId variant
 * (`currentUserIdOrNull()` internally). Dart's
 * `fetchUpgradeOfferConfig({productId, userId})` keeps the iOS-shaped
 * signature for cross-platform code reuse; we accept the arg without using
 * it. If `currentUserId` is null the SDK returns
 * `Result.failure(UserNotIdentified)` — mapped to wire code
 * `user_not_identified` for Dart pattern-matching, identical UX to the
 * other F8–F12 mutation paths.
 */
internal class ModalsHandler(private val deps: HandlerDependencies) {

    /**
     * Dispatch [call] if this handler owns its method. Returns `true` if
     * the call was consumed (a [result] callback has been issued or is
     * pending from a launched coroutine), `false` if the method is not in
     * this handler's surface so the plugin can fall through.
     */
    fun handle(call: MethodCall, result: MethodChannel.Result): Boolean {
        when (call.method) {
            "presentCancelFlow" ->
                result.error(
                    "not_implemented",
                    "presentCancelFlow is not exposed on Android — the imperative " +
                        "save-the-sale modal is iOS-only per product decision. Adopters " +
                        "can use the headless config fetch (fetchCancelFlowConfig) and " +
                        "build their own UX, or omit cancel save-the-sale on Android.",
                    null,
                )
            "presentUpgradeOffer" ->
                result.error(
                    "not_implemented",
                    "presentUpgradeOffer is not exposed on Android — use OfferManager + " +
                        "MigrationTipView/OfferTip (the Unified Offer System) to surface upgrade " +
                        "offers. The imperative one-shot API is being deprecated platform-wide.",
                    null,
                )
            "fetchUpgradeOfferConfig" -> fetchUpgradeOfferConfig(call, result)
            else -> return false
        }
        return true
    }

    // ── fetchUpgradeOfferConfig ────────────────────────────────────────

    private fun fetchUpgradeOfferConfig(call: MethodCall, result: MethodChannel.Result) {
        // iOS plugin treats both `productId` and `userId` as optional. The
        // SDK reads `currentUserId` internally; iOS-only `userId` is
        // silently dropped (matches F12 pattern). `productId == null`
        // routes to "any in-app upgrade offer".
        val productId = call.argument<String>("productId")
        deps.scope.launch {
            val sdkResult = runCatching { ZeroSettle.fetchUpgradeOfferConfig(productId) }
            sdkResult.fold(
                onSuccess = { res ->
                    res.fold(
                        onSuccess = { config -> result.success(config.toFlutterMap()) },
                        onFailure = { result.sendError(it) },
                    )
                },
                onFailure = { result.sendError(it) },
            )
        }
    }
}
