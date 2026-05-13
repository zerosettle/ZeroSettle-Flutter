package com.zerosettle.flutter.ext

import com.google.common.truth.Truth.assertThat
import com.zerosettle.sdk.models.CheckoutTransaction
import com.zerosettle.sdk.models.EntitlementSource
import org.junit.Test

/**
 * Pins the `Map<String, Any?>` wire shapes published over Flutter
 * EventChannels. iOS publishes the same shapes for the same channel names;
 * Dart stream consumers are the contract. Key drift here = silent
 * stream-decode failure on the Dart side.
 *
 * The four `fabricateCheckoutDid*Event` helpers are pinned against iOS's
 * `ZeroSettlePlugin.swift:1259-1287` delegate forwarding. Dart consumers
 * dispatch on `event["event"]` (see `test/zerosettle_test.dart:661`), so the
 * discriminator key + values are load-bearing.
 */
class EventToFlutterMapTest {

    // -- fabricateCheckoutDidBeginEvent() ---------------------------------------

    @Test
    fun `fabricateCheckoutDidBeginEvent emits iOS-matching shape`() {
        val map = fabricateCheckoutDidBeginEvent(productId = "com.app.pro")

        assertThat(map).containsExactly(
            "event", "checkoutDidBegin",
            "productId", "com.app.pro",
        )
    }

    // -- fabricateCheckoutDidCompleteEvent() ------------------------------------

    @Test
    fun `fabricateCheckoutDidCompleteEvent emits iOS-matching shape with nested transaction`() {
        val txn = CheckoutTransaction(
            id = "txn_abc",
            productId = "com.app.pro",
            status = CheckoutTransaction.Status.COMPLETED,
            source = EntitlementSource.WEB_CHECKOUT,
            purchasedAt = "2026-05-01T10:00:00Z",
        )

        val map = fabricateCheckoutDidCompleteEvent(transaction = txn)

        assertThat(map["event"]).isEqualTo("checkoutDidComplete")
        assertThat(map["transaction"]).isInstanceOf(Map::class.java)
        // Verify the nested transaction map shape matches CheckoutTransaction.toFlutterMap().
        // Spot-check the load-bearing keys -- full encoding is tested in ModelToFlutterMapTest.
        @Suppress("UNCHECKED_CAST")
        val txnMap = map["transaction"] as Map<String, Any?>
        assertThat(txnMap).containsKey("id")
        assertThat(txnMap).containsKey("productId")
        // Pin: no flat productId / transactionId leaks alongside the nested transaction.
        assertThat(map).hasSize(2)
    }

    // -- fabricateCheckoutDidCancelEvent() --------------------------------------

    @Test
    fun `fabricateCheckoutDidCancelEvent emits iOS-matching shape`() {
        val map = fabricateCheckoutDidCancelEvent(productId = "com.app.pro")

        assertThat(map).containsExactly(
            "event", "checkoutDidCancel",
            "productId", "com.app.pro",
        )
    }

    // -- fabricateCheckoutDidFailEvent() ----------------------------------------

    @Test
    fun `fabricateCheckoutDidFailEvent emits iOS-matching shape with error message`() {
        val map = fabricateCheckoutDidFailEvent(
            productId = "com.app.pro",
            error = RuntimeException("network down"),
        )

        assertThat(map["event"]).isEqualTo("checkoutDidFail")
        assertThat(map["productId"]).isEqualTo("com.app.pro")
        assertThat(map["error"]).isEqualTo("network down")
        assertThat(map).hasSize(3)
    }

    @Test
    fun `fabricateCheckoutDidFailEvent falls back on null error message`() {
        // Throwables with null message should fall back to a non-empty string
        // so the wire frame's `error` field is never blank.
        val map = fabricateCheckoutDidFailEvent(
            productId = "com.app.pro",
            error = object : RuntimeException() {},
        )

        assertThat(map["error"] as String).isNotEmpty()
    }
}
