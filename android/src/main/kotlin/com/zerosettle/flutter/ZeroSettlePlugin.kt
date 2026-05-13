package com.zerosettle.flutter

import android.app.Activity
import android.content.Context
import android.util.Log
import com.zerosettle.flutter.handlers.CatalogHandler
import com.zerosettle.flutter.handlers.HandlerDependencies
import com.zerosettle.flutter.handlers.IdentityHandler
import com.zerosettle.flutter.offermanager.OfferManagerHandleRegistry
import com.zerosettle.flutter.offermanager.OfferManagerStaticHandler
import com.zerosettle.flutter.platformviews.MigrateTipViewFactory
import com.zerosettle.flutter.platformviews.OfferTipFactory
import com.zerosettle.flutter.platformviews.PendingActionBannerFactory
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel

/**
 * Android counterpart to the iOS plugin core (see
 * `ios/zerosettle/Sources/zerosettle/ZeroSettlePlugin.swift`). F7 lands the
 * scaffold — channels, factories, registry, lifecycle. Each per-domain
 * branch of [onMethodCall] still returns the tagged `zerosettle_phase2_wip`
 * error pointing at the responsible task ID; F8–F17 replace each branch
 * with the real handler.
 *
 * ## Wire layout
 *
 * | Surface                                         | Owner                        |
 * | ----------------------------------------------- | ---------------------------- |
 * | `zerosettle` (MethodChannel)                    | [onMethodCall] (this class)  |
 * | `zerosettle/entitlement_updates` (EventChannel) | [entitlementStreamHandler]   |
 * | `zerosettle/checkout_events` (EventChannel)     | [checkoutStreamHandler]      |
 * | `zerosettle/pending_claims_updates` (EventCh.)  | [pendingClaimsStreamHandler] |
 * | `zerosettle/apple_pay_state_updates` (EventCh.) | [applePayStateStreamHandler] |
 * | `zerosettle/offer_manager_static` (MethodCh.)   | [OfferManagerStaticHandler]  |
 * | `zerosettle/offer_manager_<id>` (per-handle)    | F20 bridge, allocated by F18 |
 * | `zerosettle/offer_manager_<id>_state` (events)  | F20 bridge, allocated by F18 |
 *
 * Channel names match iOS exactly — the wire contract is symmetric and
 * Dart's `lib/zerosettle_method_channel.dart` calls into the same names on
 * either platform.
 *
 * ## Method dispatch (this is the wire contract)
 *
 * The `when` block in [onMethodCall] enumerates every method Dart calls on
 * the main channel — sourced from `lib/zerosettle_method_channel.dart` and
 * cross-checked against `ios/zerosettle/Sources/zerosettle/ZeroSettlePlugin.swift`.
 * Methods are grouped by the task ID that lands the real handler:
 *
 *   - **F8** identity (landed — see [IdentityHandler]): `configure`,
 *     `bootstrap`, `identify`, `logout`, `setCustomer`,
 *     `transferStoreKitOwnershipToCurrentUser`, `getCurrentUserId`,
 *     `getIsBootstrapped`, `getIsConfigured`
 *   - **F9** catalog / entitlements (landed — see [CatalogHandler]):
 *     `fetchProducts`, `getProducts`, `product`, `hasActiveEntitlement`,
 *     `getEntitlements`, `restoreEntitlements`
 *   - **F10** purchase: `purchase`, `purchaseViaStoreKit`,
 *     `presentPaymentSheet`, `preloadPaymentSheet`, `warmUpPaymentSheet`
 *   - **F11** pending claims: `getPendingClaims`
 *   - **F12** subscription mgmt: `openCustomerPortal`,
 *     `showManageSubscription`, `cancelSubscription`, `pauseSubscription`,
 *     `resumeSubscription`, `acceptSaveOffer`,
 *     `submitCancelFlowResponse`, `getCancelFlowConfig`,
 *     `fetchCancelFlowConfig`
 *   - **F13** modal launches: `presentCancelFlow`, `presentUpgradeOffer`,
 *     `fetchUpgradeOfferConfig`
 *   - **F15** iOS-only stubs (Android returns the tagged error today;
 *     **`presentSaveTheSaleSheet` is iOS-only per user direction and will
 *     stay `notImplemented` on Android indefinitely**):
 *     `recommendedAppAccountToken`, `presentApplePaySetup`,
 *     `getIsApplePayOnly`, `getApplePayState`
 *   - **F16** misc: `handleUniversalLink`, `getRemoteConfig`,
 *     `getDetectedJurisdiction`, `getPendingCheckout`, `setBaseUrlOverride`,
 *     `trackEvent`, `trackMigrationConversion`, `resetMigrateTipState`,
 *     `fetchTransactionHistory`
 *   - **F17** handle resolution: `resolveOfferManagerHandle`,
 *     `resolveMigrationManagerHandle`
 *
 * Methods on **per-handle** channels (`zerosettle/offer_manager_<id>`,
 * `zerosettle/migration_manager_<id>`) — `getState`, `present`, `dismiss`,
 * `startCheckout`, `preloadCheckout`, `markCheckoutSucceeded`,
 * `showAppleSubscriptionManagement`, `disposeHandle` — are NOT in this
 * dispatcher; they're owned by F20's `OfferManagerHandleBridge`. Likewise
 * the static dismissal methods (`isPermanentlyDismissed`, `setDismissed`,
 * `resetDismissedState`) live on the `offer_manager_static` channel handled
 * by [OfferManagerStaticHandler].
 *
 * ## Known gaps (left for future tasks)
 *
 *   - `zerosettle/migration_manager_static` channel — Dart's deprecated
 *     `ZeroSettleMigrationManagerStatics` wires it; not in F19 scope. Calls
 *     fall through Flutter's default `notImplemented()` until a future
 *     task either wires it or removes the Dart side.
 *   - Per-handle migration-manager channels (`zerosettle/migration_manager_<id>`)
 *     — same.
 *   - `getApplePayState` Android contract is documented to return
 *     `"unavailable"` (see Dart `getApplePayState`); for now F7 returns the
 *     tagged error and F15 lands the real `"unavailable"` literal.
 */
