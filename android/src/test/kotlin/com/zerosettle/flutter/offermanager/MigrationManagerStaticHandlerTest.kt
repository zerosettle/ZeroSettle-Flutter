package com.zerosettle.flutter.offermanager

import com.zerosettle.sdk.ZeroSettle
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
 * Unit tests for [MigrationManagerStaticHandler].
 *
 * Same structure as [OfferManagerStaticHandlerTest] — both handlers route to
 * the same `OfferDismissalStore` on Android. The key difference is that
 * `resetDismissedState` is a **no-op** here: calling
 * `ZeroSettle.resetOfferDismissedState()` from the migration-static channel
 * would conflate iOS's two separate dismissal stores (migration-tip vs
 * offer-tip). This suite verifies that no-op contract explicitly.
 */
@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
class MigrationManagerStaticHandlerTest {

    private val scope = CoroutineScope(SupervisorJob() + UnconfinedTestDispatcher())
    private lateinit var handler: MigrationManagerStaticHandler

    @Before
    fun setUp() {
        mockkObject(ZeroSettle)
        handler = MigrationManagerStaticHandler(scope)
    }

    @After
    fun tearDown() {
        unmockkObject(ZeroSettle)
        scope.cancel()
    }

    // --- isPermanentlyDismissed -------------------------------------------

    @Test
    fun `isPermanentlyDismissed returns SDK value`() = runTest {
        coEvery { ZeroSettle.isOfferPermanentlyDismissed("alice") } returns true
        val result = mockk<MethodChannel.Result>(relaxed = true)

        handler.onMethodCall(
            MethodCall("isPermanentlyDismissed", mapOf("userId" to "alice")),
            result,
        )

        coVerify { ZeroSettle.isOfferPermanentlyDismissed("alice") }
        verify { result.success(true) }
    }

    @Test
    fun `isPermanentlyDismissed forwards false SDK value`() = runTest {
        coEvery { ZeroSettle.isOfferPermanentlyDismissed("bob") } returns false
        val result = mockk<MethodChannel.Result>(relaxed = true)

        handler.onMethodCall(
            MethodCall("isPermanentlyDismissed", mapOf("userId" to "bob")),
            result,
        )

        verify { result.success(false) }
    }

    @Test
    fun `isPermanentlyDismissed errors on missing userId`() {
        val result = mockk<MethodChannel.Result>(relaxed = true)

        handler.onMethodCall(MethodCall("isPermanentlyDismissed", emptyMap<String, Any?>()), result)

        verify { result.error("INVALID_ARGUMENTS", "userId required", null) }
    }

    @Test
    fun `isPermanentlyDismissed errors on null args`() {
        val result = mockk<MethodChannel.Result>(relaxed = true)

        handler.onMethodCall(MethodCall("isPermanentlyDismissed", null), result)

        verify { result.error("INVALID_ARGUMENTS", "userId required", null) }
    }

    @Test
    fun `isPermanentlyDismissed maps SDK throw to sdk_error`() = runTest {
        coEvery { ZeroSettle.isOfferPermanentlyDismissed(any()) } throws
            RuntimeException("not configured")
        val result = mockk<MethodChannel.Result>(relaxed = true)

        handler.onMethodCall(
            MethodCall("isPermanentlyDismissed", mapOf("userId" to "alice")),
            result,
        )

        verify { result.error("sdk_error", "not configured", null) }
    }

    @Test
    fun `isPermanentlyDismissed maps typed ZeroSettleError to its wire code`() = runTest {
        coEvery { ZeroSettle.isOfferPermanentlyDismissed(any()) } throws
            com.zerosettle.sdk.models.ZeroSettleError.NotConfigured
        val result = mockk<MethodChannel.Result>(relaxed = true)

        handler.onMethodCall(
            MethodCall("isPermanentlyDismissed", mapOf("userId" to "alice")),
            result,
        )

        verify { result.error("not_configured", any(), null) }
    }

    // --- setDismissed -----------------------------------------------------

    @Test
    fun `setDismissed forwards both args to SDK`() = runTest {
        coEvery { ZeroSettle.setOfferDismissed("alice", true) } returns Unit
        val result = mockk<MethodChannel.Result>(relaxed = true)

        handler.onMethodCall(
            MethodCall("setDismissed", mapOf("userId" to "alice", "dismissed" to true)),
            result,
        )

        coVerify { ZeroSettle.setOfferDismissed("alice", true) }
        verify { result.success(null) }
    }

    @Test
    fun `setDismissed forwards false`() = runTest {
        coEvery { ZeroSettle.setOfferDismissed("alice", false) } returns Unit
        val result = mockk<MethodChannel.Result>(relaxed = true)

        handler.onMethodCall(
            MethodCall("setDismissed", mapOf("userId" to "alice", "dismissed" to false)),
            result,
        )

        coVerify { ZeroSettle.setOfferDismissed("alice", false) }
    }

    @Test
    fun `setDismissed errors on missing userId`() {
        val result = mockk<MethodChannel.Result>(relaxed = true)

        handler.onMethodCall(
            MethodCall("setDismissed", mapOf("dismissed" to true)),
            result,
        )

        verify { result.error("INVALID_ARGUMENTS", "userId + dismissed required", null) }
    }

    @Test
    fun `setDismissed errors on missing dismissed flag`() {
        val result = mockk<MethodChannel.Result>(relaxed = true)

        handler.onMethodCall(
            MethodCall("setDismissed", mapOf("userId" to "alice")),
            result,
        )

        verify { result.error("INVALID_ARGUMENTS", "userId + dismissed required", null) }
    }

    @Test
    fun `setDismissed maps SDK throw to sdk_error`() = runTest {
        coEvery { ZeroSettle.setOfferDismissed(any(), any()) } throws
            RuntimeException("boom")
        val result = mockk<MethodChannel.Result>(relaxed = true)

        handler.onMethodCall(
            MethodCall("setDismissed", mapOf("userId" to "alice", "dismissed" to true)),
            result,
        )

        verify { result.error("sdk_error", "boom", null) }
    }

    // --- resetDismissedState — deliberate no-op --------------------------

    @Test
    fun `resetDismissedState is a no-op and does NOT call resetOfferDismissedState`() {
        // Android has a single OfferDismissalStore backing both migration-tip
        // and offer-tip dismissals. Calling resetOfferDismissedState() here
        // would conflate the two iOS-distinct stores. Verify the no-op contract.
        val result = mockk<MethodChannel.Result>(relaxed = true)

        handler.onMethodCall(MethodCall("resetDismissedState", null), result)

        verify { result.success(null) }
        coVerify(exactly = 0) { ZeroSettle.resetOfferDismissedState() }
    }

    // --- unknown method ---------------------------------------------------

    @Test
    fun `unknown method returns notImplemented`() {
        val result = mockk<MethodChannel.Result>(relaxed = true)

        handler.onMethodCall(MethodCall("garbage", null), result)

        verify { result.notImplemented() }
    }
}
