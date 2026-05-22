package com.zerosettle.flutter

import com.google.common.truth.Truth.assertThat
import com.zerosettle.flutter.ext.toFlutterMap
import com.zerosettle.sdk.models.PendingClaim
import io.flutter.plugin.common.EventChannel
import io.mockk.every
import io.mockk.mockk
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
 * Unit tests for F25's SDK -> Dart EventChannel pump primitives:
 *
 *   - [BufferedStreamHandler] — buffered sink + replay-on-onListen semantics
 *     that let late Dart subscribers see the current state without waiting
 *     for the next mutation. Mirrors iOS's `onListenStarted` callback
 *     pattern (see `ZeroSettlePlugin.swift:155` for pending claims).
 *   - [pumpStateFlow] — top-level helper that subscribes to a
 *     [kotlinx.coroutines.flow.StateFlow], encodes each emission, and pushes
 *     to a [BufferedStreamHandler]. The plugin uses it for
 *     `entitlement_updates` and `pending_claims_updates`.
 *
 * Strategy: drive a [MutableStateFlow] from the test, capture sink calls
 * via a MockK relaxed [EventChannel.EventSink], assert wire-shape and
 * lifecycle. No plugin lifecycle needed.
 *
 * The dispatchers are [UnconfinedTestDispatcher] so coroutine launches
 * resume synchronously — `flow.value = x` in the test fires the collect
 * before the next line.
 */
@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
class EventPumpsTest {

    private lateinit var scope: CoroutineScope

    @Before
    fun setUp() {
        scope = CoroutineScope(SupervisorJob() + UnconfinedTestDispatcher())
    }

    @After
    fun tearDown() {
        scope.cancel()
    }

    // ─── BufferedStreamHandler ──────────────────────────────────────────

    @Test
    fun `BufferedStreamHandler starts with null sink and no cached emit`() {
        val handler = BufferedStreamHandler()
        assertThat(handler.sink).isNull()
        // No way to read lastEmit directly — verify via the replay path: a
        // fresh sink should receive nothing on onListen if no emit ever ran.
        val sink = mockk<EventChannel.EventSink>(relaxed = true)
        handler.onListen(null, sink)
        verify(exactly = 0) { sink.success(any()) }
    }

    @Test
    fun `BufferedStreamHandler emit pushes to attached sink`() {
        val handler = BufferedStreamHandler()
        val sink = mockk<EventChannel.EventSink>(relaxed = true)
        handler.onListen(null, sink)

        handler.emit(listOf(mapOf("productId" to "com.app.coins")))

        verify { sink.success(listOf(mapOf("productId" to "com.app.coins"))) }
    }

    @Test
    fun `BufferedStreamHandler emit while detached caches lastEmit but does not crash`() {
        val handler = BufferedStreamHandler()
        // No sink attached.
        handler.emit(listOf(mapOf("productId" to "com.app.coins")))
        // No crash, sink stays null.
        assertThat(handler.sink).isNull()

        // Now attach — the cached value should replay.
        val sink = mockk<EventChannel.EventSink>(relaxed = true)
        handler.onListen(null, sink)
        verify { sink.success(listOf(mapOf("productId" to "com.app.coins"))) }
    }

    @Test
    fun `BufferedStreamHandler onListen replays the most recent emit only`() {
        // Multiple emits while detached → only the latest replays. This is
        // the StateFlow "current value" semantics — a late subscriber sees
        // the current state, not the history.
        val handler = BufferedStreamHandler()
        handler.emit("first")
        handler.emit("second")
        handler.emit("third")

        val sink = mockk<EventChannel.EventSink>(relaxed = true)
        handler.onListen(null, sink)
        verify(exactly = 1) { sink.success("third") }
        verify(exactly = 0) { sink.success("first") }
        verify(exactly = 0) { sink.success("second") }
    }

