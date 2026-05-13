package com.zerosettle.flutter.handlers

import android.app.Activity
import android.content.Context
import com.google.common.truth.Truth.assertThat
import com.zerosettle.sdk.ZeroSettle
import com.zerosettle.sdk.models.CheckoutTransaction
import com.zerosettle.sdk.models.EntitlementSource
import com.zerosettle.sdk.models.ZeroSettleError
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkObject
import io.mockk.slot
import io.mockk.unmockkObject
import io.mockk.verify
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * Unit tests for [PurchaseHandler].
 *
 * Mirrors [IdentityHandlerTest] / [CatalogHandlerTest] setup —
 * `mockkObject(ZeroSettle)`, `UnconfinedTestDispatcher` so
 * `scope.launch { ... }` resolves synchronously, all SDK boundaries stubbed.
 *
 * Wire-shape claims under test:
 *   - `purchase` happy path returns `CheckoutTransaction.toFlutterMap()`.
 *   - `purchase` missing `productId` → `INVALID_ARGUMENTS`.
 *   - `purchase` with no Activity attached → `activity_required`
 *     (handler-side guard before the SDK call).
 *   - `purchase` SDK throw → `sdk_error` via the shared `sendError`.
 *   - `purchase` SDK `Result.failure(CheckoutInFlight)` → wire code
 *     `checkout_in_flight` (the Phase 1 A2 deferred-bridge collision case).
 *   - `purchase` SDK `Result.failure(UserNotIdentified)` → `user_not_identified`.
 *   - `purchase` `presentation` arg is silently accepted (iOS-only).
 *   - `purchaseViaStoreKit` → `not_implemented`.
 *   - `presentPaymentSheet` → `not_implemented`.
 *   - `preloadPaymentSheet` / `warmUpPaymentSheet`:
 *       - missing `productId` → `INVALID_ARGUMENTS` (matches iOS validation).
 *       - happy path → `success(null)` (no-op).
 */
@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
class PurchaseHandlerTest {

    private val scope = CoroutineScope(SupervisorJob() + UnconfinedTestDispatcher())
    private val appContext: Context = mockk(relaxed = true)
    private val activity: Activity = mockk(relaxed = true)
    private lateinit var handler: PurchaseHandler

    /**
     * F25 — captures every checkout event the handler fabricates during a
     * test. Reset in [setUp]; asserted on in the F25 fabrication tests.
     */
    private val checkoutEvents = mutableListOf<Map<String, Any?>>()

    @Before
    fun setUp() {
        mockkObject(ZeroSettle)
        checkoutEvents.clear()
        val deps = HandlerDependencies(
            scope = scope,
            activityProvider = { activity },
            applicationContextProvider = { appContext },
            checkoutEventEmitter = { event -> checkoutEvents.add(event) },
        )
        handler = PurchaseHandler(deps)
    }

    @After
    fun tearDown() {
        unmockkObject(ZeroSettle)
        scope.cancel()
    }

    private fun call(method: String, args: Map<String, Any?>? = null) = MethodCall(method, args)
    private fun newResult() = mockk<MethodChannel.Result>(relaxed = true)

    private fun newTransaction(
        id: String = "txn_1",
        productId: String = "com.app.coins",
    ) = CheckoutTransaction(
        id = id,
        productId = productId,
        status = CheckoutTransaction.Status.COMPLETED,
        source = EntitlementSource.WEB_CHECKOUT,
        purchasedAt = "2026-05-12T00:00:00Z",
    )

    /**
     * Build a fresh handler whose `activityProvider` returns null. Used
     * for the `activity_required` test case.
     */
    private fun handlerWithoutActivity(): PurchaseHandler {
        val deps = HandlerDependencies(
            scope = scope,
            activityProvider = { null },
            applicationContextProvider = { appContext },
            checkoutEventEmitter = { event -> checkoutEvents.add(event) },
        )
        return PurchaseHandler(deps)
    }

    // ─── handle() routing ───────────────────────────────────────────────

    @Test
    fun `handle returns false for unknown method`() {
        val result = newResult()
        val consumed = handler.handle(call("definitelyNotMine"), result)
        assertThat(consumed).isFalse()
        verify(exactly = 0) { result.success(any()) }
        verify(exactly = 0) { result.error(any(), any(), any()) }
    }