class ZeroSettlePlugin : FlutterPlugin, MethodCallHandler, ActivityAware {

    /** Plugin-wide scope. Lives for the engine's lifetime. */
    private lateinit var pluginScope: CoroutineScope

    /** Main `zerosettle` MethodChannel. */
    private lateinit var mainChannel: MethodChannel

    /** Static OfferManager channel (F19 handler). */
    private lateinit var offerManagerStaticChannel: MethodChannel
    private lateinit var offerManagerStaticHandler: OfferManagerStaticHandler

    /** EventChannels — names match iOS exactly + Dart wire contract. */
    private lateinit var entitlementEventChannel: EventChannel
    private lateinit var checkoutEventChannel: EventChannel
    private lateinit var pendingClaimsEventChannel: EventChannel
    private lateinit var applePayStateEventChannel: EventChannel

    /**
     * Buffered EventChannel sinks. F25 publishes into these from SDK Flow
     * collectors; the buffered-sink pattern lets the plugin emit without
     * juggling onListen/onCancel lifecycle from each emit site.
     *
     * Apple Pay availability is iOS-only — the channel exists for Dart-side
     * subscription parity but the Android sink will never emit.
     */
    internal val entitlementStreamHandler = BufferedStreamHandler()
    internal val checkoutStreamHandler = BufferedStreamHandler()
    internal val pendingClaimsStreamHandler = BufferedStreamHandler()
    internal val applePayStateStreamHandler = BufferedStreamHandler()

    /** Per-handle OfferManager registry (F18). Allocated on engine attach. */
    internal lateinit var offerManagerRegistry: OfferManagerHandleRegistry

    /**
     * F8 identity/lifecycle handler. Owns the 9 lifecycle methods Dart
     * calls on the main channel. Allocated on engine attach so it sees
     * the freshly-constructed scope + activity provider.
     */
    private lateinit var identityHandler: IdentityHandler

