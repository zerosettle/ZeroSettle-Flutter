package com.zerosettle.flutter

import android.app.Activity
import android.content.Context
import android.util.Log
import com.zerosettle.flutter.ext.toFlutterMap
import com.zerosettle.flutter.handlers.ApplePayStubsHandler
import com.zerosettle.flutter.handlers.CatalogHandler
import com.zerosettle.flutter.handlers.HandleResolutionHandler
import com.zerosettle.flutter.handlers.HandlerDependencies
import com.zerosettle.flutter.handlers.IdentityHandler
import com.zerosettle.flutter.handlers.MiscHandler
import com.zerosettle.flutter.handlers.ModalsHandler
import com.zerosettle.flutter.handlers.PendingActionsHandler
import com.zerosettle.flutter.handlers.PendingClaimsHandler
import com.zerosettle.flutter.handlers.PurchaseHandler
import com.zerosettle.flutter.handlers.SubscriptionMgmtHandler
import com.zerosettle.flutter.offermanager.OfferManagerHandleRegistry
import com.zerosettle.flutter.offermanager.OfferManagerStaticHandler
import com.zerosettle.flutter.platformviews.MigrateTipViewFactory
import com.zerosettle.flutter.platformviews.OfferTipFactory
import com.zerosettle.flutter.platformviews.PendingActionBannerFactory
import com.zerosettle.sdk.ZeroSettle
import com.zerosettle.sdk.core.ZeroSettleEvent
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
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

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
 *     `presentCancelFlow` returns `not_implemented` (save-the-sale modal
 *     is iOS-only forever); `presentUpgradeOffer` returns `not_implemented`
 *     and points adopters at the Unified Offer System (OfferManager +
 *     MigrationTipView) — the imperative API is being deprecated
 *     platform-wide; `fetchUpgradeOfferConfig` forwards to the SDK
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
    private lateinit var isUcbEnabledEventChannel: EventChannel
    // Task 5 — pending-actions EventChannel (Android-only; iOS emits [] once).
    private lateinit var pendingActionsEventChannel: EventChannel
    // Task 11 — SDK analytics/lifecycle events EventChannel.
    private lateinit var eventsEventChannel: EventChannel

    /**
     * Reactive state channels (Gap 5). Each one mirrors a public SDK
     * [StateFlow] onto Dart so callers don't have to poll. All four carry
     * *current state* (not discrete events), so they use replay-on-onListen
     * to deliver the latest cached value to late subscribers.
     */
    private lateinit var productsEventChannel: EventChannel
    private lateinit var currentUserIdEventChannel: EventChannel
    private lateinit var pendingCheckoutEventChannel: EventChannel
    private lateinit var isBootstrappedEventChannel: EventChannel

    /**
     * Buffered EventChannel sinks. F25 publishes into these from SDK Flow
     * collectors; the buffered-sink pattern lets the plugin emit without
     * juggling onListen/onCancel lifecycle from each emit site.
     *
     * **Replay semantics differ per channel:**
     *
     *   - `entitlement_updates` / `pending_claims_updates` carry **current
     *     state** (StateFlow snapshots). A late Dart subscriber should see
     *     the current value immediately — `replayLatest = true`.
     *   - `checkout_events` carries **discrete lifecycle events**
     *     (begin/complete/cancel/fail). Replaying a stale
     *     `checkoutDidComplete` on reattach would falsely trigger Dart's
     *     post-purchase handling — `replayLatest = false` (matches iOS,
     *     whose `CheckoutStreamHandler` has no `onListenStarted`).
     *   - `apple_pay_state_updates` is iOS-only — the channel exists for
     *     Dart-side subscription parity but the Android sink never emits
     *     at all. Flag is irrelevant; defaults to `true`.
     */
    internal val entitlementStreamHandler = BufferedStreamHandler(replayLatest = true)
    internal val checkoutStreamHandler = BufferedStreamHandler(replayLatest = false)
    internal val pendingClaimsStreamHandler = BufferedStreamHandler(replayLatest = true)
    internal val applePayStateStreamHandler = BufferedStreamHandler(replayLatest = true)
    internal val isUcbEnabledStreamHandler = BufferedStreamHandler(replayLatest = true)
    // Task 5 — pending-actions state channel (replayLatest so late subscribers
    // see the current list immediately, matching the entitlements pattern).
    internal val pendingActionsStreamHandler = BufferedStreamHandler(replayLatest = true)

    // Task 11 — SDK analytics/lifecycle events. Events are discrete — do NOT
    // replay a stale purchaseSucceeded to a late subscriber. replayLatest=false
    // matches the checkout_events pattern and iOS's discrete-event channels.
    internal val eventsStreamHandler = BufferedStreamHandler(replayLatest = false)

    /**
     * Reactive state channels (Gap 5). All four mirror SDK StateFlows
     * (`products`, `currentUserId`, `pendingCheckout`, `isBootstrapped`)
     * onto Dart. Late subscribers get the most recent value via
     * `replayLatest = true` — same pattern as `entitlement_updates`.
     */
    internal val productsStreamHandler = BufferedStreamHandler(replayLatest = true)
    internal val currentUserIdStreamHandler = BufferedStreamHandler(replayLatest = true)
    internal val pendingCheckoutStreamHandler = BufferedStreamHandler(replayLatest = true)
    internal val isBootstrappedStreamHandler = BufferedStreamHandler(replayLatest = true)

    /** Per-handle OfferManager registry (F18). Allocated on engine attach. */
    internal lateinit var offerManagerRegistry: OfferManagerHandleRegistry

    /**
     * F25 — collectors that pump SDK [StateFlow]s onto buffered EventChannel
     * sinks. Tracked so [onDetachedFromEngine] can cancel them ahead of
     * `pluginScope.cancel()` (the scope cancellation tears them down anyway;
     * the explicit handles make ownership obvious and let tests assert the
     * pumps are alive after attach).
     *
     * `apple_pay_state_updates` has no collector — Apple Pay availability is
     * an iOS-only concept (see [ApplePayStubsHandler]); the channel is wired
     * solely so Dart `EventChannel.receiveBroadcastStream()` doesn't fail
     * with MissingPluginException on Android.
     *
     * `checkout_events` also has no collector here — it's driven by the
     * [PurchaseHandler] fabrication path documented in
     * `ext/EventToFlutterMap.kt` (the Android SDK's `PurchaseSucceeded`
     * event carries only `productId + transactionId`, but iOS's
     * `checkoutDidComplete` wire shape carries the full hydrated
     * [com.zerosettle.sdk.models.CheckoutTransaction]; fabrication from the
     * handler's `Result<CheckoutTransaction>` context avoids an extra
     * server round-trip).
     */
    @Volatile private var entitlementPumpJob: Job? = null
    @Volatile private var pendingClaimsPumpJob: Job? = null

    /**
     * Gap 5 — reactive-state pumps for the four new channels. Cancelled
     * on engine detach alongside the F25 pumps.
     */
    @Volatile private var productsPumpJob: Job? = null
    @Volatile private var currentUserIdPumpJob: Job? = null
    @Volatile private var pendingCheckoutPumpJob: Job? = null
    @Volatile private var isBootstrappedPumpJob: Job? = null

    /** UCB — pump for `is_ucb_enabled_updates`. */
    @Volatile private var isUcbEnabledPumpJob: Job? = null

    /** Task 5 — pump for `pending_actions_updates`. */
    @Volatile private var pendingActionsPumpJob: Job? = null

    /** Task 11 — collector for `ZeroSettle.events` SharedFlow. */
    @Volatile private var eventsCollectorJob: Job? = null

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
     * Task 5 pending-actions handler. Owns `getPendingActions` (synchronous
     * StateFlow snapshot) and `dismissPendingAction` (suspending SDK call
     * via the String-overload at ZeroSettle.kt:1250). Same allocation
     * pattern as F8/F9/F10/F11.
     */
    private lateinit var pendingActionsHandler: PendingActionsHandler

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
     * channel — `presentCancelFlow` returns `not_implemented` (save-the-sale
     * modal is iOS-only forever); `presentUpgradeOffer` returns
     * `not_implemented` and directs adopters at the Unified Offer System
     * (OfferManager + MigrationTipView) — the imperative API is being
     * deprecated; `fetchUpgradeOfferConfig` forwards to the SDK. Same
     * allocation pattern as F8/F9/F10/F11/F12.
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
        // Gap 5 — reactive state channels.
        productsEventChannel = EventChannel(messenger, "zerosettle/products_updates").apply {
            setStreamHandler(productsStreamHandler)
        }
        currentUserIdEventChannel = EventChannel(messenger, "zerosettle/current_user_id_updates").apply {
            setStreamHandler(currentUserIdStreamHandler)
        }
        pendingCheckoutEventChannel = EventChannel(messenger, "zerosettle/pending_checkout_updates").apply {
            setStreamHandler(pendingCheckoutStreamHandler)
        }
        isBootstrappedEventChannel = EventChannel(messenger, "zerosettle/is_bootstrapped_updates").apply {
            setStreamHandler(isBootstrappedStreamHandler)
        }
        isUcbEnabledEventChannel = EventChannel(messenger, "zerosettle/is_ucb_enabled_updates").apply {
            setStreamHandler(isUcbEnabledStreamHandler)
        }
        // Task 5 — pending-actions EventChannel.
        pendingActionsEventChannel = EventChannel(messenger, "zerosettle/pending_actions_updates").apply {
            setStreamHandler(pendingActionsStreamHandler)
        }
        // Task 11 — SDK analytics/lifecycle events EventChannel. Events are
        // discrete (not state snapshots), so replayLatest=false on the handler.
        eventsEventChannel = EventChannel(messenger, "zerosettle/events").apply {
            setStreamHandler(eventsStreamHandler)
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
            // F25 — PurchaseHandler fabricates checkoutDid{Begin,Complete,
            // Cancel,Fail} events at lifecycle points; this seam routes them
            // through the buffered stream handler's emit(). Tests pass a
            // capturing lambda instead.
            checkoutEventEmitter = checkoutStreamHandler::emit,
        )
        identityHandler = IdentityHandler(handlerDeps)
        catalogHandler = CatalogHandler(handlerDeps)
        purchaseHandler = PurchaseHandler(handlerDeps)
        pendingClaimsHandler = PendingClaimsHandler(handlerDeps)
        pendingActionsHandler = PendingActionsHandler(handlerDeps)
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

        // F25 — pump SDK StateFlows onto buffered EventChannel sinks. Each
        // pump runs for the engine's lifetime; pluginScope.cancel() in
        // onDetachedFromEngine tears them down. StateFlow's behaviour is
        // "replay-latest on collect", so the initial empty list is consumed
        // immediately and cached on the BufferedStreamHandler — late Dart
        // subscribers see it on attach via the handler's replay-on-onListen
        // path. Wire shapes mirror iOS:
        //   entitlement_updates: List<Map>, each via Entitlement.toFlutterMap()
        //   pending_claims_updates: List<Map>, each via PendingClaim.toFlutterMap()
        entitlementPumpJob = pumpStateFlow(
            pluginScope,
            ZeroSettle.entitlements,
            entitlementStreamHandler,
        ) { list -> list.map { it.toFlutterMap() } }
        pendingClaimsPumpJob = pumpStateFlow(
            pluginScope,
            ZeroSettle.pendingClaims,
            pendingClaimsStreamHandler,
        ) { list -> list.map { it.toFlutterMap() } }
        // Gap 5 pumps.
        //   products_updates       : List<Map> (Product.toFlutterMap)
        //   current_user_id_updates: String? — emits null on logout to mirror
        //                            the SDK's StateFlow<String?> semantics.
        //                            BufferedStreamHandler.emit on Kotlin
        //                            forbids null, so we route through
        //                            pumpNullableStateFlow which converts
        //                            null → the sentinel below.
        //   pending_checkout_updates : Boolean
        //   is_bootstrapped_updates  : Boolean
        productsPumpJob = pumpStateFlow(
            pluginScope,
            ZeroSettle.products,
            productsStreamHandler,
        ) { list -> list.map { it.toFlutterMap() } }
        currentUserIdPumpJob = pumpNullableStateFlow(
            pluginScope,
            ZeroSettle.currentUserId,
            currentUserIdStreamHandler,
        )
        pendingCheckoutPumpJob = pumpStateFlow(
            pluginScope,
            ZeroSettle.pendingCheckout,
            pendingCheckoutStreamHandler,
        ) { it }
        isBootstrappedPumpJob = pumpStateFlow(
            pluginScope,
            ZeroSettle.isBootstrapped,
            isBootstrappedStreamHandler,
        ) { it }
        // UCB — pump `ZeroSettle.isUcbEnabled` (StateFlow<Boolean>) onto Dart.
        isUcbEnabledPumpJob = pumpStateFlow(
            pluginScope,
            ZeroSettle.isUcbEnabled,
            isUcbEnabledStreamHandler,
        ) { it }
        // Task 5 — pump `ZeroSettle.pendingActions` onto Dart.
        pendingActionsPumpJob = pumpStateFlow(
            pluginScope,
            ZeroSettle.pendingActions,
            pendingActionsStreamHandler,
        ) { list -> list.map { it.toFlutterMap() } }
        // Task 11 — collect `ZeroSettle.events` (SharedFlow — NOT StateFlow)
        // and forward each event to the Dart stream. Must collect directly
        // (not via pumpStateFlow) because SharedFlow has no `value` property.
        // replayLatest=false on the handler matches the discrete-event semantics.
        eventsCollectorJob = pluginScope.launch {
            ZeroSettle.events.collect { event ->
                eventsStreamHandler.emit(event.toFlutterMap())
            }
        }

        Log.i(
            "ZeroSettle",
            "Android plugin attached (F8-F13 + F15-F17 handlers wired; F25 pumps live; all per-domain handlers landed)"
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
        // Gap 5 channels.
        productsEventChannel.setStreamHandler(null)
        currentUserIdEventChannel.setStreamHandler(null)
        pendingCheckoutEventChannel.setStreamHandler(null)
        isBootstrappedEventChannel.setStreamHandler(null)
        isUcbEnabledEventChannel.setStreamHandler(null)
        pendingActionsEventChannel.setStreamHandler(null)
        eventsEventChannel.setStreamHandler(null)
        // F25 + Gap 5 pump jobs — `pluginScope.cancel()` below would tear
        // them down anyway, but explicit cancellation makes ownership
        // obvious.
        entitlementPumpJob?.cancel()
        pendingClaimsPumpJob?.cancel()
        productsPumpJob?.cancel()
        currentUserIdPumpJob?.cancel()
        pendingCheckoutPumpJob?.cancel()
        isBootstrappedPumpJob?.cancel()
        isUcbEnabledPumpJob?.cancel()
        pendingActionsPumpJob?.cancel()
        eventsCollectorJob?.cancel()
        entitlementPumpJob = null
        pendingClaimsPumpJob = null
        productsPumpJob = null
        currentUserIdPumpJob = null
        pendingCheckoutPumpJob = null
        isBootstrappedPumpJob = null
        isUcbEnabledPumpJob = null
        pendingActionsPumpJob = null
        eventsCollectorJob = null
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
        if (pendingActionsHandler.handle(call, result)) return
        if (subscriptionMgmtHandler.handle(call, result)) return
        if (modalsHandler.handle(call, result)) return
        if (applePayStubsHandler.handle(call, result)) return
        if (miscHandler.handle(call, result)) return
        if (handleResolutionHandler.handle(call, result)) return

        result.notImplemented()
    }
}

