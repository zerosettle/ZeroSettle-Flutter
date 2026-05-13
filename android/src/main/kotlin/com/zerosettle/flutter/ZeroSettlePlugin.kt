package com.zerosettle.flutter

import android.app.Activity
import android.content.Context
import android.util.Log
import com.zerosettle.flutter.handlers.ApplePayStubsHandler
import com.zerosettle.flutter.handlers.CatalogHandler
import com.zerosettle.flutter.handlers.HandleResolutionHandler
import com.zerosettle.flutter.handlers.HandlerDependencies
import com.zerosettle.flutter.handlers.IdentityHandler
import com.zerosettle.flutter.handlers.MiscHandler
import com.zerosettle.flutter.handlers.ModalsHandler
import com.zerosettle.flutter.handlers.PendingClaimsHandler
import com.zerosettle.flutter.handlers.PurchaseHandler
import com.zerosettle.flutter.handlers.SubscriptionMgmtHandler
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
 * `ios/zerosettle/Sources/zerosettle/ZeroSettlePlugin.swift`). F7 landed the
 * scaffold — channels, factories, registry, lifecycle — and F8–F17 landed
 * the per-domain handlers. The `when` block that previously dispatched
 * tagged `zerosettle_phase2_wip` errors is gone; every Dart method on the
 * main channel either routes through a domain handler or falls through to
 * `result.notImplemented()` (currently only `presentSaveTheSaleSheet`,
 * which is iOS-only per product direction).
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
 *   - **F10** purchase + payment sheet (landed — see [PurchaseHandler]):
 *     `purchase`, `purchaseViaStoreKit`, `presentPaymentSheet`,
 *     `preloadPaymentSheet`, `warmUpPaymentSheet`
 *   - **F11** pending claims (landed — see [PendingClaimsHandler]):
 *     `getPendingClaims`
 *   - **F12** subscription mgmt (landed — see [SubscriptionMgmtHandler]):
 *     `cancelSubscription`, `pauseSubscription`, `resumeSubscription`
 *     forward to the SDK; `openCustomerPortal`, `showManageSubscription`,
 *     `acceptSaveOffer`, `submitCancelFlowResponse`, `getCancelFlowConfig`,
 *     `fetchCancelFlowConfig` return `not_implemented` (the first two
 *     match iOS — both APIs were removed from ZeroSettleKit; the last
 *     four are the iOS-only Save-the-Sale headless surface)
 *   - **F13** modal launches (landed — see [ModalsHandler]):
 *     `presentCancelFlow`, `presentUpgradeOffer` return `not_implemented`
 *     pending Task F6 (Compose Mode dispatch in
 *     [ZeroSettleHostActivity] — distinct from the F12 save-the-sale
 *     `iOS-only forever` stubs); `fetchUpgradeOfferConfig` forwards to
 *     the SDK
 *   - **F15** iOS Apple-Pay stubs (landed — see [ApplePayStubsHandler]):
 *     `recommendedAppAccountToken` and `presentApplePaySetup` return
 *     `not_implemented` (no Android analogue); `getIsApplePayOnly` returns
 *     `false`; `getApplePayState` returns the literal string `"unavailable"`
 *     (per the Known-gaps contract below). `presentSaveTheSaleSheet` is
 *     iOS-only per user direction and falls through to `notImplemented()` —
 *     it is NOT routed through this handler.
 *   - **F16** misc (landed — see [MiscHandler]): `getPendingCheckout`
 *     reads `ZeroSettle.pendingCheckout`; `trackMigrationConversion`
 *     forwards to the SDK with `PLAY_STORE` source baked in;
 *     `setBaseUrlOverride` logs + no-ops (constructor-only on Android);
 *     `handleUniversalLink` returns `false` (no SDK API);
 *     `getRemoteConfig` / `getDetectedJurisdiction` return `null` (no
 *     SDK API); `trackEvent` / `resetMigrateTipState` return
 *     `success(null)` (no SDK API); `fetchTransactionHistory` returns
 *     `not_implemented` (SDK currently returns raw JSON — typed model
 *     blocked on a follow-up SDK task).
 *   - **F17** handle resolution (landed — see [HandleResolutionHandler]):
 *     `resolveOfferManagerHandle` allocates a fresh
 *     [OfferManagerHandleRegistry] entry, starts an
 *     [com.zerosettle.flutter.offermanager.OfferManagerHandleBridge] to
 *     wire the per-handle method + state channels, and returns the id as
 *     a String (matching iOS's `UUID().uuidString`).
 *     `resolveMigrationManagerHandle` returns `not_implemented` — the
 *     Android SDK folds migration into `OfferManager`, and Dart's
 *     `MigrationManager` is `@Deprecated` in 1.4.0 with explicit migration
 *     guidance.
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
 *   - `getApplePayState` Android contract returns the literal string
 *     `"unavailable"` (see Dart `getApplePayState`); landed by F15 via
 *     [ApplePayStubsHandler].
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
     * F10 purchase + payment-sheet handler. Owns five methods on the main
     * channel — `purchase` (web checkout via Custom Tab),
     * `purchaseViaStoreKit` + `presentPaymentSheet` (iOS-only stubs), and
     * `preloadPaymentSheet` + `warmUpPaymentSheet` (no-ops with arg
     * validation; Android's preload is configure-time only). Same
     * allocation pattern as F8/F9.
     */
    private lateinit var purchaseHandler: PurchaseHandler

    /**
     * F11 pending-claims handler. Owns the single `getPendingClaims` method
     * on the main channel — synchronous read of [ZeroSettle.pendingClaims].
     * No coroutine launch required (StateFlow `.value` is non-suspending).
     * Same allocation pattern as F8/F9/F10.
     */
    private lateinit var pendingClaimsHandler: PendingClaimsHandler

    /**
     * F12 subscription-management handler. Owns nine methods on the main
     * channel — three SDK mutations (`cancelSubscription`,
     * `pauseSubscription`, `resumeSubscription`) plus six stub methods that
     * return `not_implemented` to match iOS (`openCustomerPortal`,
     * `showManageSubscription`) or per product decision (the four
     * save-the-sale headless methods). Same allocation pattern as
     * F8/F9/F10/F11.
     */
    private lateinit var subscriptionMgmtHandler: SubscriptionMgmtHandler

    /**
     * F13 modal-presentation handler. Owns three methods on the main
     * channel — `presentCancelFlow` and `presentUpgradeOffer` return
     * `not_implemented` pending Task F6 (Compose Mode dispatch in
     * [ZeroSettleHostActivity]); `fetchUpgradeOfferConfig` forwards to the
     * SDK. Same allocation pattern as F8/F9/F10/F11/F12.
     */
    private lateinit var modalsHandler: ModalsHandler

    /**
     * F15 iOS Apple-Pay stubs handler. Owns four iOS-only methods on the
     * main channel — `recommendedAppAccountToken` + `presentApplePaySetup`
     * return `not_implemented` (no Android analogue, callers must gate by
     * `Platform.isIOS`); `getIsApplePayOnly` returns `false`;
     * `getApplePayState` returns the literal string `"unavailable"` per the
     * documented Android wire contract. Same allocation pattern as
     * F8/F9/F10/F11/F12/F13.
     */
    private lateinit var applePayStubsHandler: ApplePayStubsHandler

    /**
     * F16 misc handler. Owns nine methods on the main channel —
     * `getPendingCheckout` and `trackMigrationConversion` forward to real
     * SDK surfaces; `setBaseUrlOverride` logs + no-ops (constructor-only
     * on Android); `handleUniversalLink` returns `false`; four
     * `success(null)` / null-tolerant stubs cover the no-SDK-API cases
     * (`getRemoteConfig`, `getDetectedJurisdiction`, `trackEvent`,
     * `resetMigrateTipState`); `fetchTransactionHistory` returns
     * `not_implemented` until the SDK lands its typed
     * CheckoutTransaction model. Same allocation pattern as
     * F8/F9/F10/F11/F12/F13/F15.
     */
    private lateinit var miscHandler: MiscHandler

    /**
     * F17 handle-resolution handler. Owns the two `resolveXxxHandle`
     * methods on the main channel. `resolveOfferManagerHandle` allocates a
     * fresh registry entry, starts an [OfferManagerHandleBridge] to wire
     * the per-handle method + state channels, and returns the id as a
     * String (matching iOS's `UUID().uuidString`).
     * `resolveMigrationManagerHandle` returns `not_implemented` — Android's
     * SDK folds migration into OfferManager. Same allocation pattern as
     * F8/F9/F10/F11/F12/F13/F15/F16. Holds a reference to
     * [offerManagerRegistry] in addition to the shared deps because the
     * registry is plugin-singleton, not per-handler.
     */
    private lateinit var handleResolutionHandler: HandleResolutionHandler

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
        purchaseHandler = PurchaseHandler(handlerDeps)
        pendingClaimsHandler = PendingClaimsHandler(handlerDeps)
        subscriptionMgmtHandler = SubscriptionMgmtHandler(handlerDeps)
        modalsHandler = ModalsHandler(handlerDeps)
        applePayStubsHandler = ApplePayStubsHandler(handlerDeps)
        miscHandler = MiscHandler(handlerDeps)

        // OfferManager registry (F18) — per-handle channel allocator.
        // Built before F17's handler because F17 needs a reference to it.
        offerManagerRegistry = OfferManagerHandleRegistry(messenger)

        // F17 handle-resolution handler — depends on the registry, so it's
        // constructed after `offerManagerRegistry` is in scope.
        handleResolutionHandler = HandleResolutionHandler(handlerDeps, offerManagerRegistry)

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
            "Android plugin attached (F8-F13 + F15-F17 handlers wired; all per-domain handlers landed)"
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
        // otherwise — fall through to the next handler if no handler claims
        // the call. F8 owns identity, F9 owns catalog + entitlements, F10
        // owns purchase + payment sheet, F11 owns pending claims, F12 owns
        // subscription mgmt, F13 owns modal launches + upgrade-offer fetch,
        // F15 owns the iOS Apple-Pay stubs, F16 owns the misc grab-bag
        // (universal link, remote config, jurisdiction, pending checkout,
        // base url, tracking, transaction history), F17 owns the headless
        // handle-resolution methods.
        //
        // After F17 landed, every method Dart calls on the main channel
        // has a real handler (or a sensible stub). Unknown methods fall
        // through to `result.notImplemented()` below.
        //
        // `presentSaveTheSaleSheet` is iOS-only per user direction and is NOT
        // owned by any handler — it falls through to `notImplemented()` below.
        if (identityHandler.handle(call, result)) return
        if (catalogHandler.handle(call, result)) return
        if (purchaseHandler.handle(call, result)) return
        if (pendingClaimsHandler.handle(call, result)) return
        if (subscriptionMgmtHandler.handle(call, result)) return
        if (modalsHandler.handle(call, result)) return
        if (applePayStubsHandler.handle(call, result)) return
        if (miscHandler.handle(call, result)) return
        if (handleResolutionHandler.handle(call, result)) return

        result.notImplemented()
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