    @Test
    fun `BufferedStreamHandler onCancel clears the sink but keeps cache`() {
        val handler = BufferedStreamHandler()
        val firstSink = mockk<EventChannel.EventSink>(relaxed = true)
        handler.onListen(null, firstSink)
        handler.emit("cached")
        verify { firstSink.success("cached") }

        handler.onCancel(null)
        assertThat(handler.sink).isNull()

        // Emit while detached — should not crash, should not call old sink.
        handler.emit("dropped-to-no-sink")

        // Reattach with a fresh sink — should replay the latest cached value
        // ("dropped-to-no-sink"), proving the cache survived detach.
        val secondSink = mockk<EventChannel.EventSink>(relaxed = true)
        handler.onListen(null, secondSink)
        verify { secondSink.success("dropped-to-no-sink") }
        // Old sink got no further pushes after onCancel.
        verify(exactly = 1) { firstSink.success(any()) }
    }

    // ─── replayLatest = false (discrete event channels) ─────────────────

    @Test
    fun `BufferedStreamHandler with replayLatest=false does not replay on attach`() {
        // Matches iOS's CheckoutStreamHandler (no onListenStarted) so late
        // Dart subscribers don't get a phantom checkoutDidComplete from a
        // prior purchase.
        val handler = BufferedStreamHandler(replayLatest = false)
        handler.emit(mapOf("event" to "checkoutDidComplete"))

        val sink = mockk<EventChannel.EventSink>(relaxed = true)
        handler.onListen(null, sink)
        verify(exactly = 0) { sink.success(any()) }
    }

    @Test
    fun `BufferedStreamHandler with replayLatest=false still pushes live emits`() {
        // The no-replay flag only suppresses onListen replay — live emits
        // while a sink is attached must still land.
        val handler = BufferedStreamHandler(replayLatest = false)
        val sink = mockk<EventChannel.EventSink>(relaxed = true)
        handler.onListen(null, sink)

        handler.emit(mapOf("event" to "checkoutDidBegin", "productId" to "x"))
        verify { sink.success(mapOf("event" to "checkoutDidBegin", "productId" to "x")) }
    }

    @Test
    fun `BufferedStreamHandler with replayLatest=false drops events on reattach`() {
        // Subscribe, fire one event, cancel, reattach with a fresh sink —
        // the fresh sink receives nothing. This is the exact scenario the
        // replay flag exists to prevent for checkout_events.
        val handler = BufferedStreamHandler(replayLatest = false)
        val firstSink = mockk<EventChannel.EventSink>(relaxed = true)
        handler.onListen(null, firstSink)
        handler.emit(mapOf("event" to "checkoutDidComplete"))
        verify { firstSink.success(mapOf("event" to "checkoutDidComplete")) }

        handler.onCancel(null)
        val secondSink = mockk<EventChannel.EventSink>(relaxed = true)
        handler.onListen(null, secondSink)
        verify(exactly = 0) { secondSink.success(any()) }
    }

    @Test
    fun `BufferedStreamHandler emit after reattach goes only to the new sink`() {
        val handler = BufferedStreamHandler()
        val firstSink = mockk<EventChannel.EventSink>(relaxed = true)
        handler.onListen(null, firstSink)
        handler.onCancel(null)

        val secondSink = mockk<EventChannel.EventSink>(relaxed = true)
        handler.onListen(null, secondSink)

        handler.emit("post-reattach")

        verify { secondSink.success("post-reattach") }
        verify(exactly = 0) { firstSink.success("post-reattach") }
    }

    // ─── pumpStateFlow ──────────────────────────────────────────────────

    @Test
    fun `pumpStateFlow emits the initial StateFlow value through the encoder`() {
        // StateFlow.collect emits the current value immediately to a fresh
        // subscriber — the pump should encode + cache it so a late Dart
        // sink sees it on onListen.
        val source = MutableStateFlow(listOf("alpha", "beta"))
        val handler = BufferedStreamHandler()

        pumpStateFlow(scope, source, handler) { list -> list.map { mapOf("id" to it) } }

        // No sink yet → nothing arrives at any sink, but the value was
        // cached in the handler. Attach a sink and verify replay.
        val sink = mockk<EventChannel.EventSink>(relaxed = true)
        handler.onListen(null, sink)
        verify {
            sink.success(
                listOf(
                    mapOf("id" to "alpha"),
                    mapOf("id" to "beta"),
                )
            )
        }
    }

