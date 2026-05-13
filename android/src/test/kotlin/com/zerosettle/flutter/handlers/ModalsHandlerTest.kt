package com.zerosettle.flutter.handlers

import android.app.Activity
import android.content.Context
import com.google.common.truth.Truth.assertThat
import com.zerosettle.sdk.ZeroSettle
import com.zerosettle.sdk.models.UpgradeOffer
import com.zerosettle.sdk.models.ZeroSettleError
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.mockk.CapturingSlot
import io.mockk.coEvery
import io.mockk.coVerify
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
 * Unit tests for [ModalsHandler].
 *
 * Same setup pattern as [SubscriptionMgmtHandlerTest] — `mockkObject(ZeroSettle)`,
 * `UnconfinedTestDispatcher` so `scope.launch { ... }` resolves synchronously,
 * SDK boundaries stubbed.
 *
 * Wire-shape claims under test:
 *   - `handle` routes the three F13 methods (`presentCancelFlow`,
 *     `presentUpgradeOffer`, `fetchUpgradeOfferConfig`) and returns `false`
 *     for unknown methods.
 *   - `presentCancelFlow` returns `not_implemented` with a message naming
 *     the method (save-the-sale modal is iOS-only forever).
 *   - `presentUpgradeOffer` returns `not_implemented` with a message
 *     pointing adopters at the Unified Offer System (OfferManager +
 *     MigrationTipView); the imperative API is being deprecated.
 *   - `fetchUpgradeOfferConfig` happy path forwards to
 *     `ZeroSettle.fetchUpgradeOfferConfig(productId)` and returns the
 *     encoded config map.
 *   - `fetchUpgradeOfferConfig` accepts `productId == null` (any-product
 *     query) and forwards `null` to the SDK.
 *   - `fetchUpgradeOfferConfig` silently accepts the iOS-only `userId` arg
 *     (matches F12 pattern — SDK reads currentUserId internally).
 *   - `fetchUpgradeOfferConfig` SDK throw → `sdk_error` via shared
 *     `sendError` extension.
 *   - `fetchUpgradeOfferConfig` SDK `Result.failure(UserNotIdentified)` →
 *     `user_not_identified` wire code.
 *   - `fetchUpgradeOfferConfig` SDK `Result.failure(NetworkError)` →
 *     `network_error` wire code (covers the chunk-5 decode-failure path).
 */
@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
class ModalsHandlerTest {

    private val scope = CoroutineScope(SupervisorJob() + UnconfinedTestDispatcher())
    private val appContext: Context = mockk(relaxed = true)
    private val activity: Activity = mockk(relaxed = true)
    private lateinit var handler: ModalsHandler

    @Before
    fun setUp() {
        mockkObject(ZeroSettle)
        val deps = HandlerDependencies(
            scope = scope,
            activityProvider = { activity },
            applicationContextProvider = { appContext },
        )
        handler = ModalsHandler(deps)
    }

    @After
    fun tearDown() {
        unmockkObject(ZeroSettle)
        scope.cancel()
    }

    private fun call(method: String, args: Map<String, Any?>? = null) = MethodCall(method, args)
    private fun newResult() = mockk<MethodChannel.Result>(relaxed = true)

