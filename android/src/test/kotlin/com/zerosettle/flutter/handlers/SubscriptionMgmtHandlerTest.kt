package com.zerosettle.flutter.handlers

import android.app.Activity
import android.content.Context
import com.google.common.truth.Truth.assertThat
import com.zerosettle.sdk.ZeroSettle
import com.zerosettle.sdk.models.ZeroSettleError
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import io.mockk.mockkObject
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
 * Unit tests for [SubscriptionMgmtHandler].
 *
 * Mirrors [IdentityHandlerTest] / [CatalogHandlerTest] / [PurchaseHandlerTest]
 * setup — `mockkObject(ZeroSettle)`, `UnconfinedTestDispatcher` so
 * `scope.launch { ... }` resolves synchronously, all SDK boundaries stubbed.
 *
 * Wire-shape claims under test:
 *   - `cancelSubscription` happy path returns `success(null)`.
 *   - `cancelSubscription` missing `productId` → `INVALID_ARGUMENTS`.
 *   - `cancelSubscription` accepts iOS-only `userId` arg without rejecting.
 *   - `cancelSubscription` defaults `immediate=false` when omitted; passes
 *     through when present.
 *   - `cancelSubscription` SDK throw → `sdk_error` via shared `sendError`.
 *   - `cancelSubscription` SDK `Result.failure(UserNotIdentified)` →
 *     `user_not_identified` wire code.
 *   - `pauseSubscription` happy path with `pauseDurationDays` returns
 *     `success(resumesAtString)`.
 *   - `pauseSubscription` accepts legacy `pauseOptionId` arg as duration days.
 *   - `pauseSubscription` happy path with null resumesAt returns `success(null)`.
 *   - `pauseSubscription` missing `productId` → `INVALID_ARGUMENTS`.
 *   - `pauseSubscription` SDK `Result.failure` → mapped wire code.
 *   - `resumeSubscription` happy path returns `success(null)`.
 *   - `resumeSubscription` missing `productId` → `INVALID_ARGUMENTS`.
 *   - `resumeSubscription` SDK `Result.failure(NoActiveSubscription)` →
 *     `no_active_subscription` wire code.
 *   - `openCustomerPortal` → `not_implemented` (matches iOS — Kit removed).
 *   - `showManageSubscription` → `not_implemented` (matches iOS — Kit removed).
 *   - `acceptSaveOffer` / `submitCancelFlowResponse` /
 *     `getCancelFlowConfig` / `fetchCancelFlowConfig` →
 *     `not_implemented` (Save-the-Sale iOS-only per product decision).
 */
@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
class SubscriptionMgmtHandlerTest {

    private val scope = CoroutineScope(SupervisorJob() + UnconfinedTestDispatcher())
    private val appContext: Context = mockk(relaxed = true)
    private val activity: Activity = mockk(relaxed = true)
    private lateinit var handler: SubscriptionMgmtHandler

    @Before
    fun setUp() {
        mockkObject(ZeroSettle)
        val deps = HandlerDependencies(
            scope = scope,
            activityProvider = { activity },
            applicationContextProvider = { appContext },
        )
        handler = SubscriptionMgmtHandler(deps)
    }

    @After
    fun tearDown() {
        unmockkObject(ZeroSettle)
        scope.cancel()
    }

