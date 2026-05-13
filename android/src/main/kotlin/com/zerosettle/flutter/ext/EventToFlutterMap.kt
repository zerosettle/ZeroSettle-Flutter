package com.zerosettle.flutter.ext

import com.zerosettle.sdk.models.CheckoutTransaction

/**
 * SDK event -> `Map<String, Any?>` encoders for the Flutter EventChannel streams.
 *
 * The Android SDK's `events: SharedFlow<ZeroSettleEvent>` is the master event
 * stream; the plugin splits emissions across multiple Flutter EventChannels by
 * topic. iOS publishes the same Map shapes for the same channel names (see
 * `ZeroSettlePlugin.swift` checkout-event forwarding comments).
 *
 * **Wire channel covered here:**
 * - `zerosettle/checkout_events` -- the four `fabricateCheckoutDid*Event`
 *   helpers below. This file currently provides checkout-event fabrication
 *   only. Unlike a master-event-stream consumer, this surface is NOT driven
 *   from the SDK's master event stream. The plugin's `purchase` /
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
 *
 * Per-handle `OfferManager` state is published via `toCompositeStateMap` in
 * `ModelToFlutterMap.kt`, not via per-event encoding -- the Unified Offer
 * System (MigrationTipView + OfferManager headless API) is the canonical path.
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
