package com.zerosettle.flutter.handlers

import android.app.Activity
import android.content.Context
import com.google.common.truth.Truth.assertThat
import com.zerosettle.sdk.ZeroSettle
import com.zerosettle.sdk.models.UserOffer
import com.zerosettle.sdk.models.ZeroSettleError
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.mockk.CapturingSlot
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
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * Unit tests for [MiscHandler].
 *
 * Mirrors [SubscriptionMgmtHandlerTest] setup — `mockkObject(ZeroSettle)`,
 * `UnconfinedTestDispatcher` so `scope.launch { ... }` resolves
 * synchronously, all SDK boundaries stubbed.
 *
 * Wire-shape claims under test (matches the handler KDoc table):
 *   - `handleUniversalLink` returns `success(false)` (no SDK API, Dart
 *     tolerates with `?? false`).
 *   - `getRemoteConfig` returns `success(null)` (no SDK API, Dart Map?
 *     return type).
 *   - `getDetectedJurisdiction` returns `success(null)` (no SDK API, Dart
 *     String? return type).
 *   - `getPendingCheckout` reads `ZeroSettle.pendingCheckout.value` and
 *     returns `success(Boolean)` synchronously.
 *   - `setBaseUrlOverride` stages the override in `BaseUrlOverrideStore`
 *     and returns `success(null)`. `IdentityHandler.configure(...)`
 *     consumes the staged value when building `ZeroSettleConfig`. Bridges
 *     Dart's "set then configure" call sequence with Android's immutable
 *     config.
 *   - `trackEvent` returns `success(null)` regardless of args (no SDK API,
 *     Dart fire-and-forget swallows errors).
 *   - `trackMigrationConversion` forwards to
 *     `ZeroSettle.trackMigrationConversion(SourceStorefront.PLAY_STORE)`
 *     and returns `success(null)`. SDK failure → `sendError`.
 *   - `resetMigrateTipState` returns `success(null)` (no SDK API; would
 *     conflate with `resetOfferDismissedState` if wired through).
 *   - `fetchTransactionHistory` returns `not_implemented` per the
 *     force-unwrap rule (SDK currently returns raw JSON, Dart wire expects
 *     typed List<Map>).
 *   - Unknown method → `handle` returns `false` so the plugin can fall
 *     through to the next handler / WIP error.
 */
@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
class MiscHandlerTest {

    private val scope = CoroutineScope(SupervisorJob() + UnconfinedTestDispatcher())
    private val appContext: Context = mockk(relaxed = true)
    private val activity: Activity = mockk(relaxed = true)
    private lateinit var handler: MiscHandler

    @Before
    fun setUp() {
        mockkObject(ZeroSettle)
        val deps = HandlerDependencies(
            scope = scope,
            activityProvider = { activity },
            applicationContextProvider = { appContext },
        )
        handler = MiscHandler(deps)
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
        // Stub the SDK boundary so suspend / StateFlow paths don't blow up.
        every { ZeroSettle.pendingCheckout } returns MutableStateFlow(false)
        coEvery { ZeroSettle.trackMigrationConversion(any()) } returns Result.failure(
            ZeroSettleError.UserNotIdentified,
        )

        listOf(
            "handleUniversalLink" to mapOf("url" to "https://example.com/checkout-success"),
            "getRemoteConfig" to null,
            "getDetectedJurisdiction" to null,
            "getPendingCheckout" to null,
            "setBaseUrlOverride" to mapOf("url" to "https://staging.example.com"),
            "trackEvent" to mapOf("eventType" to "paywall_shown", "productId" to "x"),
            "trackMigrationConversion" to mapOf("userId" to "u"),
            "resetMigrateTipState" to null,
            "fetchTransactionHistory" to mapOf("userId" to "u"),
        ).forEach { (method, args) ->
            val consumed = handler.handle(call(method, args), newResult())
            assertThat(consumed).isTrue()
        }
    }

    // ─── handleUniversalLink — no SDK API → success(false) ──────────────

    @Test
    fun `handleUniversalLink returns success(false) regardless of URL`() {
        val result = newResult()
        handler.handle(
            call("handleUniversalLink", mapOf("url" to "https://example.com/checkout-success")),
            result,
        )
        verify { result.success(false) }
        verify(exactly = 0) { result.error(any(), any(), any()) }
    }

    @Test
    fun `handleUniversalLink does not reject missing url arg`() {
        // No SDK call to make, no validation needed. Dart caller's
        // `?? false` unwrap handles any return. Important: we do NOT
        // INVALID_ARGUMENTS here, because the Dart wire's force-unwrap on
        // the bool isn't safe — but the wire shape sends `{url: ...}` so
        // null shouldn't happen in practice anyway.
        val result = newResult()
        handler.handle(call("handleUniversalLink", emptyMap<String, Any?>()), result)
        verify { result.success(false) }
        verify(exactly = 0) { result.error(any(), any(), any()) }
    }

