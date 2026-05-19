package com.zerosettle.flutter.handlers

import android.app.Activity
import android.content.Context
import com.google.common.truth.Truth.assertThat
import com.zerosettle.sdk.ZeroSettle
import com.zerosettle.sdk.models.PendingAction
import com.zerosettle.sdk.models.ZeroSettleError
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.mockk.coEvery
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
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * Unit tests for [PendingActionsHandler].
 *
 * Mirrors the setup used by [PendingClaimsHandlerTest] — `mockkObject(ZeroSettle)`,
 * all SDK boundaries stubbed. Tests cover:
 *   - `getPendingActions` with an empty StateFlow → `success(emptyList())`.
 *   - `getPendingActions` with a MigrationCompletedInfo → encoded camelCase wire keys.
 *   - `getPendingActions` wire shape pins corrected keys (`migrationCompletedInfo`,
 *     `playAccessEndsAt`, `manualPlayCancel`, `expiresAt`).
 *   - `dismissPendingAction` happy path → `success(null)` via the String overload.
 *   - `dismissPendingAction` SDK failure → routed through the canonical
 *     `sendError` mapper, so a `ZeroSettleError.NotFound` (unknown
 *     transactionId) surfaces as `"not_found"`, not a flattened `"sdk_error"`.
 *   - `dismissPendingAction` missing transactionId arg → `error("INVALID_ARGUMENTS", ...)`.
 *   - Unknown method → `handle` returns false (fall-through to next handler).
 */
@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
class PendingActionsHandlerTest {

    private val testDispatcher = UnconfinedTestDispatcher()
    private val scope = CoroutineScope(SupervisorJob() + testDispatcher)
    private val appContext: Context = mockk(relaxed = true)
    private val activity: Activity = mockk(relaxed = true)
    private lateinit var handler: PendingActionsHandler

    @Before
    fun setUp() {
        mockkObject(ZeroSettle)
        // Default StateFlow stub — individual tests override.
        every { ZeroSettle.pendingActions } returns MutableStateFlow(emptyList())
        val deps = HandlerDependencies(
            scope = scope,
            activityProvider = { activity },
            applicationContextProvider = { appContext },
        )
        handler = PendingActionsHandler(deps)
    }

    @After
    fun tearDown() {
        unmockkObject(ZeroSettle)
        scope.cancel()
    }

    private fun call(method: String, args: Map<String, Any?>? = null) = MethodCall(method, args)
    private fun newResult() = mockk<MethodChannel.Result>(relaxed = true)

    // ─── handle() routing ───────────────────────────────────────────────────

    @Test
    fun `handle returns false for unknown method`() {
        val result = newResult()
        val consumed = handler.handle(call("definitelyNotMine"), result)
        assertThat(consumed).isFalse()
        verify(exactly = 0) { result.success(any()) }
        verify(exactly = 0) { result.error(any(), any(), any()) }
    }

    @Test
    fun `handle returns true for getPendingActions`() {
        val consumed = handler.handle(call("getPendingActions"), newResult())
        assertThat(consumed).isTrue()
    }

    @Test
    fun `handle returns true for dismissPendingAction`() {
        coEvery { ZeroSettle.dismissPendingAction(any<String>()) } returns Result.success(Unit)
        val consumed = handler.handle(call("dismissPendingAction", mapOf("transactionId" to "txn_1")), newResult())
        assertThat(consumed).isTrue()
    }

    // ─── getPendingActions (StateFlow snapshot) ────────────────────────────

    @Test
    fun `getPendingActions returns empty list when StateFlow is empty`() {
        every { ZeroSettle.pendingActions } returns MutableStateFlow(emptyList())
        val result = newResult()

        handler.handle(call("getPendingActions"), result)

        verify { result.success(emptyList<Map<String, Any?>>()) }
        verify(exactly = 0) { result.error(any(), any(), any()) }
    }

