package com.zerosettle.flutter.ext

import com.zerosettle.sdk.core.ZeroSettleEvent

/**
 * SDK event -> `Map<String, Any?>` encoders for the Flutter EventChannel streams.
 *
 * The Android SDK's `events: SharedFlow<ZeroSettleEvent>` is the master event
 * stream; the plugin splits emissions across multiple Flutter EventChannels by
 * topic. iOS publishes the same Map shapes for the same channel names (see
 * `ZeroSettlePlugin.swift` checkout-event forwarding comments).
 *
 * **Wire channels covered here:**
 * - `zerosettle/checkout_events` -- `toCheckoutEventMap()` + [fabricateCancelEvent].
 * - Per-handle `OfferManager` `_state` channels -- `toOfferEventMap()` (wiring
 *   added in a later F-task; the encoder shape is fixed here so the channel
 *   reader can land independently).
 *
 * **Variants intentionally omitted (YAGNI):**
 * `MigrationCompleted`, `SyncFailed`, `EntitlementsRefreshed`, `PendingActionShown`
 * have no dedicated Flutter channel in 1.5.0. Add encoders here only when a
 * channel for them ships -- silent broadcasting of every variant would couple
 * the plugin to SDK-internal events Dart consumers don't subscribe to.
 *
 * **Discriminator throw is the documented contract.** Callers MUST filter the
 * master stream before invoking these extensions; misrouted events throw
 * [IllegalArgumentException] rather than emit a malformed wire frame.
 */

/**
 * Encode a `PurchaseSucceeded` / `PurchaseFailed` event for the
 * `zerosettle/checkout_events` channel.
 *
 * Cancellation events are NOT a [ZeroSettleEvent] variant on Android -- they're
 * synthesized by the plugin via [fabricateCancelEvent] when a
 * `purchase()` / `purchaseViaPlayBilling()` call resolves with
 * `ZeroSettleError.Cancelled`.
 *
 * @throws IllegalArgumentException if the event is not a checkout-event variant.
 *         Callers MUST filter the master stream first.
 */
fun ZeroSettleEvent.toCheckoutEventMap(): Map<String, Any?> = when (this) {
    is ZeroSettleEvent.PurchaseSucceeded -> mapOf(
        "type" to "success",
        "productId" to productId,
        "transactionId" to transactionId,
    )
    is ZeroSettleEvent.PurchaseFailed -> mapOf(
        "type" to "fail",
        "productId" to productId,
        "reason" to reason,
    )
    else -> throw IllegalArgumentException(
        "Event $this is not a checkout-event variant -- caller must filter the master stream"
    )
}

/**
 * Synthesize a cancellation event for the `checkout_events` channel. Used by
 * the plugin's `purchase` / `purchaseViaPlayBilling` handlers when the SDK
 * call resolves with `Result.failure(ZeroSettleError.Cancelled)`. Mirrors
 * iOS's `cancel` event shape so Dart consumers don't need platform-specific
 * stream handling.
 */
fun fabricateCancelEvent(productId: String): Map<String, Any?> = mapOf(
    "type" to "cancel",
    "productId" to productId,
)

/**
 * Encode an offer-related event for forwarding to an `OfferManager` handle's
 * per-handle state channel. NOT a top-level channel -- see the spec's
 * "Per-handle channel layer" section.
 *
 * @throws IllegalArgumentException if the event is not an offer-event variant.
 *         Callers MUST filter the master stream first.
 */
fun ZeroSettleEvent.toOfferEventMap(): Map<String, Any?> = when (this) {
    is ZeroSettleEvent.OfferShown -> mapOf(
        "type" to "offer_shown",
        "productId" to productId,
    )
    is ZeroSettleEvent.OfferAccepted -> mapOf(
        "type" to "offer_accepted",
        "productId" to productId,
    )
    is ZeroSettleEvent.OfferDismissed -> mapOf(
        "type" to "offer_dismissed",
        "productId" to productId,
    )
    is ZeroSettleEvent.OfferEvaluationFailed -> mapOf(
        "type" to "offer_evaluation_failed",
        "reason" to reason,
    )
    else -> throw IllegalArgumentException(
        "Event $this is not an offer-event variant -- caller must filter the master stream"
    )
}