    /**
     * F9 catalog/entitlements handler. Owns six catalog + entitlement
     * methods on the main channel. Same allocation pattern as F8.
     */
    private lateinit var catalogHandler: CatalogHandler

    /**
     * Tracked Activity. F8–F17 handlers that launch the host activity
     * (CustomTabs entry, CheckoutSheet entry) read via [activityProvider].
     * `@Volatile` because ActivityAware callbacks fire on the main thread
     * but handler coroutines may resume on background dispatchers.
     */
    @Volatile private var activity: Activity? = null

    /** Lambda accessor — exposed to handlers in F8–F17. */
    internal val activityProvider: () -> Activity? = { activity }

    /** Application context — cached for CustomTabs `Intent` issuance. */
    @Volatile private var applicationContext: Context? = null
    internal val applicationContextProvider: () -> Context? = { applicationContext }

    // ── FlutterPlugin ────────────────────────────────────────────────

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        pluginScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

        val messenger: BinaryMessenger = binding.binaryMessenger

        // Main MethodChannel.
        mainChannel = MethodChannel(messenger, "zerosettle")
        mainChannel.setMethodCallHandler(this)

        // EventChannels (F25 publishes; F7 just installs the stream handlers).
        entitlementEventChannel = EventChannel(messenger, "zerosettle/entitlement_updates").apply {
            setStreamHandler(entitlementStreamHandler)
        }
        checkoutEventChannel = EventChannel(messenger, "zerosettle/checkout_events").apply {
            setStreamHandler(checkoutStreamHandler)
        }
        pendingClaimsEventChannel = EventChannel(messenger, "zerosettle/pending_claims_updates").apply {
            setStreamHandler(pendingClaimsStreamHandler)
        }
        applePayStateEventChannel = EventChannel(messenger, "zerosettle/apple_pay_state_updates").apply {
            setStreamHandler(applePayStateStreamHandler)
        }

        // F8 identity/lifecycle handler. Build the shared HandlerDependencies
        // bundle here so F9-F17 can adopt the same plumbing without each
        // handler needing the plugin's private fields exposed. The lambdas
        // capture `this`, so the activity/context providers always reflect
        // the plugin's current state (post-config-change reattach included).
        val handlerDeps = HandlerDependencies(
            scope = pluginScope,
            activityProvider = activityProvider,
            applicationContextProvider = applicationContextProvider,
        )
        identityHandler = IdentityHandler(handlerDeps)
        catalogHandler = CatalogHandler(handlerDeps)

        // OfferManager registry (F18) — per-handle channel allocator.
        offerManagerRegistry = OfferManagerHandleRegistry(messenger)

        // OfferManager static channel (F19).
        offerManagerStaticHandler = OfferManagerStaticHandler(pluginScope)
        offerManagerStaticChannel =
            MethodChannel(messenger, "zerosettle/offer_manager_static").apply {
                setMethodCallHandler(offerManagerStaticHandler)
            }

        // PlatformView factories (F22–F24).
        binding.platformViewRegistry
            .registerViewFactory("com.zerosettle/offer_tip", OfferTipFactory())
        binding.platformViewRegistry
            .registerViewFactory("com.zerosettle/pending_action_banner", PendingActionBannerFactory())
        binding.platformViewRegistry
            .registerViewFactory("com.zerosettle/migrate_tip_view", MigrateTipViewFactory(messenger))

        Log.i(
            "ZeroSettle",
            "Android plugin attached (F7 scaffold; per-domain handlers land in F8-F17)"
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // Tear down everything we allocated. Order matters: detach channel
        // handlers BEFORE cancelling the scope so any in-flight handler
        // invocation has somewhere to return to. The registry's disposeAll
        // is internally idempotent and synchronized.
        mainChannel.setMethodCallHandler(null)
        offerManagerStaticChannel.setMethodCallHandler(null)
        entitlementEventChannel.setStreamHandler(null)
        checkoutEventChannel.setStreamHandler(null)
        pendingClaimsEventChannel.setStreamHandler(null)
        applePayStateEventChannel.setStreamHandler(null)
        offerManagerRegistry.disposeAll()
        pluginScope.cancel()
        applicationContext = null
    }

