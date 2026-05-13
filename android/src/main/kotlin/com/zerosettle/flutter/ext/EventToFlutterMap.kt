package com.zerosettle.flutter.ext

import com.zerosettle.sdk.core.ZeroSettleEvent
import com.zerosettle.sdk.models.CheckoutTransaction

/**
 * SDK event -> `Map<String, Any?>` encoders for the Flutter EventChannel streams.
 *
 * The Android SDK's `events: SharedFlow<ZeroSettleEvent>` is the master event
 * stream; the plugin splits emissions across multiple Flutter EventChannels by
 * topic. iOS publishes the same Map shapes for the same channel names (see
 * `ZeroSettlePlugin.swift` checkout-event forwarding comments).
 *
 * **Wire channels covered here:**
 * - `zerosettle/checkout_events` -- the four `fabricateCheckoutDid*Event`
 *   helpers below. Unlike the offer channel, this surface is NOT driven from
 *   the SDK's master event stream. The plugin's `purchase` /
 *   `purchaseViaPlayBilling` method handlers synthesize all four events
 *   themselves from their handler context, because:
 *     1. iOS doesn't subscribe to a generic event stream either -- it calls
 *        `zeroSettleCheckoutDid*` delegate callbacks directly from the same
 *        call site that returns the transaction to Flutter.
 *     2. The Android SDK's `PurchaseSucceeded` event carries only
 *        `productId + transactionId`, but iOS's `checkoutDidComplete` carries
 *        the full hydrated `CheckoutTransaction`. The plugin already has the
 *        full transaction (returned from `purchase()` / `purchaseViaPlayBilling()`
 *        as `Result<CheckoutTransaction>` after SDK tasks A2/A3) and would
 *        otherwise need a network round-trip to re-hydrate it.
 * - Per-handle `OfferManager` `_state` channels -- `toOfferEventMap()` (wiring
 *   added in a later F-task; the encoder shape is fixed here so the channel
 *   reader can land independently). That surface IS driven from the SDK's
 *   master event stream; the discriminator throw protects against misrouting.
 *
 * **Variants intentionally omitted (YAGNI):**
 * `MigrationCompleted`, `SyncFailed`, `EntitlementsRefreshed`, `PendingActionShown`
 * have no dedicated Flutter channel in 1.5.0. Add encoders here only when a
 * channel for them ships -- silent broadcasting of every variant would couple
 * the plugin to SDK-internal events Dart consumers don't subscribe to.
 */

/**
 * Synthesize a `checkoutDidBegin` event for the `zerosettle/checkout_events`
 * channel. The plugin emits this BEFORE calling `ZeroSettle.purchase()` /
 * `purchaseViaPlayBilling()` so adopters get a UI signal to show a loading
 * spinner. Mirrors iOS's `zeroSettleCheckoutDidBegin(productId:)` delegate
 * callback (see `ZeroSettlePlugin.swift:1259`).
 *
 * Wire shape: `{event: "checkoutDidBegin", productId}`.
 */
fun fabricateCheckoutDidBeginEvent(productId: String): Map<String, Any?> = mapOf(
    "event" to "checkoutDidBegin",
    "productId" to productId,
)

/**
 * Synthesize a `checkoutDidComplete` event for the `zerosettle/checkout_events`
 * channel. The plugin emits this from its `purchase` / `purchaseViaPlayBilling`
 * handlers when the SDK returns `Result.success(CheckoutTransaction)`. The full
 * hydrated transaction (encoded via `CheckoutTransaction.toFlutterMap()` from
 * F3) is nested under the `transaction` key -- no flat `productId` /
 * `transactionId`. Mirrors iOS's
 * `zeroSettleCheckoutDidComplete(transaction:)` delegate callback.
 *
 * Wire shape: `{event: "checkoutDidComplete", transaction: <CheckoutTransaction.toFlutterMap()>}`.
 */
fun fabricateCheckoutDidCompleteEvent(
    transaction: CheckoutTransaction,
): Map<String, Any?> = mapOf(
    "event" to "checkoutDidComplete",
    "transaction" to transaction.toFlutterMap(),
)

/**
 * Synthesize a `checkoutDidCancel` event for the `zerosettle/checkout_events`
 * channel. Emitted when the SDK returns
 * `Result.failure(ZeroSettleError.Cancelled)`. The Android SDK has no
 * `PurchaseCancelled` event variant -- cancellation is communicated via the
 * `Result` from `purchase()` only. Mirrors iOS's
 * `zeroSettleCheckoutDidCancel(productId:)` delegate callback.
 *
 * Wire shape: `{event: "checkoutDidCancel", productId}`.
 */
fun fabricateCheckoutDidCancelEvent(productId: String): Map<String, Any?> = mapOf(
    "event" to "checkoutDidCancel",
    "productId" to productId,
)

/**
 * Synthesize a `checkoutDidFail` event for the `zerosettle/checkout_events`
 * channel. Emitted when the SDK returns `Result.failure(<error>)` for any
 * error variant other than `Cancelled`. The `error` value is the throwable's
 * localized message -- matches iOS's `error.localizedDescription`. Falls back
 * to the class name and finally a literal `"unknown error"` if no message is
 * available, so the wire frame is never blank. Mirrors iOS's
 * `zeroSettleCheckoutDidFail(productId:error:)` delegate callback.
 *
 * Wire shape: `{event: "checkoutDidFail", productId, error}`.
 */
fun fabricateCheckoutDidFailEvent(productId: String, error: Throwable): Map<String, Any?> = mapOf(
    "event" to "checkoutDidFail",
    "productId" to productId,
    "error" to (error.message ?: error::class.simpleName ?: "unknown error"),
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