    @Test
    fun `pumpStateFlow forwards subsequent StateFlow mutations to attached sink`() {
        val source = MutableStateFlow<List<String>>(emptyList())
        val handler = BufferedStreamHandler()
        val sink = mockk<EventChannel.EventSink>(relaxed = true)
        handler.onListen(null, sink)

        pumpStateFlow(scope, source, handler) { list -> list.map { mapOf("id" to it) } }
        // The initial empty list emits through the pump → cached + sent.
        verify { sink.success(emptyList<Map<String, Any?>>()) }

        // Mutate the source — pump propagates.
        source.value = listOf("one")
        verify { sink.success(listOf(mapOf("id" to "one"))) }

        source.value = listOf("one", "two")
        verify { sink.success(listOf(mapOf("id" to "one"), mapOf("id" to "two"))) }
    }

    @Test
    fun `pumpStateFlow continues caching while detached and replays on reattach`() {
        // Simulate iOS-like late-subscriber behaviour: pump starts, source
        // mutates several times with NO Dart sink attached, then Dart
        // attaches — should see the latest value.
        val source = MutableStateFlow("initial")
        val handler = BufferedStreamHandler()

        pumpStateFlow(scope, source, handler) { it }
        source.value = "mid"
        source.value = "latest"

        val sink = mockk<EventChannel.EventSink>(relaxed = true)
        handler.onListen(null, sink)
        verify(exactly = 1) { sink.success("latest") }
    }

    @Test
    fun `pumpStateFlow stops emitting after scope cancellation`() {
        val source = MutableStateFlow("v0")
        val handler = BufferedStreamHandler()
        val sink = mockk<EventChannel.EventSink>(relaxed = true)
        handler.onListen(null, sink)

        val job = pumpStateFlow(scope, source, handler) { it }
        // Initial value lands.
        verify { sink.success("v0") }

        job.cancel()
        // Reset the mock expectations — we now want to assert NOTHING new lands.
        every { sink.success(any()) } answers { } // re-installs the relaxed stub
        source.value = "v1-after-cancel"
        verify(exactly = 0) { sink.success("v1-after-cancel") }
    }

    // ─── Gap 5: nullable replay + pumpNullableStateFlow ────────────────

    @Test
    fun `BufferedStreamHandler replays a cached null on onListen`() {
        // Gap 5 — `current_user_id_updates` legitimately emits `null` on
        // logout. The handler must replay that null to fresh sinks rather
        // than dropping it (the pre-Gap-5 behaviour skipped null replays
        // via `lastEmit?.let`). Late subscribers need to know they're
        // logged out.
        val handler = BufferedStreamHandler()
        handler.emit(null)

        val sink = mockk<EventChannel.EventSink>(relaxed = true)
        handler.onListen(null, sink)
        verify { sink.success(null) }
    }

    @Test
    fun `BufferedStreamHandler does not replay when nothing emitted yet`() {
        // The flip side — if no value has ever been emitted, onListen must
        // not push a phantom null. `hasEmitted` is the source of truth.
        val handler = BufferedStreamHandler()
        val sink = mockk<EventChannel.EventSink>(relaxed = true)
        handler.onListen(null, sink)
        verify(exactly = 0) { sink.success(any()) }
        verify(exactly = 0) { sink.success(null) }
    }

    @Test
    fun `pumpNullableStateFlow forwards null on logout`() {
        // Mirrors the SDK's StateFlow<String?> — initial null (pre-identify),
        // then a userId (post-identify), then null again (post-logout).
        val source = MutableStateFlow<String?>(null)
        val handler = BufferedStreamHandler()
        val sink = mockk<EventChannel.EventSink>(relaxed = true)
        handler.onListen(null, sink)

        pumpNullableStateFlow(scope, source, handler)
        verify { sink.success(null) }

        source.value = "u_alice"
        verify { sink.success("u_alice") }

        source.value = null
        verify(atLeast = 2) { sink.success(null) }
    }

    @Test
    fun `pumpNullableStateFlow replays null on reattach when logged out`() {
        // Pre-Gap-5 the replay path was `lastEmit?.let`, which would have
        // silently dropped this case — leaving late Dart subscribers stuck
        // waiting for the first login. Gap 5 fixes the handler's
        // `hasEmitted` flag, this test pins the behaviour.
        val source = MutableStateFlow<String?>(null)
        val handler = BufferedStreamHandler()
        pumpNullableStateFlow(scope, source, handler)

        val sink = mockk<EventChannel.EventSink>(relaxed = true)
        handler.onListen(null, sink)
        verify { sink.success(null) }
    }