    // ── ActivityAware ────────────────────────────────────────────────

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    // ── MethodCallHandler ────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: Result) {
        // Per-domain handlers consume their own methods. Each handler's
        // `handle(call, result)` returns true if it owned the method, false
        // otherwise — fall through to the next handler / the WIP-error
        // dispatch below if no handler claims the call. F8 owns identity,
        // F9 owns catalog + entitlements; F10-F17 are still WIP-error stubs.
        if (identityHandler.handle(call, result)) return
        if (catalogHandler.handle(call, result)) return

        when (call.method) {
            // === F10 — Purchase + payment sheet ===
            "purchase",
            "purchaseViaStoreKit",
            "presentPaymentSheet",
            "preloadPaymentSheet",
            "warmUpPaymentSheet" ->
                notYetImplemented(call.method, "F10", result)

            // === F11 — Pending claims ===
            "getPendingClaims" ->
                notYetImplemented(call.method, "F11", result)

            // === F12 — Subscription management ===
            "openCustomerPortal",
            "showManageSubscription",
            "cancelSubscription",
            "pauseSubscription",
            "resumeSubscription",
            "acceptSaveOffer",
            "submitCancelFlowResponse",
            "getCancelFlowConfig",
            "fetchCancelFlowConfig" ->
                notYetImplemented(call.method, "F12", result)

            // === F13 — Modal launches (cancel flow / upgrade offer) ===
            "presentCancelFlow",
            "presentUpgradeOffer",
            "fetchUpgradeOfferConfig" ->
                notYetImplemented(call.method, "F13", result)

            // === F15 — iOS-only stubs ===
            // `presentSaveTheSaleSheet` is iOS-only per user direction (the
            // Save-the-Sale flow has no Android counterpart). It falls
            // through to `notImplemented()` rather than the tagged error
            // because no Android task will ever land it.
            "recommendedAppAccountToken",
            "presentApplePaySetup",
            "getIsApplePayOnly",
            "getApplePayState" ->
                notYetImplemented(call.method, "F15", result)

            // === F16 — Misc (universal links, remote config, tracking, history) ===
            "handleUniversalLink",
            "getRemoteConfig",
            "getDetectedJurisdiction",
            "getPendingCheckout",
            "setBaseUrlOverride",
            "trackEvent",
            "trackMigrationConversion",
            "resetMigrateTipState",
            "fetchTransactionHistory" ->
                notYetImplemented(call.method, "F16", result)

            // === F17 — Handle resolution (offer + migration managers) ===
            "resolveOfferManagerHandle",
            "resolveMigrationManagerHandle" ->
                notYetImplemented(call.method, "F17", result)

            else -> result.notImplemented()
        }
    }

    /**
     * Tagged error returned for every dispatched method whose real handler
     * hasn't landed yet. The error code matches the previous WIP stub
     * (`zerosettle_phase2_wip`) so any tooling watching for it keeps
     * working. The message bakes in the responsible task ID so logs point
     * directly at the next-step file in the plan.
     */
    private fun notYetImplemented(method: String, taskId: String, result: Result) {
        result.error(
            "zerosettle_phase2_wip",
            "Method '$method' lands in task $taskId of feat/1.3.0-parity. " +
                "Plan: docs/superpowers/plans/2026-05-12-flutter-android-parity-plan.md",
            null,
        )
    }
}

/**
 * Generic [EventChannel.StreamHandler] that buffers the latest sink so the
 * plugin can emit from coroutines without juggling lifecycle.
 *
 * `sink` is exposed for F25's SDK-Flow → EventChannel collectors to call.
 * `@Volatile` because the sink is written from the main thread by the
 * Flutter framework (onListen / onCancel callbacks) and read from arbitrary
 * coroutine dispatchers.
 */
internal class BufferedStreamHandler : EventChannel.StreamHandler {
    @Volatile
    var sink: EventChannel.EventSink? = null
        private set

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }
}