    // ─── getRemoteConfig — no SDK API → success(null) ───────────────────

    @Test
    fun `getRemoteConfig returns success(null)`() {
        // Dart's return type is Future<Map<String, dynamic>?> — null is in
        // contract. When the Android SDK adds `remoteConfig`, this swaps to
        // forward through to the SDK without touching the wire.
        val result = newResult()
        handler.handle(call("getRemoteConfig"), result)
        verify { result.success(null) }
        verify(exactly = 0) { result.error(any(), any(), any()) }
    }

    // ─── getDetectedJurisdiction — no SDK API → success(null) ───────────

    @Test
    fun `getDetectedJurisdiction returns success(null)`() {
        // Dart's return type is Future<String?> — null is in contract.
        // Same future-swap pattern as getRemoteConfig.
        val result = newResult()
        handler.handle(call("getDetectedJurisdiction"), result)
        verify { result.success(null) }
        verify(exactly = 0) { result.error(any(), any(), any()) }
    }

    // ─── getPendingCheckout — real SDK StateFlow read ───────────────────

    @Test
    fun `getPendingCheckout returns false when SDK pendingCheckout is false`() {
        every { ZeroSettle.pendingCheckout } returns MutableStateFlow(false)
        val result = newResult()
        handler.handle(call("getPendingCheckout"), result)
        verify { result.success(false) }
        verify(exactly = 0) { result.error(any(), any(), any()) }
    }

    @Test
    fun `getPendingCheckout returns true when SDK pendingCheckout is true`() {
        every { ZeroSettle.pendingCheckout } returns MutableStateFlow(true)
        val result = newResult()
        handler.handle(call("getPendingCheckout"), result)
        verify { result.success(true) }
        verify(exactly = 0) { result.error(any(), any(), any()) }
    }

    // ─── setBaseUrlOverride — stages override for next configure() ──────

    @Test
    fun `setBaseUrlOverride stages url in BaseUrlOverrideStore`() {
        BaseUrlOverrideStore.consume() // clear any leftover state
        val result = newResult()
        handler.handle(
            call("setBaseUrlOverride", mapOf("url" to "https://api-staging.zerosettle.io/v1")),
            result,
        )
        verify { result.success(null) }
        verify(exactly = 0) { result.error(any(), any(), any()) }
        assertThat(BaseUrlOverrideStore.consume()).isEqualTo("https://api-staging.zerosettle.io/v1")
    }

    @Test
    fun `setBaseUrlOverride clears the store when url omitted`() {
        // Dart's Future<void> setBaseUrlOverride(String? url) sends an
        // empty args map when url is null — clearing the override.
        BaseUrlOverrideStore.set("https://stale.example.com")
        val result = newResult()
        handler.handle(call("setBaseUrlOverride", emptyMap<String, Any?>()), result)
        verify { result.success(null) }
        assertThat(BaseUrlOverrideStore.consume()).isNull()
    }

    @Test
    fun `setBaseUrlOverride clears the store on blank url`() {
        BaseUrlOverrideStore.set("https://stale.example.com")
        val result = newResult()
        handler.handle(call("setBaseUrlOverride", mapOf("url" to "")), result)
        verify { result.success(null) }
        assertThat(BaseUrlOverrideStore.consume()).isNull()
    }

    // ─── trackEvent — no SDK API, Dart swallows errors → success(null) ──

    @Test
    fun `trackEvent returns success(null) with full args`() {
        // Dart wraps trackEvent in try/catch (`silent fire-and-forget`).
        // Returning `success(null)` cleaner than firing a PlatformException
        // that gets swallowed by the Dart try/catch anyway. No arg
        // validation (no SDK to validate against).
        val result = newResult()
        handler.handle(
            call(
                "trackEvent",
                mapOf(
                    "eventType" to "paywall_shown",
                    "productId" to "com.app.coins",
                    "screenName" to "settings",
                    "metadata" to mapOf("source" to "settings_tip"),
                ),
            ),
            result,
        )
        verify { result.success(null) }
        verify(exactly = 0) { result.error(any(), any(), any()) }
    }

    @Test
    fun `trackEvent returns success(null) even with empty args`() {
        // No SDK to validate against — accept any wire shape.
        val result = newResult()
        handler.handle(call("trackEvent", emptyMap<String, Any?>()), result)
        verify { result.success(null) }
        verify(exactly = 0) { result.error(any(), any(), any()) }
    }

    // ─── trackMigrationConversion — real SDK call (suspend) ─────────────