    @Test
    fun `handle returns true for each owned method`() {
        // Stub the SDK so the suspend purchase happy path doesn't actually
        // launch a Custom Tab / Play dialog. The other methods return
        // synchronously.
        coEvery { ZeroSettle.purchase(any(), any()) } returns Result.failure(
            ZeroSettleError.UserNotIdentified,
        )
        coEvery { ZeroSettle.purchaseViaPlayBilling(any(), any()) } returns Result.failure(
            ZeroSettleError.UserNotIdentified,
        )
        listOf(
            "purchase" to mapOf("productId" to "x"),
            "purchaseViaPlayBilling" to mapOf("productId" to "x"),
            "purchaseViaStoreKit" to null,
            "presentPaymentSheet" to null,
            "preloadPaymentSheet" to mapOf("productId" to "x"),
            "warmUpPaymentSheet" to mapOf("productId" to "x"),
        ).forEach { (method, args) ->
            val consumed = handler.handle(call(method, args), newResult())
            assertThat(consumed).isTrue()
        }
    }

    // ─── purchase ───────────────────────────────────────────────────────

    @Test
    fun `purchase returns wire-encoded transaction on success`() = runTest {
        val txn = newTransaction(id = "txn_abc", productId = "com.app.coins")
        coEvery { ZeroSettle.purchase(activity, "com.app.coins") } returns Result.success(txn)
        val mapSlot = slot<Map<String, Any?>>()
        val result = newResult()
        every { result.success(capture(mapSlot)) } answers { }

        handler.handle(call("purchase", mapOf("productId" to "com.app.coins")), result)

        coVerify { ZeroSettle.purchase(activity, "com.app.coins") }
        assertThat(mapSlot.captured["id"]).isEqualTo("txn_abc")
        assertThat(mapSlot.captured["productId"]).isEqualTo("com.app.coins")
        assertThat(mapSlot.captured["status"]).isEqualTo("completed")
    }

    @Test
    fun `purchase errors on missing productId`() {
        val result = newResult()

        handler.handle(call("purchase", emptyMap<String, Any?>()), result)

        verify { result.error("INVALID_ARGUMENTS", "productId is required", null) }
        coVerify(exactly = 0) { ZeroSettle.purchase(any(), any()) }
    }

    @Test
    fun `purchase errors activity_required when no Activity attached`() {
        val noActivityHandler = handlerWithoutActivity()
        val result = newResult()

        noActivityHandler.handle(
            call("purchase", mapOf("productId" to "com.app.coins")),
            result,
        )

        verify { result.error(eq("activity_required"), any(), null) }
        coVerify(exactly = 0) { ZeroSettle.purchase(any(), any()) }
    }

    @Test
    fun `purchase maps SDK throw to sdk_error`() = runTest {
        coEvery { ZeroSettle.purchase(any(), any()) } throws RuntimeException("boom")
        val result = newResult()

        handler.handle(call("purchase", mapOf("productId" to "com.app.coins")), result)

        verify { result.error("sdk_error", "boom", null) }
    }

    @Test
    fun `purchase maps CheckoutInFlight to checkout_in_flight wire code`() = runTest {
        // The Phase 1 A2 deferred-bridge collision case — two concurrent
        // purchase() calls fail the second with this typed error so Dart
        // can surface "another checkout already running" UX. The wire
        // code is the stable handle adopters pattern-match on.
        coEvery { ZeroSettle.purchase(any(), any()) } returns Result.failure(
            ZeroSettleError.CheckoutInFlight,
        )
        val result = newResult()

        handler.handle(call("purchase", mapOf("productId" to "com.app.coins")), result)

        verify { result.error(eq("checkout_in_flight"), any(), null) }
    }

    @Test
    fun `purchase maps UserNotIdentified to user_not_identified wire code`() = runTest {
        coEvery { ZeroSettle.purchase(any(), any()) } returns Result.failure(
            ZeroSettleError.UserNotIdentified,
        )
        val result = newResult()

        handler.handle(call("purchase", mapOf("productId" to "com.app.coins")), result)

        verify { result.error(eq("user_not_identified"), any(), null) }
    }

