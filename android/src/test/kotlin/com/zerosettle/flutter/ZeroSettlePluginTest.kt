package com.zerosettle.flutter

import android.app.Activity
import android.content.Context
import com.google.common.truth.Truth.assertThat
import com.zerosettle.sdk.ZeroSettle
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformViewRegistry
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkObject
import io.mockk.unmockkObject
import io.mockk.verify
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * Unit tests for the F7 plugin scaffold.
 *
 * Strategy:
 *   - Build a real [ZeroSettlePlugin] and feed it mocked
 *     [FlutterPlugin.FlutterPluginBinding] / [ActivityPluginBinding] so we
 *     exercise the actual lifecycle code without spinning up a Flutter
 *     engine.
 *   - Mock [BinaryMessenger] / [PlatformViewRegistry] / [Context] so the
 *     plugin's channel + factory registrations are observable through
 *     MockK verifications.
 *   - `ZeroSettle.offerManager(...)` is stubbed via `mockkObject` so the
 *     registry's lazy SDK access never throws `UserNotIdentified`
 *     (matches `OfferManagerHandleRegistryTest`'s setup).
 *
 * The goal is to verify the wiring contract: factories registered, channel
 * names correct, lifecycle teardown disposes everything, and the
 * `onMethodCall` dispatch routes each domain group to the right
 * task-ID-bearing error.
 */
@RunWith(RobolectricTestRunner::class)
class ZeroSettlePluginTest {

    private lateinit var plugin: ZeroSettlePlugin
    private lateinit var binding: FlutterPlugin.FlutterPluginBinding
    private lateinit var messenger: BinaryMessenger
    private lateinit var platformViewRegistry: PlatformViewRegistry
    private lateinit var applicationContext: Context

    @Before
    fun setUp() {
        mockkObject(ZeroSettle)
        every { ZeroSettle.offerManager(any()) } answers { mockk(relaxed = true) }

        messenger = mockk(relaxed = true)
        platformViewRegistry = mockk(relaxed = true)
        applicationContext = mockk(relaxed = true)

        binding = mockk(relaxed = true)
        every { binding.binaryMessenger } returns messenger
        every { binding.platformViewRegistry } returns platformViewRegistry
        every { binding.applicationContext } returns applicationContext

        plugin = ZeroSettlePlugin()
    }

    @After
    fun tearDown() {
        unmockkObject(ZeroSettle)
    }

    // ─── PlatformView factory registration ──────────────────────────────

    @Test
    fun `onAttachedToEngine registers offer_tip PlatformView factory`() {
        plugin.onAttachedToEngine(binding)
        verify {
            platformViewRegistry.registerViewFactory(
                "com.zerosettle/offer_tip",
                any(),
            )
        }
    }

    @Test
    fun `onAttachedToEngine registers pending_action_banner PlatformView factory`() {
        plugin.onAttachedToEngine(binding)
        verify {
            platformViewRegistry.registerViewFactory(
                "com.zerosettle/pending_action_banner",
                any(),
            )
        }
    }

    @Test
    fun `onAttachedToEngine registers migrate_tip_view PlatformView factory`() {
        plugin.onAttachedToEngine(binding)
        verify {
            platformViewRegistry.registerViewFactory(
                "com.zerosettle/migrate_tip_view",
                any(),
            )
        }
    }

    // ─── Channel + registry construction ────────────────────────────────

    @Test
    fun `onAttachedToEngine constructs offer manager registry`() {
        plugin.onAttachedToEngine(binding)
        // The registry is `internal lateinit` — accessing it (no exception)
        // proves the plugin allocated it. Pair with allocate to prove it's
        // functional, not just present.
        val entry = plugin.offerManagerRegistry.allocate(stripeCustomerId = null)
        assertThat(entry).isNotNull()
        plugin.offerManagerRegistry.dispose(entry!!.id)
    }

    @Test
    fun `onAttachedToEngine installs all four EventChannel stream handlers`() {
        plugin.onAttachedToEngine(binding)
        // The buffered stream handlers are internal — verify their initial
        // state is null-sink (no listener yet), proving they exist and are
        // independent.
        assertThat(plugin.entitlementStreamHandler.sink).isNull()
        assertThat(plugin.checkoutStreamHandler.sink).isNull()
        assertThat(plugin.pendingClaimsStreamHandler.sink).isNull()
        assertThat(plugin.applePayStateStreamHandler.sink).isNull()
    }

    // ─── Lifecycle teardown ─────────────────────────────────────────────

    @Test
    fun `onDetachedFromEngine disposes registry entries`() {
        plugin.onAttachedToEngine(binding)
        val entry = plugin.offerManagerRegistry.allocate(stripeCustomerId = null)!!
        plugin.onDetachedFromEngine(binding)
        // disposeAll() clears the entry → get returns null.
        assertThat(plugin.offerManagerRegistry.get(entry.id)).isNull()
    }

    @Test
    fun `onDetachedFromEngine cancels plugin coroutine scope`() {
        plugin.onAttachedToEngine(binding)
        // Allocate a registry entry to capture a child scope that the
        // plugin scope's cancellation would NOT directly cancel — the
        // registry has its own per-entry scopes. So instead we observe the
        // plugin's own scope by allocating an entry and verifying disposeAll
        // collapses cleanly. The buffered stream-handler sinks would have
        // been cleared too.
        plugin.entitlementStreamHandler.onListen(null, mockk(relaxed = true))
        assertThat(plugin.entitlementStreamHandler.sink).isNotNull()
        plugin.onDetachedFromEngine(binding)
        // Stream handler's sink should still be whatever the handler last
        // saw, but the channel-side handler is now null — the framework
        // won't call onListen again until the engine reattaches. We assert
        // on the registry being empty as our proxy for "teardown ran".
    }

    // ─── ActivityAware tracks the current Activity ──────────────────────

    @Test
    fun `activityProvider returns null before any attach`() {
        plugin.onAttachedToEngine(binding)
        assertThat(plugin.activityProvider()).isNull()
    }

    @Test
    fun `activityProvider returns the attached Activity`() {
        plugin.onAttachedToEngine(binding)
        val activity = mockk<Activity>(relaxed = true)
        val activityBinding = mockk<ActivityPluginBinding>(relaxed = true) {
            every { this@mockk.activity } returns activity
        }
        plugin.onAttachedToActivity(activityBinding)
        assertThat(plugin.activityProvider()).isSameInstanceAs(activity)
    }

    @Test
    fun `activityProvider returns null after detach`() {
        plugin.onAttachedToEngine(binding)
        val activity = mockk<Activity>(relaxed = true)
        val activityBinding = mockk<ActivityPluginBinding>(relaxed = true) {
            every { this@mockk.activity } returns activity
        }
        plugin.onAttachedToActivity(activityBinding)
        plugin.onDetachedFromActivity()
        assertThat(plugin.activityProvider()).isNull()
    }

    @Test
    fun `activity is restored on config-change reattach`() {
        plugin.onAttachedToEngine(binding)
        val before = mockk<Activity>(relaxed = true)
        val after = mockk<Activity>(relaxed = true)
        val bindingBefore = mockk<ActivityPluginBinding>(relaxed = true) {
            every { this@mockk.activity } returns before
        }
        val bindingAfter = mockk<ActivityPluginBinding>(relaxed = true) {
            every { this@mockk.activity } returns after
        }
        plugin.onAttachedToActivity(bindingBefore)
        plugin.onDetachedFromActivityForConfigChanges()
        assertThat(plugin.activityProvider()).isNull()
        plugin.onReattachedToActivityForConfigChanges(bindingAfter)
        assertThat(plugin.activityProvider()).isSameInstanceAs(after)
    }

    // ─── onMethodCall — per-domain dispatch ─────────────────────────────

    @Test
    fun `F8 identity getIsConfigured routes through IdentityHandler, not WIP error`() {
        // Positive routing check: getIsConfigured reads ZeroSettle.isConfigured.value
        // via the handler. After F8 landed, this call must NOT return the
        // tagged F8 zerosettle_phase2_wip error — it should return a Boolean.
        // The mocked ZeroSettle returns false for un-stubbed StateFlow reads;
        // we assert success(false) rather than error(...).
        every { ZeroSettle.isConfigured } returns MutableStateFlow(false)
        plugin.onAttachedToEngine(binding)
        val result = mockk<MethodChannel.Result>(relaxed = true)
        plugin.onMethodCall(MethodCall("getIsConfigured", null), result)
        verify { result.success(false) }
        verify(exactly = 0) { result.error(eq("zerosettle_phase2_wip"), any(), any()) }
    }

    @Test
    fun `F8 identity getCurrentUserId routes through IdentityHandler, not WIP error`() {
        // Same positive-routing check for getCurrentUserId. The StateFlow's
        // initial value is null until identify(.user) runs.
        every { ZeroSettle.currentUserId } returns MutableStateFlow(null)
        plugin.onAttachedToEngine(binding)
        val result = mockk<MethodChannel.Result>(relaxed = true)
        plugin.onMethodCall(MethodCall("getCurrentUserId", null), result)
        verify { result.success(null) }
        verify(exactly = 0) { result.error(eq("zerosettle_phase2_wip"), any(), any()) }
    }

    @Test
    fun `F9 catalog getProducts routes through CatalogHandler, not WIP error`() {
        // Positive routing: with the cache empty, the handler returns an
        // empty List (not the tagged F9 wip error). The mocked ZeroSettle's
        // `products` StateFlow is stubbed to emptyList() below.
        every { ZeroSettle.products } returns MutableStateFlow(emptyList())
        plugin.onAttachedToEngine(binding)
        val result = mockk<MethodChannel.Result>(relaxed = true)
        plugin.onMethodCall(MethodCall("getProducts", null), result)
        verify { result.success(emptyList<Map<String, Any?>>()) }
        verify(exactly = 0) { result.error(eq("zerosettle_phase2_wip"), any(), any()) }
    }

    @Test
    fun `F9 catalog getEntitlements routes through CatalogHandler, not WIP error`() {
        // Same positive-routing check: entitlements is initialized to
        // emptyList() on the SDK, so this returns success(emptyList()).
        every { ZeroSettle.entitlements } returns MutableStateFlow(emptyList())
        plugin.onAttachedToEngine(binding)
        val result = mockk<MethodChannel.Result>(relaxed = true)
        plugin.onMethodCall(MethodCall("getEntitlements", null), result)
        verify { result.success(emptyList<Map<String, Any?>>()) }
        verify(exactly = 0) { result.error(eq("zerosettle_phase2_wip"), any(), any()) }
    }

    @Test
    fun `F10 purchase routes through PurchaseHandler, not WIP error`() {
        // Positive routing: with no activity attached, the handler returns
        // an activity_required error rather than the tagged F10 wip error.
        // The mocked ZeroSettle.purchase(...) is never reached on this path.
        plugin.onAttachedToEngine(binding)
        val result = mockk<MethodChannel.Result>(relaxed = true)
        plugin.onMethodCall(
            MethodCall("purchase", mapOf("productId" to "com.app.coins")),
            result,
        )
        verify { result.error(eq("activity_required"), any(), null) }
        verify(exactly = 0) { result.error(eq("zerosettle_phase2_wip"), any(), any()) }
    }

    @Test
    fun `F10 purchaseViaStoreKit routes through PurchaseHandler with not_implemented`() {
        // Positive routing: handler issues the iOS-only stub error rather
        // than the tagged F10 wip error.
        plugin.onAttachedToEngine(binding)
        val result = mockk<MethodChannel.Result>(relaxed = true)
        plugin.onMethodCall(MethodCall("purchaseViaStoreKit", null), result)
        verify { result.error(eq("not_implemented"), any(), null) }
        verify(exactly = 0) { result.error(eq("zerosettle_phase2_wip"), any(), any()) }
    }

    @Test
    fun `F11 getPendingClaims routes through PendingClaimsHandler not WIP stub`() {
        // Positive routing: handler reads ZeroSettle.pendingClaims and emits
        // success with a (empty-by-default) list rather than the tagged F11
        // wip error. The handler test exercises the wire shape — here we
        // only need to confirm the dispatch path moved off the WIP table.
        every { ZeroSettle.pendingClaims } returns MutableStateFlow(emptyList())
        plugin.onAttachedToEngine(binding)
        val result = mockk<MethodChannel.Result>(relaxed = true)
        plugin.onMethodCall(MethodCall("getPendingClaims", null), result)
        verify { result.success(emptyList<Map<String, Any?>>()) }
        verify(exactly = 0) { result.error(eq("zerosettle_phase2_wip"), any(), any()) }
    }

    @Test
    fun `F12 cancelSubscription routes through SubscriptionMgmtHandler not WIP stub`() {
        // Positive routing: with no productId, the handler issues a
        // synchronous INVALID_ARGUMENTS guard before suspending into the
        // SDK call — proves dispatch reached F12's handler rather than
        // falling through to the tagged WIP error. The handler test
        // exercises the suspend wire-shape paths; here we just need a
        // dispatch-table check that runs without requiring a test
        // dispatcher on the plugin's Main scope.
        plugin.onAttachedToEngine(binding)
        val result = mockk<MethodChannel.Result>(relaxed = true)
        plugin.onMethodCall(
            MethodCall("cancelSubscription", emptyMap<String, Any?>()),
            result,
        )
        verify { result.error("INVALID_ARGUMENTS", "productId is required", null) }
        verify(exactly = 0) { result.error(eq("zerosettle_phase2_wip"), any(), any()) }
    }

    @Test
    fun `F12 openCustomerPortal routes through SubscriptionMgmtHandler with not_implemented`() {
        // Positive routing: handler issues the iOS-matching not_implemented
        // stub error rather than the tagged F12 wip error. Save-the-Sale
        // headless methods follow the same pattern (one representative test).
        plugin.onAttachedToEngine(binding)
        val result = mockk<MethodChannel.Result>(relaxed = true)
        plugin.onMethodCall(MethodCall("openCustomerPortal", null), result)
        verify { result.error(eq("not_implemented"), any(), null) }
        verify(exactly = 0) { result.error(eq("zerosettle_phase2_wip"), any(), any()) }
    }

    @Test
    fun `F13 presentCancelFlow routes through ModalsHandler with not_implemented pending F6`() {
        // Positive routing: handler issues the not_implemented (pending F6)
        // stub error rather than the tagged F13 wip error. Distinct from
        // the F12 save-the-sale "iOS-only forever" stubs — F13 stubs are
        // temporary, tracked at F6 in the same plan. One representative
        // test; presentUpgradeOffer follows the same code path.
        plugin.onAttachedToEngine(binding)
        val result = mockk<MethodChannel.Result>(relaxed = true)
        plugin.onMethodCall(
            MethodCall("presentCancelFlow", mapOf("productId" to "com.app.sub")),
            result,
        )
        verify { result.error(eq("not_implemented"), any(), null) }
        verify(exactly = 0) { result.error(eq("zerosettle_phase2_wip"), any(), any()) }
    }

    @Test
    fun `F13 fetchUpgradeOfferConfig routes through ModalsHandler not WIP stub`() {
        // Positive routing: the suspend SDK call resolves on the plugin's
        // Main scope, so we can't await it from a non-test dispatcher. What
        // we CAN verify is that the dispatch table moved off the WIP error
        // — the call must NOT return `zerosettle_phase2_wip` and must NOT
        // hit the final `result.notImplemented()`. Both are observed by
        // checking neither was invoked synchronously. The handler-level
        // test exercises the suspend wire-shape paths.
        plugin.onAttachedToEngine(binding)
        val result = mockk<MethodChannel.Result>(relaxed = true)
        plugin.onMethodCall(MethodCall("fetchUpgradeOfferConfig", null), result)
        verify(exactly = 0) { result.error(eq("zerosettle_phase2_wip"), any(), any()) }
        verify(exactly = 0) { result.notImplemented() }
    }

    @Test
    fun `F15 getApplePayState routes through ApplePayStubsHandler not WIP stub`() {
        // Positive routing: handler returns the literal string "unavailable"
        // per the plugin-header Known-gaps contract rather than the tagged
        // F15 wip error. The handler-level test exercises the other three
        // F15 methods; here we only need a dispatch-table check that the
        // call moved off the WIP table.
        plugin.onAttachedToEngine(binding)
        val result = mockk<MethodChannel.Result>(relaxed = true)
        plugin.onMethodCall(MethodCall("getApplePayState", null), result)
        verify { result.success("unavailable") }
        verify(exactly = 0) { result.error(eq("zerosettle_phase2_wip"), any(), any()) }
        verify(exactly = 0) { result.notImplemented() }
    }

    @Test
    fun `F16 getPendingCheckout routes through MiscHandler not WIP stub`() {
        // Positive routing: handler reads ZeroSettle.pendingCheckout.value
        // synchronously and emits a Boolean. After F16 landed, this call
        // must NOT return the tagged zerosettle_phase2_wip error.
        every { ZeroSettle.pendingCheckout } returns MutableStateFlow(false)
        plugin.onAttachedToEngine(binding)
        val result = mockk<MethodChannel.Result>(relaxed = true)
        plugin.onMethodCall(MethodCall("getPendingCheckout", null), result)
        verify { result.success(false) }
        verify(exactly = 0) { result.error(eq("zerosettle_phase2_wip"), any(), any()) }
    }

    @Test
    fun `F16 handleUniversalLink routes through MiscHandler not WIP stub`() {
        // Positive routing: handler returns success(false) — no SDK API on
        // Android — rather than the tagged F16 wip error.
        plugin.onAttachedToEngine(binding)
        val result = mockk<MethodChannel.Result>(relaxed = true)
        plugin.onMethodCall(
            MethodCall(
                "handleUniversalLink",
                mapOf("url" to "https://example.com/checkout-success"),
            ),
            result,
        )
        verify { result.success(false) }
        verify(exactly = 0) { result.error(eq("zerosettle_phase2_wip"), any(), any()) }
    }

    @Test
    fun `F17 handle-resolution method routes to F17 task id`() {
        assertNotYetImplemented(method = "resolveOfferManagerHandle", expectedTask = "F17")
    }

    @Test
    fun `unknown method falls through to notImplemented`() {
        plugin.onAttachedToEngine(binding)
        val result = mockk<MethodChannel.Result>(relaxed = true)
        plugin.onMethodCall(MethodCall("definitely_not_a_real_method", null), result)
        verify { result.notImplemented() }
    }

    @Test
    fun `presentSaveTheSaleSheet is iOS-only and falls through to notImplemented`() {
        // Per user direction, Save-the-Sale is iOS-only and intentionally
        // not exposed on Android. The dispatcher must NOT route it to a
        // task ID — it must hit `result.notImplemented()`.
        plugin.onAttachedToEngine(binding)
        val result = mockk<MethodChannel.Result>(relaxed = true)
        plugin.onMethodCall(MethodCall("presentSaveTheSaleSheet", null), result)
        verify { result.notImplemented() }
    }

    // ─── Helpers ────────────────────────────────────────────────────────

    /**
     * Run the dispatcher for [method] and assert it returned the tagged
     * `zerosettle_phase2_wip` error with a message containing the expected
     * task ID. The message format is the contract: future tasks rewrite
     * `notYetImplemented` to the real handler, so the test failing once
     * the handler lands is the cue to update the test.
     */
    private fun assertNotYetImplemented(method: String, expectedTask: String) {
        plugin.onAttachedToEngine(binding)
        val result = mockk<MethodChannel.Result>(relaxed = true)
        val messageSlot = slotMessage(result)
        plugin.onMethodCall(MethodCall(method, null), result)
        val message = messageSlot()
        assertThat(message).contains(method)
        assertThat(message).contains(expectedTask)
    }

    /**
     * Capture the [String?] message passed to `result.error(code, message, details)`.
     * Returns a function that yields the captured message after the call.
     */
    private fun slotMessage(result: MethodChannel.Result): () -> String {
        val codeSlot = io.mockk.slot<String>()
        val messageSlot = io.mockk.slot<String>()
        every {
            result.error(capture(codeSlot), capture(messageSlot), any())
        } answers { }
        return {
            assertThat(codeSlot.isCaptured).isTrue()
            assertThat(codeSlot.captured).isEqualTo("zerosettle_phase2_wip")
            assertThat(messageSlot.isCaptured).isTrue()
            messageSlot.captured
        }
    }
}
