package com.zerosettle.flutter.ext

import com.google.common.truth.Truth.assertThat
import com.zerosettle.sdk.core.ZeroSettleEvent
import org.junit.Assert.assertThrows
import org.junit.Test

/**
 * Pins the [ZeroSettleEvent] -> `Map<String, Any?>` wire shapes published over
 * Flutter EventChannels. iOS publishes the same shapes for the same channel
 * names; Dart stream consumers are the contract. Key drift here = silent
 * stream-decode failure on the Dart side.
 */
class EventToFlutterMapTest {

    // -- toCheckoutEventMap() ---------------------------------------------------

    @Test
    fun `PurchaseSucceeded encodes with type=success`() {
        val event = ZeroSettleEvent.PurchaseSucceeded(
            productId = "com.app.pro",
            transactionId = "txn_1",
        )

        val map = event.toCheckoutEventMap()

        assertThat(map["type"]).isEqualTo("success")
        assertThat(map["productId"]).isEqualTo("com.app.pro")
        assertThat(map["transactionId"]).isEqualTo("txn_1")
        assertThat(map).hasSize(3)
    }

    @Test
    fun `PurchaseFailed encodes with type=fail and reason`() {
        val event = ZeroSettleEvent.PurchaseFailed(
            productId = "com.app.pro",
            reason = "network error",
        )

        val map = event.toCheckoutEventMap()

        assertThat(map["type"]).isEqualTo("fail")
        assertThat(map["productId"]).isEqualTo("com.app.pro")
        assertThat(map["reason"]).isEqualTo("network error")
        assertThat(map).hasSize(3)
    }

    @Test
    fun `toCheckoutEventMap throws on offer-event variant`() {
        val event: ZeroSettleEvent = ZeroSettleEvent.OfferShown("p1")

        assertThrows(IllegalArgumentException::class.java) {
            event.toCheckoutEventMap()
        }
    }

    @Test
    fun `toCheckoutEventMap throws on non-checkout SDK event`() {
        // Spot-check a SyncFailed variant that has no dedicated channel:
        // the discriminator must reject it so a future caller mis-piping the
        // master stream gets a loud failure, not a malformed Map.
        val event: ZeroSettleEvent = ZeroSettleEvent.SyncFailed(
            purchaseToken = "tok",
            attempts = 1,
            terminal = false,
        )

        assertThrows(IllegalArgumentException::class.java) {
            event.toCheckoutEventMap()
        }
    }

    // -- fabricateCancelEvent() -------------------------------------------------

    @Test
    fun `fabricated cancel event has type=cancel and productId only`() {
        val map = fabricateCancelEvent(productId = "com.app.pro")

        assertThat(map["type"]).isEqualTo("cancel")
        assertThat(map["productId"]).isEqualTo("com.app.pro")
        assertThat(map).hasSize(2)
    }

    // -- toOfferEventMap() ------------------------------------------------------

    @Test
    fun `OfferShown encodes with type=offer_shown`() {
        val map = ZeroSettleEvent.OfferShown("p1").toOfferEventMap()

        assertThat(map["type"]).isEqualTo("offer_shown")
        assertThat(map["productId"]).isEqualTo("p1")
        assertThat(map).hasSize(2)
    }

    @Test
    fun `OfferAccepted encodes with type=offer_accepted`() {
        val map = ZeroSettleEvent.OfferAccepted("p1").toOfferEventMap()

        assertThat(map["type"]).isEqualTo("offer_accepted")
        assertThat(map["productId"]).isEqualTo("p1")
        assertThat(map).hasSize(2)
    }

    @Test
    fun `OfferDismissed encodes with type=offer_dismissed`() {
        val map = ZeroSettleEvent.OfferDismissed("p1").toOfferEventMap()

        assertThat(map["type"]).isEqualTo("offer_dismissed")
        assertThat(map["productId"]).isEqualTo("p1")
        assertThat(map).hasSize(2)
    }

    @Test
    fun `OfferEvaluationFailed encodes with type=offer_evaluation_failed and reason`() {
        val map = ZeroSettleEvent.OfferEvaluationFailed("server 500").toOfferEventMap()

        assertThat(map["type"]).isEqualTo("offer_evaluation_failed")
        assertThat(map["reason"]).isEqualTo("server 500")
        assertThat(map).hasSize(2)
    }

    @Test
    fun `toOfferEventMap throws on checkout-event variant`() {
        val event: ZeroSettleEvent = ZeroSettleEvent.PurchaseSucceeded("p", "t")

        assertThrows(IllegalArgumentException::class.java) {
            event.toOfferEventMap()
        }
    }

    @Test
    fun `toOfferEventMap throws on non-offer SDK event`() {
        val event: ZeroSettleEvent = ZeroSettleEvent.EntitlementsRefreshed(count = 3)

        assertThrows(IllegalArgumentException::class.java) {
            event.toOfferEventMap()
        }
    }
}