/**
 * F25 — launch a collector that pumps [source]'s emissions through
 * [encode] and onto [sink]'s buffered channel. Returns the [Job] so callers
 * can cancel ahead of scope teardown (and so tests can drive the collector
 * deterministically by passing an `UnconfinedTestDispatcher`-backed scope).
 *
 * Factored as a top-level internal function so the entitlements +
 * pendingClaims pumps share the same collect-and-encode shape, and unit
 * tests can exercise the pump against a `MutableStateFlow` + a fake
 * [BufferedStreamHandler] without standing up the full plugin lifecycle.
 *
 * @param scope    plugin coroutine scope; pump lives for its lifetime.
 * @param source   SDK [StateFlow] to subscribe to.
 * @param sink     buffered sink that buffers the latest emission for replay.
 * @param encode   maps each emission to the wire shape (typically
 *                 `List<Map<String, Any?>>` matching iOS exactly).
 */
internal fun <T> pumpStateFlow(
    scope: CoroutineScope,
    source: StateFlow<T>,
    sink: BufferedStreamHandler,
    encode: (T) -> Any,
): Job = scope.launch {
    source.collect { value -> sink.emit(encode(value)) }
}

/**
 * Gap 5 — variant of [pumpStateFlow] that emits the underlying value (or
 * null) directly to the sink. Used for `current_user_id_updates`
 * specifically: the Android SDK's [ZeroSettle.currentUserId] is
 * `StateFlow<String?>`, and Dart wants to see `null` on logout so it can
 * route to the signed-out UI. The standard [pumpStateFlow] requires the
 * encode lambda to return `Any` (non-null), so we factor out the nullable
 * case rather than weakening that contract for every channel.
 */