    @Test
    fun `trackMigrationConversion happy path returns success(null)`() = runTest {
        coEvery {
            ZeroSettle.trackMigrationConversion(UserOffer.SourceStorefront.PLAY_STORE)
        } returns Result.success(Unit)

        val result = newResult()
        handler.handle(call("trackMigrationConversion"), result)

        coVerify {
            ZeroSettle.trackMigrationConversion(UserOffer.SourceStorefront.PLAY_STORE)
        }
        verify { result.success(null) }
        verify(exactly = 0) { result.error(any(), any(), any()) }
    }

    @Test
    fun `trackMigrationConversion silently accepts iOS-only userId arg`() = runTest {
        // Dart's wire ships `userId` for iOS parity; Android SDK uses
        // internal currentUserId. Handler drops the arg without rejecting.
        coEvery {
            ZeroSettle.trackMigrationConversion(UserOffer.SourceStorefront.PLAY_STORE)
        } returns Result.success(Unit)

        val result = newResult()
        handler.handle(
            call("trackMigrationConversion", mapOf("userId" to "user_123")),
            result,
        )

        coVerify {
            ZeroSettle.trackMigrationConversion(UserOffer.SourceStorefront.PLAY_STORE)
        }
        verify { result.success(null) }
    }

    @Test
    fun `trackMigrationConversion always passes PLAY_STORE as source`() = runTest {
        // Android = Play migration. iOS Kit's API has no source arg;
        // Android SDK's API requires it. Handler bakes in PLAY_STORE.
        val sourceSlot: CapturingSlot<UserOffer.SourceStorefront> = slot()
        coEvery {
            ZeroSettle.trackMigrationConversion(capture(sourceSlot))
        } returns Result.success(Unit)

        handler.handle(call("trackMigrationConversion"), newResult())

        assertThat(sourceSlot.captured).isEqualTo(UserOffer.SourceStorefront.PLAY_STORE)
    }

    @Test
    fun `trackMigrationConversion maps UserNotIdentified to wire code`() = runTest {
        coEvery {
            ZeroSettle.trackMigrationConversion(any())
        } returns Result.failure(ZeroSettleError.UserNotIdentified)

        val result = newResult()
        handler.handle(call("trackMigrationConversion"), result)

        verify { result.error(eq("user_not_identified"), any(), null) }
        verify(exactly = 0) { result.success(any()) }
    }

    @Test
    fun `trackMigrationConversion maps SDK throw to sdk_error`() = runTest {
        coEvery {
            ZeroSettle.trackMigrationConversion(any())
        } throws RuntimeException("boom")

        val result = newResult()
        handler.handle(call("trackMigrationConversion"), result)

        verify { result.error("sdk_error", "boom", null) }
        verify(exactly = 0) { result.success(any()) }
    }

    // ─── resetMigrateTipState — no SDK API → success(null) ──────────────

    @Test
    fun `resetMigrateTipState returns success(null) without touching offer dismissal store`() {
        // Intentionally NOT routed through ZeroSettle.resetOfferDismissedState() —
        // doing so would conflate the iOS-distinct MigrationManager.resetDismissedState
        // and ZSOfferManagerStatics.resetDismissedState surfaces. Verify the
        // handler doesn't call resetOfferDismissedState here.
        val result = newResult()
        handler.handle(call("resetMigrateTipState"), result)
        verify { result.success(null) }
        coVerify(exactly = 0) { ZeroSettle.resetOfferDismissedState() }
        verify(exactly = 0) { result.error(any(), any(), any()) }
    }

    // ─── fetchTransactionHistory — force-unwrap blocker → not_implemented ─

    @Test
    fun `fetchTransactionHistory returns not_implemented with explanatory message`() {
        // Per the F15 force-unwrap rule: Dart's
        // Future<List<Map<String, dynamic>>> with `result!.map(...)` would
        // throw an uncatchable Dart `_TypeError` on `success(null)`.
        // SDK's Result<String> (raw JSON) can't be re-shaped into
        // List<Map> without a typed model — blocked on a follow-up SDK task.
        val result = newResult()
        val codeSlot: CapturingSlot<String> = slot()
        val messageSlot: CapturingSlot<String> = slot()

        handler.handle(call("fetchTransactionHistory", mapOf("userId" to "u")), result)

        verify { result.error(capture(codeSlot), capture(messageSlot), null) }
        verify(exactly = 0) { result.success(any()) }
        assertThat(codeSlot.captured).isEqualTo("not_implemented")
        assertThat(messageSlot.captured).contains("fetchTransactionHistory")
        // The message must hint at the typed-model gap so a future task
        // implementer knows where to start.
        assertThat(messageSlot.captured).contains("CheckoutTransaction")
    }

    @Test
    fun `fetchTransactionHistory returns not_implemented even without userId`() {
        // Force-unwrap rule applies regardless of args.
        val result = newResult()
        handler.handle(call("fetchTransactionHistory"), result)
        verify { result.error(eq("not_implemented"), any(), null) }
    }
}
