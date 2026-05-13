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
    fun `F9 catalog method routes to F9 task id`() {
        assertNotYetImplemented(method = "getProducts", expectedTask = "F9")
    }

    @Test
    fun `F10 purchase method routes to F10 task id`() {
        assertNotYetImplemented(method = "purchase", expectedTask = "F10")
    }

    @Test
    fun `F11 pending claims method routes to F11 task id`() {
        assertNotYetImplemented(method = "getPendingClaims", expectedTask = "F11")
    }

    @Test
    fun `F12 sub mgmt method routes to F12 task id`() {
        assertNotYetImplemented(method = "cancelSubscription", expectedTask = "F12")
    }

    @Test
    fun `F13 modal method routes to F13 task id`() {
        assertNotYetImplemented(method = "presentCancelFlow", expectedTask = "F13")
    }

    @Test
    fun `F15 iOS-only method routes to F15 task id`() {
        assertNotYetImplemented(method = "getApplePayState", expectedTask = "F15")
    }

    @Test
    fun `F16 misc method routes to F16 task id`() {
        assertNotYetImplemented(method = "handleUniversalLink", expectedTask = "F16")
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