internal fun pumpNullableStateFlow(
    scope: CoroutineScope,
    source: StateFlow<String?>,
    sink: BufferedStreamHandler,
): Job = scope.launch {
    source.collect { value -> sink.emit(value) }
}

/**
 * Generic [EventChannel.StreamHandler] that buffers the active sink and,
 * for [replayLatest] = `true` channels, the most recent emission too.
 *
 * **The buffer.** The plugin can emit from coroutines without juggling
 * onListen/onCancel lifecycle from each emit site — writes go to `sink` if
 * attached, no-op otherwise.
 *
 * **Replay-on-onListen** (when [replayLatest] is `true`): without this, a
 * `StateFlow.collect` collector launched in `onAttachedToEngine` consumes
 * the current value before any Dart listener attaches — that emission has
 * nowhere to go (`sink == null`), so it's dropped. The next time Dart
 * attaches, it waits for a *new* mutation before seeing anything. iOS
 * sidesteps this via per-handler `onListenStarted` callbacks that re-read
 * `ZeroSettle.shared.<stateflow>` on attach; the buffered variant achieves
 * the same parity by caching the last [emit] and replaying it on [onListen].
 *
 * **When NOT to replay** (when [replayLatest] is `false`): channels that
 * carry *discrete lifecycle events* — like `checkout_events`
 * (`checkoutDid{Begin,Complete,Cancel,Fail}`) — must NOT replay. Replaying
 * a stale `checkoutDidComplete` on reattach would falsely trigger Dart's
 * post-purchase handling (double-grant, duplicate analytics, etc.).
 * Matches iOS's `CheckoutStreamHandler` (no `onListenStarted`). The
 * emission is still cached for symmetry, but never surfaced to a fresh sink.
 *
 * `@Volatile` because both fields are written from the main thread by the
 * Flutter framework (onListen / onCancel callbacks) and read from arbitrary
 * coroutine dispatchers in the F25 pumps and PurchaseHandler emit sites.
 *
 * @param replayLatest whether [onListen] should replay the most recent
 *   [emit] to a fresh sink. `true` for StateFlow/state channels;
 *   `false` for discrete event channels.
 */