    private fun call(method: String, args: Map<String, Any?>? = null) = MethodCall(method, args)
    private fun newResult() = mockk<MethodChannel.Result>(relaxed = true)

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
        // Stub the SDK so suspend happy paths don't actually call the
        // network. The other methods return synchronously.
        coEvery { ZeroSettle.cancelSubscription(any(), any()) } returns Result.failure(
            ZeroSettleError.UserNotIdentified,
        )
        coEvery { ZeroSettle.pauseSubscription(any(), any()) } returns Result.failure(
            ZeroSettleError.UserNotIdentified,
        )
        coEvery { ZeroSettle.resumeSubscription(any()) } returns Result.failure(
            ZeroSettleError.UserNotIdentified,
        )
        listOf(
            "cancelSubscription" to mapOf("productId" to "x"),
            "pauseSubscription" to mapOf("productId" to "x"),
            "resumeSubscription" to mapOf("productId" to "x"),
            "openCustomerPortal" to null,
            "showManageSubscription" to null,
            "acceptSaveOffer" to null,
            "submitCancelFlowResponse" to null,
            "getCancelFlowConfig" to null,
            "fetchCancelFlowConfig" to null,
        ).forEach { (method, args) ->
            val consumed = handler.handle(call(method, args), newResult())
            assertThat(consumed).isTrue()
        }
    }

    // ─── cancelSubscription ─────────────────────────────────────────────

    @Test
    fun `cancelSubscription happy path returns success(null)`() = runTest {
        coEvery { ZeroSettle.cancelSubscription("com.app.sub", false) } returns Result.success(Unit)
        val result = newResult()

        handler.handle(
            call("cancelSubscription", mapOf("productId" to "com.app.sub")),
            result,
        )

        coVerify { ZeroSettle.cancelSubscription("com.app.sub", false) }
        verify { result.success(null) }
        verify(exactly = 0) { result.error(any(), any(), any()) }
    }

    @Test
    fun `cancelSubscription forwards immediate=true when provided`() = runTest {
        coEvery { ZeroSettle.cancelSubscription("com.app.sub", true) } returns Result.success(Unit)
        val result = newResult()

        handler.handle(
            call(
                "cancelSubscription",
                mapOf("productId" to "com.app.sub", "immediate" to true),
            ),
            result,
        )

        coVerify { ZeroSettle.cancelSubscription("com.app.sub", true) }
        verify { result.success(null) }
    }

    @Test
    fun `cancelSubscription silently accepts iOS-only userId arg`() = runTest {
        // Dart's wire ships `userId` for iOS parity; Android SDK uses internal
        // currentUserId. Handler drops the arg without rejecting.
        coEvery { ZeroSettle.cancelSubscription("com.app.sub", false) } returns Result.success(Unit)
        val result = newResult()

        handler.handle(
            call(
                "cancelSubscription",
                mapOf("productId" to "com.app.sub", "userId" to "user_123"),
            ),
            result,
        )

        coVerify { ZeroSettle.cancelSubscription("com.app.sub", false) }
        verify(exactly = 0) { result.error(any(), any(), any()) }
    }

    @Test
    fun `cancelSubscription errors on missing productId`() {
        val result = newResult()

        handler.handle(call("cancelSubscription", emptyMap<String, Any?>()), result)

        verify { result.error("INVALID_ARGUMENTS", "productId is required", null) }
        coVerify(exactly = 0) { ZeroSettle.cancelSubscription(any(), any()) }
    }

    @Test
    fun `cancelSubscription maps SDK throw to sdk_error`() = runTest {
        coEvery { ZeroSettle.cancelSubscription(any(), any()) } throws RuntimeException("boom")
        val result = newResult()

        handler.handle(call("cancelSubscription", mapOf("productId" to "com.app.sub")), result)

        verify { result.error("sdk_error", "boom", null) }
    }

    @Test
    fun `cancelSubscription maps UserNotIdentified to user_not_identified wire code`() = runTest {
        coEvery { ZeroSettle.cancelSubscription(any(), any()) } returns Result.failure(
            ZeroSettleError.UserNotIdentified,
        )
        val result = newResult()

        handler.handle(call("cancelSubscription", mapOf("productId" to "com.app.sub")), result)

        verify { result.error(eq("user_not_identified"), any(), null) }
    }

    // ─── pauseSubscription ──────────────────────────────────────────────

    @Test
    fun `pauseSubscription happy path returns resumesAt string from SDK`() = runTest {
        coEvery { ZeroSettle.pauseSubscription("com.app.sub", 30) } returns Result.success(
            "2026-06-12T00:00:00Z",
        )
        val result = newResult()

        handler.handle(
            call(
                "pauseSubscription",
                mapOf("productId" to "com.app.sub", "pauseDurationDays" to 30),
            ),
            result,
        )

        coVerify { ZeroSettle.pauseSubscription("com.app.sub", 30) }
        verify { result.success("2026-06-12T00:00:00Z") }
    }

    @Test
    fun `pauseSubscription accepts legacy pauseOptionId arg as duration days`() = runTest {
        // Mirrors iOS line 682 fallback. Dart's legacy 1.2.x wire shipped
        // `pauseOptionId`; new wire uses `pauseDurationDays`. Both route to
        // the same SDK arg.
        coEvery { ZeroSettle.pauseSubscription("com.app.sub", 14) } returns Result.success(null)
        val result = newResult()

        handler.handle(
            call(
                "pauseSubscription",
                mapOf("productId" to "com.app.sub", "pauseOptionId" to 14),
            ),
            result,
        )

        coVerify { ZeroSettle.pauseSubscription("com.app.sub", 14) }
    }

    @Test
    fun `pauseSubscription happy path with null resumesAt returns success(null)`() = runTest {
        // SDK contract: Result<String?> — null means backend didn't return a
        // resume timestamp (indefinite pause). Pass-through to result.success.
        coEvery { ZeroSettle.pauseSubscription("com.app.sub", null) } returns Result.success(null)
        val result = newResult()

        handler.handle(
            call("pauseSubscription", mapOf("productId" to "com.app.sub")),
            result,
        )

        coVerify { ZeroSettle.pauseSubscription("com.app.sub", null) }
        verify { result.success(null) }
    }

    @Test
    fun `pauseSubscription errors on missing productId`() {
        val result = newResult()

        handler.handle(call("pauseSubscription", emptyMap<String, Any?>()), result)

        verify { result.error("INVALID_ARGUMENTS", "productId is required", null) }
        coVerify(exactly = 0) { ZeroSettle.pauseSubscription(any(), any()) }
    }

    @Test
    fun `pauseSubscription maps NoActiveSubscription to wire code`() = runTest {
        coEvery { ZeroSettle.pauseSubscription(any(), any()) } returns Result.failure(
            ZeroSettleError.NoActiveSubscription("com.app.sub"),
        )
        val result = newResult()

        handler.handle(call("pauseSubscription", mapOf("productId" to "com.app.sub")), result)

        verify { result.error(eq("no_active_subscription"), any(), null) }
    }

    // ─── resumeSubscription ─────────────────────────────────────────────

    @Test
    fun `resumeSubscription happy path returns success(null)`() = runTest {
        coEvery { ZeroSettle.resumeSubscription("com.app.sub") } returns Result.success(Unit)
        val result = newResult()

        handler.handle(
            call("resumeSubscription", mapOf("productId" to "com.app.sub")),
            result,
        )

        coVerify { ZeroSettle.resumeSubscription("com.app.sub") }
        verify { result.success(null) }
    }

    @Test
    fun `resumeSubscription errors on missing productId`() {
        val result = newResult()

        handler.handle(call("resumeSubscription", emptyMap<String, Any?>()), result)

        verify { result.error("INVALID_ARGUMENTS", "productId is required", null) }
        coVerify(exactly = 0) { ZeroSettle.resumeSubscription(any()) }
    }

    @Test
    fun `resumeSubscription maps NoActiveSubscription to wire code`() = runTest {
        coEvery { ZeroSettle.resumeSubscription(any()) } returns Result.failure(
            ZeroSettleError.NoActiveSubscription("com.app.sub"),
        )
        val result = newResult()

        handler.handle(call("resumeSubscription", mapOf("productId" to "com.app.sub")), result)

        verify { result.error(eq("no_active_subscription"), any(), null) }
    }

    // ─── openCustomerPortal / showManageSubscription (match iOS not_implemented) ───

    @Test
    fun `openCustomerPortal returns not_implemented matching iOS`() {
        // ZeroSettleKit dropped openCustomerPortal/showManageSubscription;
        // iOS dispatch stubs both as not_implemented (Swift plugin line 596).
        // Android has no analogue either — match iOS exactly.
        val result = newResult()

        handler.handle(call("openCustomerPortal", mapOf("userId" to "user_1")), result)

        verify { result.error(eq("not_implemented"), any(), null) }
    }

    @Test
    fun `showManageSubscription returns not_implemented matching iOS`() {
        val result = newResult()

        handler.handle(call("showManageSubscription", mapOf("userId" to "user_1")), result)

        verify { result.error(eq("not_implemented"), any(), null) }
    }

    // ─── Save-the-Sale headless surface (iOS-only per product decision) ───

    @Test
    fun `acceptSaveOffer returns not_implemented for save-the-sale iOS-only`() {
        val result = newResult()

        handler.handle(
            call("acceptSaveOffer", mapOf("productId" to "x", "userId" to "u")),
            result,
        )

        verify { result.error(eq("not_implemented"), any(), null) }
    }

    @Test
    fun `submitCancelFlowResponse returns not_implemented for save-the-sale iOS-only`() {
        val result = newResult()

        handler.handle(call("submitCancelFlowResponse", emptyMap<String, Any?>()), result)

        verify { result.error(eq("not_implemented"), any(), null) }
    }

    @Test
    fun `getCancelFlowConfig returns not_implemented for save-the-sale iOS-only`() {
        val result = newResult()

        handler.handle(call("getCancelFlowConfig"), result)

        verify { result.error(eq("not_implemented"), any(), null) }
    }

    @Test
    fun `fetchCancelFlowConfig returns not_implemented for save-the-sale iOS-only`() {
        val result = newResult()

        handler.handle(call("fetchCancelFlowConfig", mapOf("userId" to "u")), result)

        verify { result.error(eq("not_implemented"), any(), null) }
    }
}