    private fun sampleConfig() = UpgradeOffer.Config(
        fromProductId = "com.app.weekly",
        toProductId = "com.app.monthly",
        savingsPercent = 20,
        display = UpgradeOffer.Display(
            offerTitle = "Save 20%",
            offerMessage = "Switch to monthly",
            offerCta = "Switch",
            acceptedTitle = "Done",
            acceptedMessage = "You're on monthly now",
            acceptedCta = "OK",
            completedTitle = "All set",
            completedMessage = "Enjoy your savings",
        ),
    )

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
        // Stub the suspend method so the fetchUpgradeOfferConfig branch
        // doesn't actually call the network. The two stub branches return
        // synchronously.
        coEvery { ZeroSettle.fetchUpgradeOfferConfig(any()) } returns Result.failure(
            ZeroSettleError.UserNotIdentified,
        )
        listOf(
            "presentCancelFlow" to mapOf("productId" to "x"),
            "presentUpgradeOffer" to mapOf("productId" to "x"),
            "fetchUpgradeOfferConfig" to null,
        ).forEach { (method, args) ->
            val consumed = handler.handle(call(method, args), newResult())
            assertThat(consumed).isTrue()
        }
    }

    // ─── presentCancelFlow / presentUpgradeOffer — not exposed on Android ──

    @Test
    fun `presentCancelFlow returns not_implemented (iOS-only save-the-sale)`() {
        val result = newResult()
        val codeSlot: CapturingSlot<String> = slot()
        val messageSlot: CapturingSlot<String> = slot()

        handler.handle(
            call("presentCancelFlow", mapOf("productId" to "com.app.sub", "userId" to "u")),
            result,
        )

        verify { result.error(capture(codeSlot), capture(messageSlot), null) }
        assertThat(codeSlot.captured).isEqualTo("not_implemented")
        assertThat(messageSlot.captured).contains("presentCancelFlow")
    }

    @Test
    fun `presentUpgradeOffer returns not_implemented pointing at Unified Offer System`() {
        // The imperative one-shot upgrade-offer API is being deprecated
        // platform-wide; the message should point adopters at the Unified
        // Offer System (OfferManager + MigrationTipView).
        val result = newResult()
        val codeSlot: CapturingSlot<String> = slot()
        val messageSlot: CapturingSlot<String> = slot()

        handler.handle(
            call("presentUpgradeOffer", mapOf("productId" to "com.app.sub")),
            result,
        )

        verify { result.error(capture(codeSlot), capture(messageSlot), null) }
        assertThat(codeSlot.captured).isEqualTo("not_implemented")
        assertThat(messageSlot.captured).contains("presentUpgradeOffer")
        assertThat(messageSlot.captured).contains("OfferManager")
    }

    // ─── fetchUpgradeOfferConfig ────────────────────────────────────────

    @Test
    fun `fetchUpgradeOfferConfig happy path returns encoded config map`() = runTest {
        val config = sampleConfig()
        coEvery { ZeroSettle.fetchUpgradeOfferConfig("com.app.monthly") } returns Result.success(config)
        val result = newResult()
        val mapSlot: CapturingSlot<Map<String, Any?>> = slot()

        handler.handle(
            call("fetchUpgradeOfferConfig", mapOf("productId" to "com.app.monthly")),
            result,
        )

        coVerify { ZeroSettle.fetchUpgradeOfferConfig("com.app.monthly") }
        verify { result.success(capture(mapSlot)) }
        verify(exactly = 0) { result.error(any(), any(), any()) }

        // Wire shape: camelCase keys mirroring the encoder in ModelToFlutterMap.
        assertThat(mapSlot.captured["fromProductId"]).isEqualTo("com.app.weekly")
        assertThat(mapSlot.captured["toProductId"]).isEqualTo("com.app.monthly")
        assertThat(mapSlot.captured["savingsPercent"]).isEqualTo(20)
        @Suppress("UNCHECKED_CAST")
        val display = mapSlot.captured["display"] as Map<String, Any?>
        assertThat(display["offerTitle"]).isEqualTo("Save 20%")
    }

    @Test
    fun `fetchUpgradeOfferConfig with null productId forwards null to SDK`() = runTest {
        // The Dart wire treats productId as optional. iOS routes to the
        // no-productId overload; Android's SDK takes a nullable String.
        // Verify we forward null without rejecting the call.
        coEvery { ZeroSettle.fetchUpgradeOfferConfig(null) } returns Result.success(sampleConfig())
        val result = newResult()

        handler.handle(call("fetchUpgradeOfferConfig", null), result)

        coVerify { ZeroSettle.fetchUpgradeOfferConfig(null) }
        verify(exactly = 0) { result.error(any(), any(), any()) }
    }

    @Test
    fun `fetchUpgradeOfferConfig silently accepts iOS-only userId arg`() = runTest {
        // iOS plugin accepts an optional userId and routes to a userId-arg
        // overload. Android SDK only has the no-userId variant — the
        // handler must accept the arg without rejecting (matches F12
        // pattern). Currently-identified-user resolves inside the SDK.
        coEvery { ZeroSettle.fetchUpgradeOfferConfig("com.app.monthly") } returns Result.success(sampleConfig())
        val result = newResult()

        handler.handle(
            call(
                "fetchUpgradeOfferConfig",
                mapOf("productId" to "com.app.monthly", "userId" to "user_123"),
            ),
            result,
        )

        coVerify { ZeroSettle.fetchUpgradeOfferConfig("com.app.monthly") }
        verify(exactly = 0) { result.error(any(), any(), any()) }
    }

    @Test
    fun `fetchUpgradeOfferConfig maps SDK throw to sdk_error`() = runTest {
        coEvery { ZeroSettle.fetchUpgradeOfferConfig(any()) } throws RuntimeException("boom")
        val result = newResult()

        handler.handle(call("fetchUpgradeOfferConfig", null), result)

        verify { result.error("sdk_error", "boom", null) }
    }

    @Test
    fun `fetchUpgradeOfferConfig maps UserNotIdentified to user_not_identified wire code`() = runTest {
        coEvery { ZeroSettle.fetchUpgradeOfferConfig(any()) } returns Result.failure(
            ZeroSettleError.UserNotIdentified,
        )
        val result = newResult()

        handler.handle(call("fetchUpgradeOfferConfig", null), result)

        verify { result.error(eq("user_not_identified"), any(), null) }
    }

    @Test
    fun `fetchUpgradeOfferConfig maps NetworkError to network_error wire code`() = runTest {
        // Covers the chunk-5 decode-failure path: when the backend response
        // doesn't match the placeholder UpgradeOffer.Config schema, the
        // SDK's mapDecode wraps the MissingFieldException in NetworkError.
        // The handler must surface it as wire code `network_error` for
        // Dart pattern-matching.
        coEvery { ZeroSettle.fetchUpgradeOfferConfig(any()) } returns Result.failure(
            ZeroSettleError.NetworkError(RuntimeException("decode failed")),
        )
        val result = newResult()

        handler.handle(call("fetchUpgradeOfferConfig", null), result)

        verify { result.error(eq("network_error"), any(), null) }
    }
}
