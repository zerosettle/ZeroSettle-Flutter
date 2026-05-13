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
 * Unit tests for [OfferManagerStaticHandler].
 *
 * Stubs `ZeroSettle.isOfferPermanentlyDismissed` / `setOfferDismissed` /
 * `resetOfferDismissedState` via `mockkObject(ZeroSettle)` — same pattern
 * as `OfferManagerHandleRegistryTest`. The real SDK methods throw
 * `NotConfigured` without a configured backend; mocking lets us pin the
 * handler's behaviour without bootstrapping.
 *
 * `UnconfinedTestDispatcher` runs `scope.launch { ... }` synchronously so
 * `verify { result.success(...) }` fires after the suspending SDK call
 * resolves — without it the verify runs before the coroutine completes.
 */
@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
class OfferManagerStaticHandlerTest {

    private val scope = CoroutineScope(SupervisorJob() + UnconfinedTestDispatcher())
    private lateinit var handler: OfferManagerStaticHandler

    @Before
    fun setUp() {
        mockkObject(ZeroSettle)
        handler = OfferManagerStaticHandler(scope)
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

        verify {
            result.error("INVALID_ARGUMENTS", "userId required", null)
        }
    }

    @Test
    fun `isPermanentlyDismissed errors on null args`() {
        val result = mockk<MethodChannel.Result>(relaxed = true)

        handler.onMethodCall(MethodCall("isPermanentlyDismissed", null), result)

        verify {
            result.error("INVALID_ARGUMENTS", "userId required", null)
        }
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

    // --- resetDismissedState ----------------------------------------------

    @Test
    fun `resetDismissedState calls SDK with no args`() = runTest {
        coEvery { ZeroSettle.resetOfferDismissedState() } returns Unit
        val result = mockk<MethodChannel.Result>(relaxed = true)

        handler.onMethodCall(MethodCall("resetDismissedState", null), result)

        coVerify { ZeroSettle.resetOfferDismissedState() }
        verify { result.success(null) }
    }

    @Test
    fun `resetDismissedState maps SDK throw to sdk_error`() = runTest {
        coEvery { ZeroSettle.resetOfferDismissedState() } throws RuntimeException("nope")
        val result = mockk<MethodChannel.Result>(relaxed = true)

        handler.onMethodCall(MethodCall("resetDismissedState", null), result)

        verify { result.error("sdk_error", "nope", null) }
    }

    // --- unknown method ---------------------------------------------------

    @Test
    fun `unknown method returns notImplemented`() {
        val result = mockk<MethodChannel.Result>(relaxed = true)

        handler.onMethodCall(MethodCall("garbage", null), result)

        verify { result.notImplemented() }
    }
}
