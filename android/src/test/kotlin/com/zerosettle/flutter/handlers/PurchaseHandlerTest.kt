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

    @Before
    fun setUp() {
        mockkObject(ZeroSettle)
        val deps = HandlerDependencies(
            scope = scope,
            activityProvider = { activity },
            applicationContextProvider = { appContext },
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
        // launch a Custom Tab. The other methods return synchronously.
        coEvery { ZeroSettle.purchase(any(), any()) } returns Result.failure(
            ZeroSettleError.UserNotIdentified,
        )
        listOf(
            "purchase" to mapOf("productId" to "x"),
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
}
