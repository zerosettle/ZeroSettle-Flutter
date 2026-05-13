package com.zerosettle.flutter.handlers

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
 * | `presentCancelFlow`        | `not_implemented` (pending F6 Compose dispatch)     |
 * | `presentUpgradeOffer`      | `not_implemented` (pending F6 Compose dispatch)     |
 * | `fetchUpgradeOfferConfig`  | `ZeroSettle.fetchUpgradeOfferConfig(productId)`     |
 *
 * Wire shapes mirror `ios/zerosettle/Sources/zerosettle/ZeroSettlePlugin.swift`
 * — cases at lines 635-672 (`presentCancelFlow`) and 952-988
 * (`presentUpgradeOffer` / `fetchUpgradeOfferConfig`).
 *
 * ## `presentCancelFlow` / `presentUpgradeOffer` — pending F6, not iOS-only
 *
 * Unlike the F12 save-the-sale headless surface (`acceptSaveOffer`,
 * `submitCancelFlowResponse`, `getCancelFlowConfig`, `fetchCancelFlowConfig`)
 * which are iOS-only **forever** per product decision, these two modal
 * launches are tracked Android work blocked on Task F6 (Compose Mode
 * dispatch in `ZeroSettleHostActivity`).
 *
 * Both have:
 *   - **No Android SDK high-level method.** iOS Kit exposes
 *     `ZeroSettle.shared.presentCancelFlow(...) -> CancelFlow.Result` and
 *     `presentUpgradeOffer(...) -> UpgradeOffer.Result` as one-shot async
 *     methods. The Android SDK has only the *config-fetch* layer
 *     (`fetchCancelFlowConfig`, `fetchUpgradeOfferConfig`) plus low-level
 *     `:ui` Composables (`ZeroSettleCancelFlow`, `ZeroSettleUpgradeOffer`)
 *     that take pre-fetched configs and emit decisions. The orchestration
 *     glue (fetch config → show Composable → translate decision → dispatch
 *     server call → return `Result` to Dart) is what F6 will land.
 *   - **No host-activity dispatch yet.** [com.zerosettle.flutter.ZeroSettleHostActivity]
 *     declares `Mode.CancelFlow` / `Mode.UpgradeOffer` but `onCreate`
 *     finishes immediately with `Outcome.Cancelled` (see the file's F5
 *     placeholder note).
 *
 * Returning `not_implemented` (rather than the tagged
 * `zerosettle_phase2_wip` task-ID error) reflects that the handler IS
 * landed and owns the methods — the SDK + UI plumbing it depends on is
 * what's missing. Once F6 lands, swap each stub for an
 * `ActivityResultLauncher<ZeroSettleHostContract.Input>` launch + outcome
 * decode (see the plan's wire-table rows 232-233).
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
            "presentCancelFlow",
            "presentUpgradeOffer" ->
                result.error(
                    "not_implemented",
                    "${call.method} is pending Task F6 (Compose Mode dispatch in " +
                        "ZeroSettleHostActivity) in feat/1.3.0-parity. The Android SDK lacks " +
                        "a high-level present method; F6 will wire :ui Composables into the " +
                        "host activity and the handler will launch via " +
                        "ActivityResultLauncher<ZeroSettleHostContract.Input>. Plan: " +
                        "docs/superpowers/plans/2026-05-12-flutter-android-parity-plan.md",
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
