package com.zerosettle.flutter.handlers

import android.app.Activity
import android.content.Context
import com.google.common.truth.Truth.assertThat
import com.zerosettle.sdk.ZeroSettle
import com.zerosettle.sdk.models.PendingClaim
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
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
 * Unit tests for [PendingClaimsHandler].
 *
 * Mirrors the setup used by [IdentityHandlerTest] / [CatalogHandlerTest] /
 * [PurchaseHandlerTest] — `mockkObject(ZeroSettle)`, all SDK boundaries
 * stubbed. The handler is synchronous (StateFlow `.value`), so no
 * coroutine plumbing is exercised, but we keep the scope around for
 * allocation-pattern parity with the other handlers.
 *
 * Wire-shape claims under test:
 *   - `getPendingClaims` with an empty StateFlow → `success(emptyList())`.
 *   - `getPendingClaims` with a single claim → wire-encoded list of size 1.
 *   - `getPendingClaims` with multiple claims → list preserves order.
 *   - `getPendingClaims` per-claim Map has the three documented keys
 *     (`productId`, `originalTransactionId`, `existingOwnerHint`) — pins
 *     the F3 encoder shape against accidental rename.
 *   - Unknown method → `handle` returns false (fall-through to next handler).
 */
@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
class PendingClaimsHandlerTest {

    private val scope = CoroutineScope(SupervisorJob() + UnconfinedTestDispatcher())
    private val appContext: Context = mockk(relaxed = true)
    private val activity: Activity = mockk(relaxed = true)
    private lateinit var handler: PendingClaimsHandler

    @Before
    fun setUp() {
        mockkObject(ZeroSettle)
        // Default StateFlow stub — individual tests override.
        every { ZeroSettle.pendingClaims } returns MutableStateFlow(emptyList())
        val deps = HandlerDependencies(
            scope = scope,
            activityProvider = { activity },
            applicationContextProvider = { appContext },
        )
        handler = PendingClaimsHandler(deps)
    }

    @After
    fun tearDown() {
        unmockkObject(ZeroSettle)
        scope.cancel()
    }

    private fun call(method: String, args: Map<String, Any?>? = null) = MethodCall(method, args)
    private fun newResult() = mockk<MethodChannel.Result>(relaxed = true)

    private fun newClaim(
        productId: String = "com.app.coins",
        originalTransactionId: String = "txn_orig_1",
        existingOwnerHint: String = "alice@example.com",
    ) = PendingClaim(
        productId = productId,
        originalTransactionId = originalTransactionId,
        existingOwnerHint = existingOwnerHint,
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
    fun `handle returns true for getPendingClaims`() {
        val consumed = handler.handle(call("getPendingClaims"), newResult())
        assertThat(consumed).isTrue()
    }

    // ─── getPendingClaims (StateFlow snapshot) ──────────────────────────

    @Test
    fun `getPendingClaims returns empty list when StateFlow is empty`() {
        every { ZeroSettle.pendingClaims } returns MutableStateFlow(emptyList())
        val result = newResult()

        handler.handle(call("getPendingClaims"), result)

        verify { result.success(emptyList<Map<String, Any?>>()) }
        verify(exactly = 0) { result.error(any(), any(), any()) }
    }

    @Test
    fun `getPendingClaims returns wire-encoded list for a single claim`() {
        val claim = newClaim(
            productId = "com.app.coins",
            originalTransactionId = "txn_orig_1",
            existingOwnerHint = "alice@example.com",
        )
        every { ZeroSettle.pendingClaims } returns MutableStateFlow(listOf(claim))
        val listSlot = slot<List<Map<String, Any?>>>()
        val result = newResult()
        every { result.success(capture(listSlot)) } answers { }

        handler.handle(call("getPendingClaims"), result)

        assertThat(listSlot.captured).hasSize(1)
        val map = listSlot.captured[0]
        assertThat(map["productId"]).isEqualTo("com.app.coins")
        assertThat(map["originalTransactionId"]).isEqualTo("txn_orig_1")
        assertThat(map["existingOwnerHint"]).isEqualTo("alice@example.com")
    }

    @Test
    fun `getPendingClaims preserves StateFlow order for multiple claims`() {
        val claims = listOf(
            newClaim(productId = "com.app.coins", originalTransactionId = "txn_1"),
            newClaim(productId = "com.app.pro", originalTransactionId = "txn_2"),
            newClaim(productId = "com.app.gold", originalTransactionId = "txn_3"),
        )
        every { ZeroSettle.pendingClaims } returns MutableStateFlow(claims)
        val listSlot = slot<List<Map<String, Any?>>>()
        val result = newResult()
        every { result.success(capture(listSlot)) } answers { }

        handler.handle(call("getPendingClaims"), result)

        assertThat(listSlot.captured).hasSize(3)
        assertThat(listSlot.captured.map { it["productId"] })
            .containsExactly("com.app.coins", "com.app.pro", "com.app.gold")
            .inOrder()
        assertThat(listSlot.captured.map { it["originalTransactionId"] })
            .containsExactly("txn_1", "txn_2", "txn_3")
            .inOrder()
    }

    @Test
    fun `getPendingClaims wire shape pins F3 encoder keys`() {
        // Guards against accidental rename of the encoded fields in
        // ext/ModelToFlutterMap.kt::PendingClaim.toFlutterMap. The Dart
        // decoder at lib/zerosettle_method_channel.dart relies on these
        // exact key names — drift here is a wire break.
        val claim = newClaim()
        every { ZeroSettle.pendingClaims } returns MutableStateFlow(listOf(claim))
        val listSlot = slot<List<Map<String, Any?>>>()
        val result = newResult()
        every { result.success(capture(listSlot)) } answers { }

        handler.handle(call("getPendingClaims"), result)

        val map = listSlot.captured.single()
        assertThat(map.keys).containsExactly(
            "productId",
            "originalTransactionId",
            "existingOwnerHint",
        )
    }
}
