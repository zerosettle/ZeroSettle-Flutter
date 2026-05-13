package com.zerosettle.flutter.handlers

import android.app.Activity
import android.content.Context
import com.google.common.truth.Truth.assertThat
import com.zerosettle.flutter.offermanager.OfferManagerHandleRegistry
import com.zerosettle.sdk.ZeroSettle
import com.zerosettle.sdk.models.ZeroSettleError
import com.zerosettle.sdk.offers.OfferManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.mockk.CapturingSlot
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkConstructor
import io.mockk.mockkObject
import io.mockk.slot
import io.mockk.unmockkAll
import io.mockk.unmockkObject
import io.mockk.verify
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
 * Unit tests for [HandleResolutionHandler].
 *
 * Wire-shape claims under test (matches the handler KDoc):
 *   - `resolveOfferManagerHandle` allocates via the registry, starts a
 *     bridge for the new entry, and returns the entry's integer id
 *     stringified — matching iOS's `UUID().uuidString` wire contract.
 *   - Missing `stripeCustomerId` arg is accepted (forwarded to the
 *     registry as null) — matches Dart wire's optional-arg shape.
 *   - Registry returning `null` (disposed-race) → tagged `sdk_error`.
 *   - Registry throwing → mapped via `sendError` (e.g. UserNotIdentified
 *     surfaces as `user_not_identified`).
 *   - `resolveMigrationManagerHandle` returns `not_implemented` with an
 *     explanatory message pointing at `OfferManager`.
 *   - Unknown method → `handle` returns `false` so the plugin falls
 *     through.
 *
 * The bridge wiring is not unit-tested here (it requires the full SDK
 * `OfferManager` to construct, and F20 owns those tests). We use a
 * Robolectric-friendly fake registry: the real `OfferManagerHandleRegistry`
 * is constructable in unit tests because the mocked `BinaryMessenger`
 * absorbs channel construction without crashing on JVM-side instantiation;
 * and `ZeroSettle.offerManager(...)` is `mockkObject`-stubbed to return a
 * relaxed mock manager so bridge `start()` can install handlers on the
 * mock channels without exploding.
 */
@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
class HandleResolutionHandlerTest {

    private val scope = CoroutineScope(SupervisorJob() + UnconfinedTestDispatcher())
    private val appContext: Context = mockk(relaxed = true)
    private val activity: Activity = mockk(relaxed = true)
    private lateinit var registry: OfferManagerHandleRegistry
    private lateinit var handler: HandleResolutionHandler

    @Before
    fun setUp() {
        mockkObject(ZeroSettle)
        // Bridge.start() reads StateFlows on the OfferManager. A relaxed
        // mock returns relaxed StateFlow-typed mocks, but `combine` over
        // them would never fire — that's fine for these tests, we only
        // verify the bridge was constructed + started (no exceptions).
        every { ZeroSettle.offerManager(any()) } answers { mockk<OfferManager>(relaxed = true) }

        // Mock MethodChannel + EventChannel constructors so the registry can
        // build channels against a relaxed BinaryMessenger without the
        // Flutter test runner needing a full engine. The constructed
        // channels are mocked instances; their `setMethodCallHandler` /
        // `setStreamHandler` calls become recorded no-ops.
        mockkConstructor(MethodChannel::class)
        every { anyConstructed<MethodChannel>().setMethodCallHandler(any()) } answers { }
        every { anyConstructed<MethodChannel>().setMethodCallHandler(null) } answers { }
        mockkConstructor(EventChannel::class)
        every { anyConstructed<EventChannel>().setStreamHandler(any()) } answers { }
        every { anyConstructed<EventChannel>().setStreamHandler(null) } answers { }

        val messenger: BinaryMessenger = mockk(relaxed = true)
        registry = OfferManagerHandleRegistry(messenger)
        val deps = HandlerDependencies(
            scope = scope,
            activityProvider = { activity },
            applicationContextProvider = { appContext },
        )
        handler = HandleResolutionHandler(deps, registry)
    }