internal class BufferedStreamHandler(
    private val replayLatest: Boolean = true,
) : EventChannel.StreamHandler {
    @Volatile
    var sink: EventChannel.EventSink? = null
        private set

    /**
     * Last value pushed via [emit]. May legitimately be `null` (e.g.
     * `current_user_id_updates` after logout) — [hasEmitted] is the source
     * of truth for "has the pump produced anything yet?". Both fields are
     * written together inside [emit].
     */
    @Volatile
    private var lastEmit: Any? = null

    @Volatile
    private var hasEmitted: Boolean = false

    /**
     * Push [value] to the current sink (if attached) and remember it for
     * possible replay on the next [onListen]. Safe to call from any thread.
     * Null is a legal value — channels with non-null wire shapes simply
     * never call this with `null`.
     */
    fun emit(value: Any?) {
        lastEmit = value
        hasEmitted = true
        sink?.success(value)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        // Replay the most recent emission only for state-snapshot channels.
        // Discrete event channels (replayLatest=false) match iOS's no-replay
        // behaviour to avoid duplicate post-purchase processing on Dart.
        // Using `hasEmitted` (not `lastEmit != null`) so a cached `null`
        // — e.g. `currentUserId` after logout — replays through to late
        // subscribers.
        if (replayLatest && hasEmitted) {
            events?.success(lastEmit)
        }
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }
}
