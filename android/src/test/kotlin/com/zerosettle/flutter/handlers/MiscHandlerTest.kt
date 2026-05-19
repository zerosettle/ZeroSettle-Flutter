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
 *   - `fetchTransactionHistory` forwards to
 *     `ZeroSettle.fetchTransactionHistory()` and returns
 *     `success(List<Map<String, Any?>>)` matching the iOS wire shape.
 *     SDK failure → `sendError`.
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
        every { ZeroSettle.isUcbEnabled } returns MutableStateFlow(false)
        coEvery { ZeroSettle.trackMigrationConversion(any()) } returns Result.failure(
            ZeroSettleError.UserNotIdentified,
        )
        coEvery { ZeroSettle.fetchTransactionHistory() } returns Result.success(emptyList())
        coEvery { ZeroSettle.fetchUserOffer() } returns Result.failure(
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
            "getIsUcbEnabled" to null,
            "fetchUserOffer" to null,
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

    // ─── fetchTransactionHistory — typed list pass-through ─────────────

    @Test
    fun `fetchTransactionHistory forwards to SDK and returns list of maps`() = runTest {
        // SDK now returns Result<List<CheckoutTransaction>>; the handler
        // encodes each entry via CheckoutTransaction.toFlutterMap() so the
        // wire shape matches iOS. Cover the canonical fields (id/productId/
        // status/source/purchasedAt) + a couple of optional ones to make
        // sure the encoder fired.
        val sample = com.zerosettle.sdk.models.CheckoutTransaction(
            id = "txn_1",
            productId = "pro_monthly",
            status = com.zerosettle.sdk.models.CheckoutTransaction.Status.COMPLETED,
            source = com.zerosettle.sdk.models.EntitlementSource.WEB_CHECKOUT,
            purchasedAt = "2026-05-11T00:00:00Z",
            expiresAt = "2026-06-11T00:00:00Z",
            productName = "Pro Monthly",
            amountCents = 599,
            currency = "usd",
            storekitStatus = null,
        )
        coEvery { ZeroSettle.fetchTransactionHistory() } returns Result.success(listOf(sample))

        val result = newResult()
        val slotSuccess: CapturingSlot<Any> = slot()
        handler.handle(call("fetchTransactionHistory", mapOf("userId" to "u")), result)
        verify { result.success(capture(slotSuccess)) }
        verify(exactly = 0) { result.error(any(), any(), any()) }

        @Suppress("UNCHECKED_CAST")
        val list = slotSuccess.captured as List<Map<String, Any?>>
        assertThat(list).hasSize(1)
        val m = list[0]
        assertThat(m["id"]).isEqualTo("txn_1")
        assertThat(m["productId"]).isEqualTo("pro_monthly")
        assertThat(m["status"]).isEqualTo("completed")
        assertThat(m["source"]).isEqualTo("web_checkout")
        assertThat(m["amountCents"]).isEqualTo(599)
        assertThat(m["currency"]).isEqualTo("usd")
        // null storekitStatus must be omitted, matching the encoder contract.
        assertThat(m).doesNotContainKey("storekitStatus")
    }

    @Test
    fun `fetchTransactionHistory surfaces SDK failure via sendError`() = runTest {
        coEvery { ZeroSettle.fetchTransactionHistory() } returns Result.failure(
            ZeroSettleError.UserNotIdentified,
        )

        val result = newResult()
        handler.handle(call("fetchTransactionHistory"), result)
        verify { result.error(eq("user_not_identified"), any(), any()) }
        verify(exactly = 0) { result.success(any()) }
    }

    // ─── fetchUserOffer — typed response pass-through (Task 9) ──────────

    @Test
    fun `fetchUserOffer happy path encodes response as UserOfferResponse wire map`() = runTest {
        val sampleResponse = UserOffer.Response(
            userId = "u1",
            appId = 42,
            isSandbox = false,
            subscription = UserOffer.Subscription(type = "active_web", productId = "p.month"),
            offer = UserOffer.OfferData(
                actionType = UserOffer.ActionType.MIGRATE_STOREKIT_TO_WEB,
                isEligible = true,
                checkoutProductId = "p.month",
                savingsPercent = 20,
                freeTrialDays = 7,
                minSubscriptionDays = 0,
                rolloutPercent = 100,
                requiresAppleCancel = false,
            ),
            serverTime = "2026-05-19T00:00:00Z",
        )
        coEvery { ZeroSettle.fetchUserOffer() } returns Result.success(sampleResponse)

        val result = newResult()
        val slotSuccess: CapturingSlot<Any> = slot()
        handler.handle(call("fetchUserOffer"), result)
        verify { result.success(capture(slotSuccess)) }
        verify(exactly = 0) { result.error(any(), any(), any()) }

        @Suppress("UNCHECKED_CAST")
        val m = slotSuccess.captured as Map<String, Any?>
        assertThat(m["userId"]).isEqualTo("u1")
        // appId Int → String coercion
        assertThat(m["appId"]).isEqualTo("42")
        assertThat(m["isSandbox"]).isEqualTo(false)
        // serverTime passes through as-is on Android (already a String in the model)
        assertThat(m["serverTime"]).isEqualTo("2026-05-19T00:00:00Z")

        @Suppress("UNCHECKED_CAST")
        val sub = m["subscription"] as Map<String, Any?>
        // subscription.type: snake_case → camelCase
        assertThat(sub["type"]).isEqualTo("activeWeb")
        assertThat(sub["productId"]).isEqualTo("p.month")

        @Suppress("UNCHECKED_CAST")
        val offer = m["offer"] as Map<String, Any?>
        assertThat(offer["actionType"]).isEqualTo("migrateStorekitToWeb")
        assertThat(offer["isEligible"]).isEqualTo(true)
        assertThat(offer["checkoutProductId"]).isEqualTo("p.month")
        assertThat(offer["savingsPercent"]).isEqualTo(20)
        assertThat(offer["freeTrialDays"]).isEqualTo(7)
        assertThat(offer["requiresAppleCancel"]).isEqualTo(false)
    }

    @Test
    fun `fetchUserOffer encodes experimentVariantId Int as String`() = runTest {
        val response = UserOffer.Response(
            userId = "u2",
            appId = 1,
            isSandbox = false,
            subscription = UserOffer.Subscription(type = "none"),
            offer = UserOffer.OfferData(
                actionType = UserOffer.ActionType.NO_ACTION,
                isEligible = false,
                checkoutProductId = "",
                savingsPercent = 0,
                freeTrialDays = 0,
                minSubscriptionDays = 0,
                rolloutPercent = 100,
                requiresAppleCancel = false,
                experimentVariantId = 7,
            ),
            serverTime = "2026-05-19T00:00:00Z",
        )
        coEvery { ZeroSettle.fetchUserOffer() } returns Result.success(response)

        val result = newResult()
        val slotSuccess: CapturingSlot<Any> = slot()
        handler.handle(call("fetchUserOffer"), result)
        verify { result.success(capture(slotSuccess)) }

        @Suppress("UNCHECKED_CAST")
        val m = slotSuccess.captured as Map<String, Any?>
        @Suppress("UNCHECKED_CAST")
        val offer = m["offer"] as Map<String, Any?>
        // Int experimentVariantId → String on wire
        assertThat(offer["experimentVariantId"]).isEqualTo("7")
    }

    @Test
    fun `fetchUserOffer maps subscription type snake_case to camelCase`() = runTest {
        val types = listOf(
            "active_web" to "activeWeb",
            "active_storekit" to "activeStorekit",
            "migration_trial" to "migrationTrial",
            "cancelled_active" to "cancelledActive",
            "none" to "none",
            "future_unknown" to "future_unknown",
        )
        for ((raw, expected) in types) {
            val response = UserOffer.Response(
                userId = "u",
                appId = 1,
                isSandbox = false,
                subscription = UserOffer.Subscription(type = raw),
                offer = UserOffer.OfferData(
                    actionType = UserOffer.ActionType.NO_ACTION,
                    isEligible = false,
                    checkoutProductId = "",
                    savingsPercent = 0,
                    freeTrialDays = 0,
                    minSubscriptionDays = 0,
                    rolloutPercent = 100,
                    requiresAppleCancel = false,
                ),
                serverTime = "t",
            )
            coEvery { ZeroSettle.fetchUserOffer() } returns Result.success(response)
            val result = newResult()
            val slotSuccess: CapturingSlot<Any> = slot()
            handler.handle(call("fetchUserOffer"), result)
            verify { result.success(capture(slotSuccess)) }

            @Suppress("UNCHECKED_CAST")
            val m = slotSuccess.captured as Map<String, Any?>
            @Suppress("UNCHECKED_CAST")
            val sub = m["subscription"] as Map<String, Any?>
            assertThat(sub["type"]).isEqualTo(expected)
        }
    }

    @Test
    fun `fetchUserOffer surfaces SDK failure via sendError`() = runTest {
        coEvery { ZeroSettle.fetchUserOffer() } returns Result.failure(
            ZeroSettleError.UserNotIdentified,
        )

        val result = newResult()
        handler.handle(call("fetchUserOffer"), result)
        verify { result.error(eq("user_not_identified"), any(), any()) }
        verify(exactly = 0) { result.success(any()) }
    }

    // ─── getIsUcbEnabled — reads the SDK isUcbEnabled StateFlow ─────────

    @Test
    fun `getIsUcbEnabled returns the SDK isUcbEnabled StateFlow value`() {
        // The handler reads `ZeroSettle.isUcbEnabled.value` synchronously.
        // Stub the StateFlow to `true` (not the default `false`) so this
        // test fails if the handler ever reverts to a hardcoded value.
        every { ZeroSettle.isUcbEnabled } returns MutableStateFlow(true)

        val result = newResult()
        val consumed = handler.handle(call("getIsUcbEnabled"), result)
        assertThat(consumed).isTrue()
        verify { result.success(true) }
    }
}