    @After
    fun tearDown() {
        unmockkObject(ZeroSettle)
        unmockkAll()
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
    fun `handle returns true for both owned methods`() {
        listOf(
            "resolveOfferManagerHandle" to mapOf("stripeCustomerId" to "cus_x"),
            "resolveMigrationManagerHandle" to null,
        ).forEach { (method, args) ->
            val consumed = handler.handle(call(method, args), newResult())
            assertThat(consumed).isTrue()
        }
    }

    // ─── resolveOfferManagerHandle — happy path ─────────────────────────

    @Test
    fun `resolveOfferManagerHandle returns stringified id on success`() {
        val result = newResult()
        val idSlot: CapturingSlot<String> = slot()

        handler.handle(
            call("resolveOfferManagerHandle", mapOf("stripeCustomerId" to "cus_test")),
            result,
        )

        // Dart wire contract is Future<String>. Registry uses AtomicInteger
        // starting at 1 — first allocation returns id=1.
        verify { result.success(capture(idSlot)) }
        verify(exactly = 0) { result.error(any(), any(), any()) }
        assertThat(idSlot.captured).isEqualTo("1")
    }

    @Test
    fun `resolveOfferManagerHandle allocates incrementing ids`() {
        // Two successive allocations return distinct stringified ids —
        // verifies uniqueness contract (the registry's AtomicInteger).
        val first = newResult()
        val firstSlot: CapturingSlot<String> = slot()
        every { first.success(capture(firstSlot)) } answers { }
        handler.handle(
            call("resolveOfferManagerHandle", mapOf("stripeCustomerId" to "cus_a")),
            first,
        )

        val second = newResult()
        val secondSlot: CapturingSlot<String> = slot()
        every { second.success(capture(secondSlot)) } answers { }
        handler.handle(
            call("resolveOfferManagerHandle", mapOf("stripeCustomerId" to "cus_b")),
            second,
        )

        assertThat(firstSlot.captured).isEqualTo("1")
        assertThat(secondSlot.captured).isEqualTo("2")
    }

    @Test
    fun `resolveOfferManagerHandle accepts missing stripeCustomerId`() {
        // Dart wire's arg is optional — the registry's `allocate` accepts
        // null and forwards to `ZeroSettle.offerManager(null)`. Verify we
        // don't reject the call shape.
        val result = newResult()
        handler.handle(call("resolveOfferManagerHandle", emptyMap<String, Any?>()), result)
        verify { result.success(any()) }
        verify(exactly = 0) { result.error(any(), any(), any()) }
    }

    @Test
    fun `resolveOfferManagerHandle accepts null args`() {
        // Some Dart call sites pass `null` instead of an empty map. Handler
        // must not crash on `call.arguments == null`.
        val result = newResult()
        handler.handle(call("resolveOfferManagerHandle", null), result)
        verify { result.success(any()) }
        verify(exactly = 0) { result.error(any(), any(), any()) }
    }

    @Test
    fun `resolveOfferManagerHandle forwards stripeCustomerId to SDK`() {
        // The SDK's `ZeroSettle.offerManager(stripeCustomerId)` is the bind
        // point — verify the handler doesn't drop the customer id. The
        // value passed in the test is non-null, so a plain `String` slot
        // captures it without the nullable-mockk dance.
        val customerSlot: CapturingSlot<String> = slot()
        every { ZeroSettle.offerManager(capture(customerSlot)) } answers {
            mockk<OfferManager>(relaxed = true)
        }

        handler.handle(
            call("resolveOfferManagerHandle", mapOf("stripeCustomerId" to "cus_forward_check")),
            newResult(),
        )

        assertThat(customerSlot.captured).isEqualTo("cus_forward_check")
    }

    // ─── resolveOfferManagerHandle — registry / bridge failures ─────────

    @Test
    fun `resolveOfferManagerHandle returns sdk_error when SDK throws`() {
        // ZeroSettle.offerManager() raising propagates up through
        // registry.allocate() and is caught by the handler's outer try.
        // Maps via sendError; non-ZeroSettleError throws hit `sdk_error`.
        every { ZeroSettle.offerManager(any()) } throws RuntimeException("boom")

        val result = newResult()
        handler.handle(
            call("resolveOfferManagerHandle", mapOf("stripeCustomerId" to "cus_x")),
            result,
        )

        verify { result.error(eq("sdk_error"), eq("boom"), null) }
        verify(exactly = 0) { result.success(any()) }
    }

    @Test
    fun `resolveOfferManagerHandle maps UserNotIdentified to wire code`() {
        // If the SDK eagerly rejects an unidentified user at offerManager()
        // time, the handler should surface the typed wire code rather than
        // the generic sdk_error.
        every { ZeroSettle.offerManager(any()) } throws ZeroSettleError.UserNotIdentified

        val result = newResult()
        handler.handle(
            call("resolveOfferManagerHandle", null),
            result,
        )

        verify { result.error(eq("user_not_identified"), any(), null) }
    }

    // ─── resolveMigrationManagerHandle — Android has no MigrationManager ─

    @Test
    fun `resolveMigrationManagerHandle returns not_implemented`() {
        val result = newResult()
        val codeSlot: CapturingSlot<String> = slot()
        val messageSlot: CapturingSlot<String> = slot()

        handler.handle(
            call("resolveMigrationManagerHandle", mapOf("stripeCustomerId" to "cus_x")),
            result,
        )

        verify { result.error(capture(codeSlot), capture(messageSlot), null) }
        verify(exactly = 0) { result.success(any()) }
        assertThat(codeSlot.captured).isEqualTo("not_implemented")
        // Message must point adopters at the OfferManager alternative so
        // developers know what to switch to without reading source.
        assertThat(messageSlot.captured).contains("OfferManager")
    }

    @Test
    fun `resolveMigrationManagerHandle ignores args (still not_implemented)`() {
        // Whatever Dart sends — it doesn't matter, the answer is the same.
        val result = newResult()
        handler.handle(call("resolveMigrationManagerHandle", null), result)
        verify { result.error(eq("not_implemented"), any(), null) }
    }
}