    @Test
    fun `purchase maps PurchaseCancelled to cancelled wire code`() = runTest {
        coEvery { ZeroSettle.purchase(any(), any()) } returns Result.failure(
            ZeroSettleError.PurchaseCancelled,
        )
        val result = newResult()

        handler.handle(call("purchase", mapOf("productId" to "com.app.coins")), result)

        verify { result.error(eq("cancelled"), any(), null) }
    }

    @Test
    fun `purchase silently accepts iOS-only presentation arg`() = runTest {
        // The Dart wire ships `presentation` for iOS parity. Android's SDK
        // has no equivalent; the handler drops the arg without rejecting.
        val txn = newTransaction(id = "txn_pres", productId = "com.app.coins")
        coEvery { ZeroSettle.purchase(activity, "com.app.coins") } returns Result.success(txn)
        val result = newResult()

        handler.handle(
            call(
                "purchase",
                mapOf("productId" to "com.app.coins", "presentation" to "sheet"),
            ),
            result,
        )

        // Call still went through; presentation arg was ignored, not surfaced as an error.
        coVerify { ZeroSettle.purchase(activity, "com.app.coins") }
        verify(exactly = 0) { result.error(any(), any(), any()) }
    }

    // ─── purchaseViaStoreKit (iOS-only stub) ────────────────────────────

    @Test
    fun `purchaseViaStoreKit returns not_implemented`() {
        val result = newResult()

        handler.handle(call("purchaseViaStoreKit", mapOf("productId" to "com.app.coins")), result)

        verify { result.error(eq("not_implemented"), any(), null) }
    }

    // ─── purchaseViaPlayBilling (D1) ─────────────────────────────────────

    @Test
    fun `purchaseViaPlayBilling returns wire-encoded transaction on success`() = runTest {
        val txn = newTransaction(id = "GPA.123", productId = "com.app.coins")
        coEvery {
            ZeroSettle.purchaseViaPlayBilling(activity, "com.app.coins")
        } returns Result.success(txn)
        val mapSlot = slot<Map<String, Any?>>()
        val result = newResult()
        every { result.success(capture(mapSlot)) } answers { }

        handler.handle(
            call("purchaseViaPlayBilling", mapOf("productId" to "com.app.coins")),
            result,
        )

        coVerify { ZeroSettle.purchaseViaPlayBilling(activity, "com.app.coins") }
        assertThat(mapSlot.captured["id"]).isEqualTo("GPA.123")
        assertThat(mapSlot.captured["productId"]).isEqualTo("com.app.coins")
        assertThat(mapSlot.captured["status"]).isEqualTo("completed")
    }

    @Test
    fun `purchaseViaPlayBilling errors on missing productId`() {
        val result = newResult()

        handler.handle(
            call("purchaseViaPlayBilling", emptyMap<String, Any?>()),
            result,
        )

        verify { result.error("INVALID_ARGUMENTS", "productId is required", null) }
        coVerify(exactly = 0) { ZeroSettle.purchaseViaPlayBilling(any(), any()) }
    }

    @Test
    fun `purchaseViaPlayBilling errors activity_required when no Activity attached`() {
        val noActivityHandler = handlerWithoutActivity()
        val result = newResult()

        noActivityHandler.handle(
            call("purchaseViaPlayBilling", mapOf("productId" to "com.app.coins")),
            result,
        )

        verify { result.error(eq("activity_required"), any(), null) }
        coVerify(exactly = 0) { ZeroSettle.purchaseViaPlayBilling(any(), any()) }
    }

    @Test
    fun `purchaseViaPlayBilling maps SDK throw to sdk_error`() = runTest {
        coEvery { ZeroSettle.purchaseViaPlayBilling(any(), any()) } throws RuntimeException("boom")
        val result = newResult()

        handler.handle(
            call("purchaseViaPlayBilling", mapOf("productId" to "com.app.coins")),
            result,
        )

        verify { result.error("sdk_error", "boom", null) }
    }

