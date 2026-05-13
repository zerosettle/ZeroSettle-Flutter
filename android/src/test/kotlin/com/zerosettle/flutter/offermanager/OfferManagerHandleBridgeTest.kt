package com.zerosettle.flutter.offermanager

import com.google.common.truth.Truth.assertThat
import com.zerosettle.sdk.models.UserOffer
import com.zerosettle.sdk.offers.OfferManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import io.mockk.verify
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * Unit tests for [OfferManagerHandleBridge]. Stubs an [OfferManager] with
 * [MutableStateFlow]-backed properties so we can drive state changes and
 * assert that the state channel re-emits a composite snapshot.
 *
 * Channel stubs: real [MethodChannel] / [EventChannel] would require a
 * Flutter engine; we mock both, capture their handlers via `slot`, and drive
 * them directly. This is the same pattern used in
 * `OfferManagerHandleRegistryTest`.
 *
 * `UnconfinedTestDispatcher` makes `entry.scope.launch { ... }` run
 * synchronously so `verify`/`coVerify` fires after the suspending SDK call
 * resolves.
 */
@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
class OfferManagerHandleBridgeTest {

    private val scope = CoroutineScope(SupervisorJob() + UnconfinedTestDispatcher())

    private lateinit var manager: OfferManager
    private lateinit var methodChannel: MethodChannel
    private lateinit var stateChannel: EventChannel
    private lateinit var entry: OfferManagerHandleRegistry.Entry

    // SDK StateFlow stubs.
    private val stateFlow = MutableStateFlow(OfferManager.OfferState.LOADING)
    private val offerDataFlow = MutableStateFlow<UserOffer.OfferData?>(null)
    private val isLoadingFlow = MutableStateFlow(false)
    private val checkoutErrorFlow = MutableStateFlow<com.zerosettle.sdk.models.ZeroSettleError?>(null)
    private val pendingCheckoutUrlFlow = MutableStateFlow<String?>(null)

    @Before
    fun setUp() {
        manager = mockk(relaxed = true)
        every { manager.state } returns stateFlow
        every { manager.offerData } returns offerDataFlow
        every { manager.isLoading } returns isLoadingFlow
        every { manager.checkoutError } returns checkoutErrorFlow
        every { manager.pendingCheckoutUrl } returns pendingCheckoutUrlFlow

        methodChannel = mockk(relaxed = true)
        stateChannel = mockk(relaxed = true)
        entry = OfferManagerHandleRegistry.Entry(
            id = 1,
            manager = manager,
            methodChannel = methodChannel,
            stateChannel = stateChannel,
            scope = scope,
        )
    }

    @After
    fun tearDown() {
        scope.cancel()
    }

    /**
     * Starts the bridge, captures the method-channel handler that was
     * installed, and returns it so tests can invoke method calls directly
     * without needing a real Flutter engine.
     */
    private fun startAndCaptureMethodHandler(): MethodChannel.MethodCallHandler {
        val handlerSlot = slot<MethodChannel.MethodCallHandler>()
        every { methodChannel.setMethodCallHandler(capture(handlerSlot)) } returns Unit
        every { stateChannel.setStreamHandler(any()) } returns Unit
        OfferManagerHandleBridge(entry, onDispose = {}).start()
        return handlerSlot.captured
    }

    /**
     * Starts the bridge, captures the event-channel stream handler, returns it.
     */
    private fun startAndCaptureStreamHandler(
        onDispose: () -> Unit = {},
    ): EventChannel.StreamHandler {
        val streamSlot = slot<EventChannel.StreamHandler>()
        every { methodChannel.setMethodCallHandler(any()) } returns Unit
        every { stateChannel.setStreamHandler(capture(streamSlot)) } returns Unit
        OfferManagerHandleBridge(entry, onDispose = onDispose).start()
        return streamSlot.captured
    }

    // --- Method-channel routing -------------------------------------------

    @Test
    fun `getState emits composite snapshot synchronously`() {
        val handler = startAndCaptureMethodHandler()
        val result = mockk<MethodChannel.Result>(relaxed = true)

        handler.onMethodCall(MethodCall("getState", null), result)

        val mapSlot = slot<Map<String, Any?>>()
        verify { result.success(capture(mapSlot)) }
        assertThat(mapSlot.captured["state"]).isEqualTo("loading")
        assertThat(mapSlot.captured["isLoading"]).isEqualTo(false)
        assertThat(mapSlot.captured["storekitCancelRequired"]).isEqualTo(false)
    }