    // ─── pending_claims_updates pump (Play transfer) ───────────────────

    @Test
    fun `pending_claims pump emits PendingClaim list with purchaseToken to Dart`() {
        // Pins the `pending_claims_updates` channel wiring: a StateFlow of
        // PendingClaim (the shape of ZeroSettle.pendingClaims) is pumped
        // through the same encoder the plugin installs at
        // ZeroSettlePlugin.kt — `it.map { c -> c.toFlutterMap() }`. A
        // late-attaching Dart sink must see the Play purchaseToken.
        val claim = PendingClaim(
            productId = "com.app.pro",
            originalTransactionId = "100000123",
            existingOwnerHint = "a1b2c3d4",
            purchaseToken = "GPA.1234-5678-9012-34567",
        )
        val source = MutableStateFlow(listOf(claim))
        val handler = BufferedStreamHandler(replayLatest = true)

        pumpStateFlow(scope, source, handler) { list -> list.map { it.toFlutterMap() } }

        val sink = mockk<EventChannel.EventSink>(relaxed = true)
        handler.onListen(null, sink)
        verify {
            sink.success(
                listOf(
                    mapOf(
                        "productId" to "com.app.pro",
                        "originalTransactionId" to "100000123",
                        "existingOwnerHint" to "a1b2c3d4",
                        "purchaseToken" to "GPA.1234-5678-9012-34567",
                    )
                )
            )
        }
    }

    @Test
    fun `pending_claims pump forwards a newly-detected conflict to an attached sink`() {
        // A conflict appearing after the pump is live (the real flow: a
        // Play sync detects a cross-user conflict and pushes a PendingClaim
        // onto ZeroSettle.pendingClaims) must reach the Dart sink.
        val source = MutableStateFlow<List<PendingClaim>>(emptyList())
        val handler = BufferedStreamHandler(replayLatest = true)
        val sink = mockk<EventChannel.EventSink>(relaxed = true)
        handler.onListen(null, sink)

        pumpStateFlow(scope, source, handler) { list -> list.map { it.toFlutterMap() } }
        verify { sink.success(emptyList<Map<String, Any?>>()) }

        source.value = listOf(
            PendingClaim(
                productId = "com.app.pro",
                originalTransactionId = "100000123",
                existingOwnerHint = "deadbeef",
                purchaseToken = "GPA.token-xyz",
            )
        )
        verify {
            sink.success(
                listOf(
                    mapOf(
                        "productId" to "com.app.pro",
                        "originalTransactionId" to "100000123",
                        "existingOwnerHint" to "deadbeef",
                        "purchaseToken" to "GPA.token-xyz",
                    )
                )
            )
        }
    }

    @Test
    fun `pumpStateFlow encoder is called per emission, not per attach`() {
        // The encoder is the wire-shape transform; it should run exactly
        // once per source emission, regardless of how many times the sink
        // attaches / detaches. Verifies the pump isn't re-encoding on replay.
        var encodeCount = 0
        val source = MutableStateFlow("v0")
        val handler = BufferedStreamHandler()

        pumpStateFlow(scope, source, handler) { v ->
            encodeCount += 1
            "encoded:$v"
        }
        // Initial collect → encode #1.
        assertThat(encodeCount).isEqualTo(1)

        val firstSink = mockk<EventChannel.EventSink>(relaxed = true)
        handler.onListen(null, firstSink)
        verify { firstSink.success("encoded:v0") }
        // Replay-on-onListen pulls from cache, no re-encode.
        assertThat(encodeCount).isEqualTo(1)

        handler.onCancel(null)
        val secondSink = mockk<EventChannel.EventSink>(relaxed = true)
        handler.onListen(null, secondSink)
        verify { secondSink.success("encoded:v0") }
        // Re-attach also doesn't re-encode.
        assertThat(encodeCount).isEqualTo(1)

        source.value = "v1"
        assertThat(encodeCount).isEqualTo(2)
    }
}