    @Test
    fun `purchaseViaPlayBilling maps CheckoutInFlight to checkout_in_flight wire code`() = runTest {
        // The Phase 1 A3 deferred-bridge collision case mirrors A2 for web
        // — two concurrent Play purchases fail the second with this typed
        // error so Dart can surface "another checkout already running" UX.
        coEvery { ZeroSettle.purchaseViaPlayBilling(any(), any()) } returns Result.failure(
            ZeroSettleError.CheckoutInFlight,
        )
        val result = newResult()

        handler.handle(
            call("purchaseViaPlayBilling", mapOf("productId" to "com.app.coins")),
            result,
        )

        verify { result.error(eq("checkout_in_flight"), any(), null) }
    }

    @Test
    fun `purchaseViaPlayBilling maps PurchaseCancelled to cancelled wire code`() = runTest {
        coEvery { ZeroSettle.purchaseViaPlayBilling(any(), any()) } returns Result.failure(
            ZeroSettleError.PurchaseCancelled,
        )
        val result = newResult()

        handler.handle(
            call("purchaseViaPlayBilling", mapOf("productId" to "com.app.coins")),
            result,
        )

        verify { result.error(eq("cancelled"), any(), null) }
    }

    @Test
    fun `purchaseViaPlayBilling does NOT fabricate checkout events`() = runTest {
        // Parity is with iOS purchaseViaStoreKit, not the web purchase() flow.
        // Play Billing's dialog drives its own UX; the checkout-event channel
        // is for web Custom Tab where Flutter is hidden. See class doc.
        val txn = newTransaction(id = "GPA.456", productId = "com.app.coins")
        coEvery {
            ZeroSettle.purchaseViaPlayBilling(activity, "com.app.coins")
        } returns Result.success(txn)

        handler.handle(
            call("purchaseViaPlayBilling", mapOf("productId" to "com.app.coins")),
            newResult(),
        )

        assertThat(checkoutEvents).isEmpty()
    }

    // ─── presentPaymentSheet (iOS-only stub) ────────────────────────────

    @Test
    fun `presentPaymentSheet returns not_implemented`() {
        val result = newResult()

        handler.handle(call("presentPaymentSheet", mapOf("productId" to "com.app.coins")), result)

        verify { result.error(eq("not_implemented"), any(), null) }
    }

    // ─── preloadPaymentSheet (no-op with arg validation) ────────────────

    @Test
    fun `preloadPaymentSheet returns success(null) on happy path`() {
        val result = newResult()

        handler.handle(call("preloadPaymentSheet", mapOf("productId" to "com.app.coins")), result)

        verify { result.success(null) }
        verify(exactly = 0) { result.error(any(), any(), any()) }
    }

    @Test
    fun `preloadPaymentSheet errors on missing productId`() {
        val result = newResult()

        handler.handle(call("preloadPaymentSheet", emptyMap<String, Any?>()), result)

        verify { result.error("INVALID_ARGUMENTS", "productId is required", null) }
        verify(exactly = 0) { result.success(any()) }
    }

    // ─── warmUpPaymentSheet (no-op with arg validation) ─────────────────

    @Test
    fun `warmUpPaymentSheet returns success(null) on happy path`() {
        val result = newResult()

        handler.handle(call("warmUpPaymentSheet", mapOf("productId" to "com.app.coins")), result)

        verify { result.success(null) }
        verify(exactly = 0) { result.error(any(), any(), any()) }
    }

    @Test
    fun `warmUpPaymentSheet errors on missing productId`() {
        val result = newResult()

        handler.handle(call("warmUpPaymentSheet", emptyMap<String, Any?>()), result)

        verify { result.error("INVALID_ARGUMENTS", "productId is required", null) }
        verify(exactly = 0) { result.success(any()) }
    }

    // ─── F25 — checkout-event fabrication ───────────────────────────────
    //
    // The handler emits four wire events on the
    // `zerosettle/checkout_events` EventChannel via
    // [HandlerDependencies.checkoutEventEmitter]. Wire shapes mirror iOS
    // exactly (see `ext/EventToFlutterMap.kt`).