    @Test
    fun `present returns success without touching SDK`() {
        // Android's OfferManager has no present(); the Dart-side method is
        // @Deprecated. We return success so legacy callers don't see a spurious
        // failure but verify the manager isn't called.
        val handler = startAndCaptureMethodHandler()
        val result = mockk<MethodChannel.Result>(relaxed = true)

        handler.onMethodCall(MethodCall("present", null), result)

        verify { result.success(null) }
        // No SDK methods should have been called as a result of `present`.
        // (relaxed mock — there's no per-method verify-no-call API, but mockk's
        // `verify(exactly = 0)` covers it.)
        verify(exactly = 0) { manager.cancelPendingCheckout() }
    }

    @Test
    fun `dismiss launches manager dismiss and returns success`() = runTest {
        coEvery { manager.dismiss() } returns Unit
        val handler = startAndCaptureMethodHandler()
        val result = mockk<MethodChannel.Result>(relaxed = true)

        handler.onMethodCall(MethodCall("dismiss", null), result)

        coVerify { manager.dismiss() }
        verify { result.success(null) }
    }

    @Test
    fun `dismiss maps non-typed SDK throw to sdk_error`() = runTest {
        // Non-ZeroSettleError throwables fall through to the `sdk_error`
        // fallback in `MethodChannel.Result.sendError`.
        coEvery { manager.dismiss() } throws RuntimeException("boom")
        val handler = startAndCaptureMethodHandler()
        val result = mockk<MethodChannel.Result>(relaxed = true)

        handler.onMethodCall(MethodCall("dismiss", null), result)

        verify { result.error("sdk_error", "boom", null) }
    }

    @Test
    fun `dismiss maps typed ZeroSettleError to its wire code`() = runTest {
        // End-to-end proof that the bridge routes typed errors through the
        // shared `sendError` extension — adopters can pattern-match
        // `ZSUserNotIdentifiedException` on OfferManager calls just like every
        // other Dart API.
        coEvery { manager.dismiss() } throws com.zerosettle.sdk.models.ZeroSettleError.UserNotIdentified
        val handler = startAndCaptureMethodHandler()
        val result = mockk<MethodChannel.Result>(relaxed = true)

        handler.onMethodCall(MethodCall("dismiss", null), result)

        verify { result.error("user_not_identified", any(), null) }
    }

    @Test
    fun `startCheckout returns SDK checkoutUrl on success`() = runTest {
        coEvery { manager.checkoutUrl() } returns Result.success("https://checkout.example/abc")
        val handler = startAndCaptureMethodHandler()
        val result = mockk<MethodChannel.Result>(relaxed = true)

        handler.onMethodCall(
            MethodCall("startCheckout", mapOf("stripeCustomerId" to "cus_123")),
            result,
        )

        coVerify { manager.checkoutUrl() }
        verify { result.success("https://checkout.example/abc") }
    }

    @Test
    fun `startCheckout passes through null URL for web-to-web upgrades`() = runTest {
        // SDK returns Result.success(null) for upgrade_web_to_web (no WebView).
        // Dart's startCheckout doc tolerates null.
        coEvery { manager.checkoutUrl() } returns Result.success(null)
        val handler = startAndCaptureMethodHandler()
        val result = mockk<MethodChannel.Result>(relaxed = true)

        handler.onMethodCall(MethodCall("startCheckout", null), result)

        verify { result.success(null) }
    }

    @Test
    fun `startCheckout maps non-typed SDK failure to sdk_error`() = runTest {
        // Non-ZeroSettleError failure → fallback wire code.
        coEvery { manager.checkoutUrl() } returns
            Result.failure(RuntimeException("network down"))
        val handler = startAndCaptureMethodHandler()
        val result = mockk<MethodChannel.Result>(relaxed = true)

        handler.onMethodCall(MethodCall("startCheckout", null), result)

        verify { result.error("sdk_error", "network down", null) }
    }

    @Test
    fun `preloadCheckout returns null without calling SDK`() {
        // iOS-only optimization. The Dart-side docstring at
        // lib/managers/offer_manager.dart:108-118 explicitly tolerates null.
        val handler = startAndCaptureMethodHandler()
        val result = mockk<MethodChannel.Result>(relaxed = true)

        handler.onMethodCall(MethodCall("preloadCheckout", null), result)

        verify { result.success(null) }
    }

