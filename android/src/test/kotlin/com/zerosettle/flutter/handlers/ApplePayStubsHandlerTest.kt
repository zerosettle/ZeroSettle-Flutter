package com.zerosettle.flutter.handlers

import android.app.Activity
import android.content.Context
import com.google.common.truth.Truth.assertThat
import com.zerosettle.sdk.ZeroSettle
import com.zerosettle.sdk.models.ZeroSettleError
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.mockk.CapturingSlot
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkObject
import io.mockk.slot
import io.mockk.unmockkObject
import io.mockk.verify
import java.util.UUID
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * Unit tests for [ApplePayStubsHandler].
 *
 * The handler is fully synchronous (no SDK calls, no coroutines) so the
 * scope / activity / context dependencies are unused at runtime. We still
 * pass them in matching the F8-F13 pattern for consistency.
 *
 * Wire-shape claims under test:
 *   - `recommendedAppAccountToken` forwards to
 *     `ZeroSettle.recommendedAppAccountToken().toString()`. The Android SDK
 *     derives the same `(userId, packageName)` UUID iOS Kit returns, so
 *     this is in-contract for the Dart `Future<String>` wire. Failures
 *     (UserNotIdentified / NotConfigured) surface as `PlatformException`.
 *   - `presentApplePaySetup` returns `not_implemented` error (iOS Wallet
 *     only; no Android analogue).
 *   - `getIsApplePayOnly` returns `success(false)` (Android is never
 *     Apple-Pay-only).
 *   - `getApplePayState` returns `success("unavailable")` per the
 *     plugin-header Known-gaps contract (NOT a `not_implemented` error —
 *     that would break adopters that switch on the
 *     `ApplePayAvailabilityState` enum string).
 *   - Unknown method → `handle` returns `false` so the plugin can fall
 *     through to the next handler / WIP error.
 *   - Each `not_implemented` message names the offending method so devs
 *     reading logs can find the call site.
 */
@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
class ApplePayStubsHandlerTest {

    private val scope = CoroutineScope(SupervisorJob() + UnconfinedTestDispatcher())
    private val appContext: Context = mockk(relaxed = true)
    private val activity: Activity = mockk(relaxed = true)
    private lateinit var handler: ApplePayStubsHandler

    @Before
    fun setUp() {
        mockkObject(ZeroSettle)
        val deps = HandlerDependencies(
            scope = scope,
            activityProvider = { activity },
            applicationContextProvider = { appContext },
        )
        handler = ApplePayStubsHandler(deps)
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
        // Stub the SDK boundary so the recommendedAppAccountToken case
        // doesn't blow up on an unmocked static call.
        every { ZeroSettle.recommendedAppAccountToken() } returns UUID.randomUUID()

        listOf(
            "recommendedAppAccountToken",
            "presentApplePaySetup",
            "getIsApplePayOnly",
            "getApplePayState",
        ).forEach { method ->
            val consumed = handler.handle(call(method), newResult())
            assertThat(consumed).isTrue()
        }
    }

    // ─── recommendedAppAccountToken — typed UUID pass-through ──────────

    @Test
    fun `recommendedAppAccountToken returns stringified UUID from SDK`() {
        val token = UUID.fromString("01234567-89ab-cdef-0123-456789abcdef")
        every { ZeroSettle.recommendedAppAccountToken() } returns token

        val result = newResult()
        val consumed = handler.handle(call("recommendedAppAccountToken"), result)

        assertThat(consumed).isTrue()
        verify { result.success("01234567-89ab-cdef-0123-456789abcdef") }
        verify(exactly = 0) { result.error(any(), any(), any()) }
    }

    @Test
    fun `recommendedAppAccountToken surfaces SDK errors via sendError`() {
        // The SDK throws ZeroSettleError.UserNotIdentified when called
        // before identify(); make sure that maps to the typed wire code
        // so Dart can pattern-match it.
        every { ZeroSettle.recommendedAppAccountToken() } throws
            ZeroSettleError.UserNotIdentified

        val result = newResult()
        val consumed = handler.handle(call("recommendedAppAccountToken"), result)

        assertThat(consumed).isTrue()
        verify { result.error(eq("user_not_identified"), any(), any()) }
        verify(exactly = 0) { result.success(any()) }
    }

    // ─── presentApplePaySetup ────────────────────────────────────────────

    @Test
    fun `presentApplePaySetup returns not_implemented error`() {
        val result = newResult()
        val codeSlot: CapturingSlot<String> = slot()
        val messageSlot: CapturingSlot<String> = slot()

        val consumed = handler.handle(call("presentApplePaySetup"), result)

        assertThat(consumed).isTrue()
        verify { result.error(capture(codeSlot), capture(messageSlot), null) }
        verify(exactly = 0) { result.success(any()) }
        assertThat(codeSlot.captured).isEqualTo("not_implemented")
        assertThat(messageSlot.captured).contains("presentApplePaySetup")
        assertThat(messageSlot.captured).contains("Platform.isIOS")
    }

    // ─── getIsApplePayOnly ───────────────────────────────────────────────

    @Test
    fun `getIsApplePayOnly returns success false`() {
        val result = newResult()
        val consumed = handler.handle(call("getIsApplePayOnly"), result)

        assertThat(consumed).isTrue()
        verify { result.success(false) }
        verify(exactly = 0) { result.error(any(), any(), any()) }
    }

    // ─── getApplePayState ────────────────────────────────────────────────

    @Test
    fun `getApplePayState returns success with literal string unavailable`() {
        // The plugin-header doc pins this to the literal "unavailable" so
        // the Dart-side `ApplePayAvailabilityState` enum decodes cleanly.
        // Returning a `not_implemented` error here would break callers
        // that switch on the state string (the iOS Kit's three values are
        // "ready" / "setupRequired" / "unavailable"; Android is always the
        // third).
        val result = newResult()
        val consumed = handler.handle(call("getApplePayState"), result)

        assertThat(consumed).isTrue()
        verify { result.success("unavailable") }
        verify(exactly = 0) { result.error(any(), any(), any()) }
    }
}