    @Test
    fun `purchase happy path emits checkoutDidBegin then checkoutDidComplete`() {
        val txn = newTransaction(id = "txn_ok", productId = "com.app.coins")
        coEvery { ZeroSettle.purchase(activity, "com.app.coins") } returns Result.success(txn)

        handler.handle(call("purchase", mapOf("productId" to "com.app.coins")), newResult())

        // Exactly two fabricated events, in order.
        assertThat(checkoutEvents).hasSize(2)
        assertThat(checkoutEvents[0]).isEqualTo(
            mapOf("event" to "checkoutDidBegin", "productId" to "com.app.coins")
        )
        // checkoutDidComplete carries the full transaction map under
        // "transaction" — same key as iOS (CheckoutTransaction.toFlutterMap()).
        val complete = checkoutEvents[1]
        assertThat(complete["event"]).isEqualTo("checkoutDidComplete")
        @Suppress("UNCHECKED_CAST")
        val embedded = complete["transaction"] as Map<String, Any?>
        assertThat(embedded["id"]).isEqualTo("txn_ok")
        assertThat(embedded["productId"]).isEqualTo("com.app.coins")
    }

    @Test
    fun `purchase PurchaseCancelled emits checkoutDidBegin then checkoutDidCancel`() {
        coEvery { ZeroSettle.purchase(activity, "com.app.coins") } returns Result.failure(
            ZeroSettleError.PurchaseCancelled,
        )

        handler.handle(call("purchase", mapOf("productId" to "com.app.coins")), newResult())

        assertThat(checkoutEvents).hasSize(2)
        assertThat(checkoutEvents[0]["event"]).isEqualTo("checkoutDidBegin")
        // Cancel carries productId only — no error/message field. Matches iOS.
        assertThat(checkoutEvents[1]).isEqualTo(
            mapOf("event" to "checkoutDidCancel", "productId" to "com.app.coins")
        )
    }

    @Test
    fun `purchase non-cancel failure emits checkoutDidBegin then checkoutDidFail`() {
        coEvery { ZeroSettle.purchase(activity, "com.app.coins") } returns Result.failure(
            ZeroSettleError.CheckoutInFlight,
        )

        handler.handle(call("purchase", mapOf("productId" to "com.app.coins")), newResult())

        assertThat(checkoutEvents).hasSize(2)
        assertThat(checkoutEvents[0]["event"]).isEqualTo("checkoutDidBegin")
        val fail = checkoutEvents[1]
        assertThat(fail["event"]).isEqualTo("checkoutDidFail")
        assertThat(fail["productId"]).isEqualTo("com.app.coins")
        // Error message falls back to the localized message — never blank.
        assertThat(fail["error"] as String).isNotEmpty()
    }

    @Test
    fun `purchase SDK throw emits checkoutDidBegin then checkoutDidFail with throwable message`() {
        coEvery { ZeroSettle.purchase(any(), any()) } throws RuntimeException("boom")

        handler.handle(call("purchase", mapOf("productId" to "com.app.coins")), newResult())

        assertThat(checkoutEvents).hasSize(2)
        assertThat(checkoutEvents[0]["event"]).isEqualTo("checkoutDidBegin")
        assertThat(checkoutEvents[1]).isEqualTo(
            mapOf(
                "event" to "checkoutDidFail",
                "productId" to "com.app.coins",
                "error" to "boom",
            )
        )
    }

    @Test
    fun `purchase without Activity does not fabricate any checkout event`() {
        // The activity-required guard fires synchronously before any
        // checkout begins; no fabricated event should escape. Matches iOS,
        // which never invokes its delegate path until the sheet presents.
        val noActivityHandler = handlerWithoutActivity()
        noActivityHandler.handle(
            call("purchase", mapOf("productId" to "com.app.coins")),
            newResult(),
        )

        assertThat(checkoutEvents).isEmpty()
    }

    @Test
    fun `purchase missing productId does not fabricate any checkout event`() {
        // Same rationale as the no-Activity case — the INVALID_ARGUMENTS
        // guard fires before any begin event would be emitted.
        handler.handle(call("purchase", emptyMap<String, Any?>()), newResult())

        assertThat(checkoutEvents).isEmpty()
    }
}