    @Test
    fun `markCheckoutSucceeded forwards transactionId to SDK A6 overload`() = runTest {
        coEvery { manager.onWebCheckoutSucceeded("txn_42") } returns Unit
        val handler = startAndCaptureMethodHandler()
        val result = mockk<MethodChannel.Result>(relaxed = true)

        handler.onMethodCall(
            MethodCall("markCheckoutSucceeded", mapOf("transactionId" to "txn_42")),
            result,
        )

        coVerify { manager.onWebCheckoutSucceeded("txn_42") }
        verify { result.success(null) }
    }

    @Test
    fun `markCheckoutSucceeded forwards null transactionId`() = runTest {
        coEvery { manager.onWebCheckoutSucceeded(null) } returns Unit
        val handler = startAndCaptureMethodHandler()
        val result = mockk<MethodChannel.Result>(relaxed = true)

        handler.onMethodCall(MethodCall("markCheckoutSucceeded", null), result)

        coVerify { manager.onWebCheckoutSucceeded(null) }
        verify { result.success(null) }
    }

    @Test
    fun `showAppleSubscriptionManagement returns not_implemented error`() {
        val handler = startAndCaptureMethodHandler()
        val result = mockk<MethodChannel.Result>(relaxed = true)

        handler.onMethodCall(MethodCall("showAppleSubscriptionManagement", null), result)

        verify {
            result.error(
                "not_implemented",
                "showAppleSubscriptionManagement is iOS-only; Android has no analogue",
                null,
            )
        }
    }

    @Test
    fun `disposeHandle invokes the onDispose lambda`() {
        var disposed = false
        val streamSlot = slot<EventChannel.StreamHandler>()
        val methodSlot = slot<MethodChannel.MethodCallHandler>()
        every { methodChannel.setMethodCallHandler(capture(methodSlot)) } returns Unit
        every { stateChannel.setStreamHandler(capture(streamSlot)) } returns Unit
        OfferManagerHandleBridge(entry, onDispose = { disposed = true }).start()
        val result = mockk<MethodChannel.Result>(relaxed = true)

        methodSlot.captured.onMethodCall(MethodCall("disposeHandle", null), result)

        assertThat(disposed).isTrue()
        verify { result.success(null) }
    }

    @Test
    fun `unknown method returns notImplemented`() {
        val handler = startAndCaptureMethodHandler()
        val result = mockk<MethodChannel.Result>(relaxed = true)

        handler.onMethodCall(MethodCall("garbage", null), result)

        verify { result.notImplemented() }
    }

    // --- State-channel streaming ------------------------------------------

    @Test
    fun `onListen emits an immediate composite snapshot`() {
        val streamHandler = startAndCaptureStreamHandler()
        val sink = mockk<EventChannel.EventSink>(relaxed = true)

        streamHandler.onListen(null, sink)

        // The combine in `start` also fires its first value synchronously
        // under UnconfinedTestDispatcher (every StateFlow has an initial
        // value), so sink.success can fire more than once. Use a mutableList
        // capture and assert against the FIRST emit.
        val emits = mutableListOf<Map<String, Any?>>()
        verify(atLeast = 1) { sink.success(capture(emits)) }
        assertThat(emits).isNotEmpty()
        val first = emits.first()
        assertThat(first["state"]).isEqualTo("loading")
        assertThat(first["isLoading"]).isEqualTo(false)
        assertThat(first["storekitCancelRequired"]).isEqualTo(false)
    }

    @Test
    fun `state-flow change re-emits composite snapshot`() = runTest {
        val streamHandler = startAndCaptureStreamHandler()
        val sink = mockk<EventChannel.EventSink>(relaxed = true)

        streamHandler.onListen(null, sink)
        // First emit is the immediate snapshot. Drive a state change:
        stateFlow.value = OfferManager.OfferState.PRESENTED

        // sink.success was called at least twice — initial snapshot + the
        // re-emit triggered by the combine.
        verify(atLeast = 2) { sink.success(any()) }
    }

    @Test
    fun `onCancel cancels the collection job so further changes are not emitted`() = runTest {
        val streamHandler = startAndCaptureStreamHandler()
        val sink = mockk<EventChannel.EventSink>(relaxed = true)

        streamHandler.onListen(null, sink)
        streamHandler.onCancel(null)

        // After cancel, sink should not receive new emits. Clear the recorded
        // calls from onListen, drive a change, then verify zero new calls.
        io.mockk.clearMocks(sink, answers = false)
        stateFlow.value = OfferManager.OfferState.PRESENTED
        isLoadingFlow.value = true

        verify(exactly = 0) { sink.success(any()) }
    }

    @Test
    fun `onListen with null sink is tolerated`() {
        val streamHandler = startAndCaptureStreamHandler()

        // Should not throw and not start a collection.
        streamHandler.onListen(null, null)
    }
}