    @Test
    fun `getPendingActions MigrationCompletedInfo wire shape has camelCase type discriminator`() {
        val action = PendingAction.MigrationCompletedInfo(
            transactionId = "txn_migrate_1",
            userMessage = "Play access ends soon.",
            playAccessEndsAtIso = "2026-06-01T10:00:00Z",
            newSubscriptionPriceCents = 499,
            newSubscriptionCurrency = "USD",
            newSubscriptionInterval = "month",
        )
        every { ZeroSettle.pendingActions } returns MutableStateFlow(listOf(action))
        val listSlot = slot<List<Map<String, Any?>>>()
        val result = newResult()
        every { result.success(capture(listSlot)) } answers { }

        handler.handle(call("getPendingActions"), result)

        assertThat(listSlot.captured).hasSize(1)
        val map = listSlot.captured[0]
        // Type discriminator must be camelCase to match Dart PendingAction.fromMap.
        assertThat(map["type"]).isEqualTo("migrationCompletedInfo")
        assertThat(map["transactionId"]).isEqualTo("txn_migrate_1")
        assertThat(map["userMessage"]).isEqualTo("Play access ends soon.")
        // Date field must NOT have Iso suffix — Dart reads "playAccessEndsAt".
        assertThat(map["playAccessEndsAt"]).isEqualTo("2026-06-01T10:00:00Z")
        assertThat(map).doesNotContainKey("playAccessEndsAtIso")
        assertThat(map["newSubscriptionPriceCents"]).isEqualTo(499)
        assertThat(map["newSubscriptionCurrency"]).isEqualTo("USD")
        assertThat(map["newSubscriptionInterval"]).isEqualTo("month")
    }

    @Test
    fun `getPendingActions ManualPlayCancel wire shape has camelCase type discriminator`() {
        val action = PendingAction.ManualPlayCancel(
            transactionId = "txn_cancel_1",
            userMessage = "Cancel Play to complete switch.",
            originalPlayPurchaseToken = "play-token-xyz",
            expiresAtIso = "2026-06-01T10:00:00Z",
            deepLink = "https://play.google.com/store/account/subscriptions",
        )
        every { ZeroSettle.pendingActions } returns MutableStateFlow(listOf(action))
        val listSlot = slot<List<Map<String, Any?>>>()
        val result = newResult()
        every { result.success(capture(listSlot)) } answers { }

        handler.handle(call("getPendingActions"), result)

        assertThat(listSlot.captured).hasSize(1)
        val map = listSlot.captured[0]
        // Type discriminator must be camelCase to match Dart PendingAction.fromMap.
        assertThat(map["type"]).isEqualTo("manualPlayCancel")
        assertThat(map["transactionId"]).isEqualTo("txn_cancel_1")
        assertThat(map["originalPlayPurchaseToken"]).isEqualTo("play-token-xyz")
        // Date field must NOT have Iso suffix — Dart reads "expiresAt".
        assertThat(map["expiresAt"]).isEqualTo("2026-06-01T10:00:00Z")
        assertThat(map).doesNotContainKey("expiresAtIso")
        assertThat(map["deepLink"])
            .isEqualTo("https://play.google.com/store/account/subscriptions")
    }

    // ─── dismissPendingAction (suspend) ────────────────────────────────────

    @Test
    fun `dismissPendingAction calls SDK String overload and returns success`() {
        coEvery { ZeroSettle.dismissPendingAction("txn_123") } returns Result.success(Unit)
        val result = newResult()

        handler.handle(call("dismissPendingAction", mapOf("transactionId" to "txn_123")), result)

        verify { result.success(null) }
        verify(exactly = 0) { result.error(any(), any(), any()) }
    }

    @Test
    fun `dismissPendingAction SDK failure routes through sendError to mapped code`() {
        // The SDK's String dismissPendingAction returns Result.failure(NotFound)
        // when the transactionId isn't in the pendingActions StateFlow. The
        // canonical sendError mapper turns NotFound into "not_found" — the
        // handler must NOT collapse it to a generic "sdk_error".
        coEvery {
            ZeroSettle.dismissPendingAction("txn_fail")
        } returns Result.failure(ZeroSettleError.NotFound("no pending action for txn_fail"))
        val result = newResult()

        handler.handle(call("dismissPendingAction", mapOf("transactionId" to "txn_fail")), result)

        verify { result.error(eq("not_found"), any(), null) }
        verify(exactly = 0) { result.success(any()) }
    }

    @Test
    fun `dismissPendingAction missing transactionId returns INVALID_ARGUMENTS`() {
        val result = newResult()

        // No transactionId in args map.
        handler.handle(call("dismissPendingAction", emptyMap<String, Any?>()), result)

        verify { result.error(eq("INVALID_ARGUMENTS"), any(), null) }
        verify(exactly = 0) { result.success(any()) }
    }

    @Test
    fun `dismissPendingAction null args returns INVALID_ARGUMENTS`() {
        val result = newResult()

        handler.handle(call("dismissPendingAction", null), result)

        verify { result.error(eq("INVALID_ARGUMENTS"), any(), null) }
        verify(exactly = 0) { result.success(any()) }
    }
}
