import Flutter
import UIKit
import ZeroSettleKit
import SwiftUI
import Combine
import StoreKit

/// Holds the per-handle Combine subscriptions and method-channel + event-
/// channel handlers that bridge a single `ZSMigrationManager` instance to
/// Flutter. Released when Dart calls `disposeHandle`.
private final class MigrationManagerHandleEntry: NSObject {
    let manager: ZSMigrationManager
    let methodChannel: FlutterMethodChannel
    let stateChannel: FlutterEventChannel
    let failuresChannel: FlutterEventChannel
    var stateSink: FlutterEventSink?
    var failuresSink: FlutterEventSink?
    var cancellables: Set<AnyCancellable> = []

    init(
        manager: ZSMigrationManager,
        methodChannel: FlutterMethodChannel,
        stateChannel: FlutterEventChannel,
        failuresChannel: FlutterEventChannel
    ) {
        self.manager = manager
        self.methodChannel = methodChannel
        self.stateChannel = stateChannel
        self.failuresChannel = failuresChannel
    }
}

/// Holds the per-handle Combine subscriptions and method-channel + event-
/// channel handlers that bridge a single `ZSOfferManager` instance to
/// Flutter. Released when Dart calls `disposeHandle`.
///
/// Unlike `MigrationManagerHandleEntry`, there is no failures channel —
/// `ZSOfferManager` has no `onCheckoutFailure` closure callback. Errors
/// surface via the state stream's `checkoutErrorMessage` field.
private final class OfferManagerHandleEntry: NSObject {
    let manager: ZSOfferManager
    let methodChannel: FlutterMethodChannel
    let stateChannel: FlutterEventChannel
    var stateSink: FlutterEventSink?
    var cancellables: Set<AnyCancellable> = []

    init(
        manager: ZSOfferManager,
        methodChannel: FlutterMethodChannel,
        stateChannel: FlutterEventChannel
    ) {
        self.manager = manager
        self.methodChannel = methodChannel
        self.stateChannel = stateChannel
    }
}

public class ZeroSettlePlugin: NSObject, FlutterPlugin, FlutterApplicationLifeCycleDelegate {

    private var methodChannel: FlutterMethodChannel?
    private var entitlementEventChannel: FlutterEventChannel?
    private var checkoutEventChannel: FlutterEventChannel?
    private var pendingClaimsEventChannel: FlutterEventChannel?
    private var applePayStateEventChannel: FlutterEventChannel?
    // Gap 5 — reactive state channels mirroring SDK observable properties.
    private var productsEventChannel: FlutterEventChannel?
    private var currentUserIdEventChannel: FlutterEventChannel?
    private var pendingCheckoutEventChannel: FlutterEventChannel?
    private var isBootstrappedEventChannel: FlutterEventChannel?
    // UCB — always-false stub channel (UCB is Android/Play only).
    private var isUcbEnabledEventChannel: FlutterEventChannel?
    // Pending Actions — Android/Play only; iOS emits [] once on subscribe.
    private var pendingActionsEventChannel: FlutterEventChannel?
    // Task 12 — SDK analytics/lifecycle events stream (shared channel name with Android).
    private var eventsEventChannel: FlutterEventChannel?

    /// Captured at `register(with:)` time so per-handle channels (built on
    /// demand inside `installMigrationHandle`) can attach without re-routing
    /// through the registrar.
    private var messenger: FlutterBinaryMessenger?

    /// (handleId → entry). One entry per Dart `MigrationManager` lifetime.
    /// Cleared on `disposeHandle` from Dart.
    private var migrationHandles: [String: MigrationManagerHandleEntry] = [:]

    /// (handleId → entry). One entry per Dart `OfferManager` lifetime.
    /// Cleared on `disposeHandle` from Dart.
    private var offerHandles: [String: OfferManagerHandleEntry] = [:]

    private let entitlementStreamHandler = EntitlementStreamHandler()
    private let checkoutStreamHandler = CheckoutStreamHandler()
    private let pendingClaimsStreamHandler = PendingClaimsStreamHandler()
    private let applePayStateStreamHandler = ApplePayStateStreamHandler()
    // Gap 5 — reactive state stream handlers. All four cache the latest
    // emission so late Dart subscribers see the current value on attach.
    private let productsStreamHandler = ReactiveStateStreamHandler()
    private let currentUserIdStreamHandler = ReactiveStateStreamHandler()
    private let pendingCheckoutStreamHandler = ReactiveStateStreamHandler()
    private let isBootstrappedStreamHandler = ReactiveStateStreamHandler()
    // UCB — one-shot false stub (UCB is Android/Play only; iOS emits false on subscribe).
    private let isUcbEnabledStreamHandler = OneShotBoolStreamHandler(value: false)
    // Pending Actions — one-shot empty-list stub (Android/Play only; iOS emits [] on subscribe).
    private let pendingActionsStreamHandler = OneShotEmptyListStreamHandler()
    // Task 12 — discrete events stream handler. No replay (replayLatest = false on Android).
    private let eventsStreamHandler = EventsStreamHandler()

    /// Combine subscription that fires on `ZeroSettle.shared.objectWillChange`
    /// to mirror the three Observable-backed state properties (`products`,
    /// `pendingCheckout`, `isBootstrapped`) onto Dart. We dedupe each
    /// channel's value separately to avoid spamming Dart when an unrelated
    /// observable property changes (objectWillChange fires for ANY mutation
    /// on the shared singleton).
    private var observableStateCancellable: AnyCancellable?
    private var lastProductsSnapshot: [[String: Any]] = []
    private var lastPendingCheckout: Bool?
    private var lastIsBootstrapped: Bool?

    /// Gap 5 — emit the current `cachedCurrentUserId` on the
    /// `current_user_id_updates` channel. Called from every site that
    /// mutates `cachedCurrentUserId` (identify success, logout, bootstrap
    /// success). `nil` is sent as `NSNull()` so Dart sees an explicit
    /// logged-out event.
    fileprivate func pushCurrentUserIdUpdate() {
        currentUserIdStreamHandler.send(cachedCurrentUserId ?? NSNull())
    }

    /// Combine subscription that mirrors
    /// `ZeroSettle.shared.applePayAvailability.statePublisher` onto the
    /// `apple_pay_state_updates` event channel. Subscribed once at register()
    /// time so late Dart subscribers receive the current state on attach.
    private var applePayStateCancellable: AnyCancellable?

    /// Combine subscription that mirrors `ZeroSettle.shared.pendingClaims`
    /// changes onto the `pending_claims_updates` event channel. The iOS Kit
    /// fires `objectWillChange.send()` before each mutation; we re-read on
    /// the next runloop tick to capture the post-mutation value, then dedupe.
    private var pendingClaimsCancellable: AnyCancellable?
    private var lastPendingClaimsSnapshot: [[String: Any]] = []

    /// Plugin-side cache of the user ID passed to the most recent
    /// `identify(.user)` or `bootstrap()` call. Mirrors what the iOS Kit
    /// stores in its `internal var currentUserId` — which we can't read
    /// across module boundaries — so we shadow it here. Cleared on
    /// `logout()` and on `identify(.anonymous|.deferred)`.
    private var cachedCurrentUserId: String?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "zerosettle", binaryMessenger: registrar.messenger())
        let instance = ZeroSettlePlugin()
        instance.methodChannel = channel
        instance.messenger = registrar.messenger()

        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addApplicationDelegate(instance)

        let entitlementEC = FlutterEventChannel(name: "zerosettle/entitlement_updates", binaryMessenger: registrar.messenger())
        entitlementEC.setStreamHandler(instance.entitlementStreamHandler)
        instance.entitlementEventChannel = entitlementEC

        let checkoutEC = FlutterEventChannel(name: "zerosettle/checkout_events", binaryMessenger: registrar.messenger())
        checkoutEC.setStreamHandler(instance.checkoutStreamHandler)
        instance.checkoutEventChannel = checkoutEC

        let pendingClaimsEC = FlutterEventChannel(name: "zerosettle/pending_claims_updates", binaryMessenger: registrar.messenger())
        pendingClaimsEC.setStreamHandler(instance.pendingClaimsStreamHandler)
        instance.pendingClaimsEventChannel = pendingClaimsEC

        let applePayStateEC = FlutterEventChannel(name: "zerosettle/apple_pay_state_updates", binaryMessenger: registrar.messenger())
        applePayStateEC.setStreamHandler(instance.applePayStateStreamHandler)
        instance.applePayStateEventChannel = applePayStateEC

        // Gap 5 — reactive state event channels. Each carries the latest
        // value of an SDK Observable / shadowed property.
        let productsEC = FlutterEventChannel(name: "zerosettle/products_updates", binaryMessenger: registrar.messenger())
        productsEC.setStreamHandler(instance.productsStreamHandler)
        instance.productsEventChannel = productsEC

        let currentUserIdEC = FlutterEventChannel(name: "zerosettle/current_user_id_updates", binaryMessenger: registrar.messenger())
        currentUserIdEC.setStreamHandler(instance.currentUserIdStreamHandler)
        instance.currentUserIdEventChannel = currentUserIdEC

        let pendingCheckoutEC = FlutterEventChannel(name: "zerosettle/pending_checkout_updates", binaryMessenger: registrar.messenger())
        pendingCheckoutEC.setStreamHandler(instance.pendingCheckoutStreamHandler)
        instance.pendingCheckoutEventChannel = pendingCheckoutEC

        let isBootstrappedEC = FlutterEventChannel(name: "zerosettle/is_bootstrapped_updates", binaryMessenger: registrar.messenger())
        isBootstrappedEC.setStreamHandler(instance.isBootstrappedStreamHandler)
        instance.isBootstrappedEventChannel = isBootstrappedEC

        // UCB — one-shot false stub (UCB is Android/Play only).
        let isUcbEnabledEC = FlutterEventChannel(name: "zerosettle/is_ucb_enabled_updates", binaryMessenger: registrar.messenger())
        isUcbEnabledEC.setStreamHandler(instance.isUcbEnabledStreamHandler)
        instance.isUcbEnabledEventChannel = isUcbEnabledEC

        // Pending Actions — one-shot empty-list stub (Android/Play only).
        let pendingActionsEC = FlutterEventChannel(name: "zerosettle/pending_actions_updates", binaryMessenger: registrar.messenger())
        pendingActionsEC.setStreamHandler(instance.pendingActionsStreamHandler)
        instance.pendingActionsEventChannel = pendingActionsEC

        // Task 12 — SDK analytics/lifecycle events stream. Discrete (no replay on subscribe).
        // iOS emits a subset translatable from ZeroSettleDelegate callbacks:
        //   purchaseSucceeded, purchaseFailed, entitlementsRefreshed, syncFailed.
        // Android-only events (offerShown/Accepted/Dismissed, offerEvaluationFailed,
        //   migrationCompleted, pendingActionShown) are not emitted on iOS — they have
        //   no corresponding delegate callback surface in ZeroSettleKit.
        let eventsEC = FlutterEventChannel(name: "zerosettle/events", binaryMessenger: registrar.messenger())
        eventsEC.setStreamHandler(instance.eventsStreamHandler)
        instance.eventsEventChannel = eventsEC

        // Gap 5 — push initial state to late subscribers via onListenStarted,
        // matching the pendingClaims pattern. `products` / `pendingCheckout` /
        // `isBootstrapped` are public @Observable properties on
        // ZeroSettle.shared; we read them directly. `currentUserId` is
        // `internal private(set)` on the Kit — we shadow it as
        // `cachedCurrentUserId` and emit that value.
        instance.productsStreamHandler.onListenStarted = { [weak instance] in
            DispatchQueue.main.async {
                guard let instance else { return }
                MainActor.assumeIsolated {
                    let current = ZeroSettle.shared.products.map { $0.toFlutterMap() }
                    instance.lastProductsSnapshot = current
                    instance.productsStreamHandler.send(current)
                }
            }
        }
        instance.currentUserIdStreamHandler.onListenStarted = { [weak instance] in
            DispatchQueue.main.async {
                guard let instance else { return }
                // cachedCurrentUserId is plugin-side state, written from
                // `Task { @MainActor in ... }` blocks. We're on the main
                // queue here so `MainActor.assumeIsolated` makes the access
                // explicit (matches the surrounding pendingClaims / Apple
                // Pay state blocks for consistency).
                MainActor.assumeIsolated {
                    // cachedCurrentUserId may be nil — send NSNull so the Dart
                    // wire sees an explicit `null` event for the logged-out state.
                    instance.currentUserIdStreamHandler.send(instance.cachedCurrentUserId ?? NSNull())
                }
            }
        }
        instance.pendingCheckoutStreamHandler.onListenStarted = { [weak instance] in
            DispatchQueue.main.async {
                guard let instance else { return }
                MainActor.assumeIsolated {
                    let value = ZeroSettle.shared.pendingCheckout
                    instance.lastPendingCheckout = value
                    instance.pendingCheckoutStreamHandler.send(value)
                }
            }
        }
        instance.isBootstrappedStreamHandler.onListenStarted = { [weak instance] in
            DispatchQueue.main.async {
                guard let instance else { return }
                MainActor.assumeIsolated {
                    let value = ZeroSettle.shared.isBootstrapped
                    instance.lastIsBootstrapped = value
                    instance.isBootstrappedStreamHandler.send(value)
                }
            }
        }

        // Gap 5 — subscribe once to ZeroSettle.shared.objectWillChange and
        // re-read the three Observable properties on the next runloop tick
        // (post-mutation). Per-channel dedupe avoids spamming Dart when an
        // unrelated property changes — `objectWillChange` is a singleton-wide
        // signal. `currentUserId` is NOT driven from here; it's pushed from
        // the identify/logout method sites where `cachedCurrentUserId`
        // already mutates (see pushCurrentUserIdUpdate(_:)).
        Task { @MainActor in
            instance.observableStateCancellable = ZeroSettle.shared.objectWillChange
                .sink { [weak instance] _ in
                    DispatchQueue.main.async {
                        guard let instance else { return }
                        MainActor.assumeIsolated {
                            // products
                            let nextProducts = ZeroSettle.shared.products.map { $0.toFlutterMap() }
                            if !productsSnapshotsEqual(instance.lastProductsSnapshot, nextProducts) {
                                instance.lastProductsSnapshot = nextProducts
                                instance.productsStreamHandler.send(nextProducts)
                            }
                            // pendingCheckout
                            let nextPendingCheckout = ZeroSettle.shared.pendingCheckout
                            if instance.lastPendingCheckout != nextPendingCheckout {
                                instance.lastPendingCheckout = nextPendingCheckout
                                instance.pendingCheckoutStreamHandler.send(nextPendingCheckout)
                            }
                            // isBootstrapped
                            let nextIsBootstrapped = ZeroSettle.shared.isBootstrapped
                            if instance.lastIsBootstrapped != nextIsBootstrapped {
                                instance.lastIsBootstrapped = nextIsBootstrapped
                                instance.isBootstrappedStreamHandler.send(nextIsBootstrapped)
                            }
                        }
                    }
                }
        }

        // Bridge ZeroSettle.shared.applePayAvailability.$state (Combine
        // @Published) onto the applePayStateStreamHandler. Push the current
        // value on listen-start so late Dart subscribers see it immediately.
        instance.applePayStateStreamHandler.onListenStarted = { [weak instance] in
            DispatchQueue.main.async {
                guard let instance else { return }
                MainActor.assumeIsolated {
                    let raw = ZeroSettle.shared.applePayAvailability.state.rawString
                    instance.applePayStateStreamHandler.send(raw)
                }
            }
        }
        Task { @MainActor in
            instance.applePayStateCancellable = ZeroSettle.shared
                .applePayAvailability
                .statePublisher
                .removeDuplicates()
                .sink { [weak instance] state in
                    instance?.applePayStateStreamHandler.send(state.rawString)
                }
        }

        // Bridge ZeroSettle.shared.pendingClaims (an ObservableObject @Published-like
        // property notified via objectWillChange) onto the pendingClaimsStreamHandler.
        // objectWillChange fires for every mutation on the shared instance, so we
        // dedupe against the previous snapshot to avoid spamming Dart.
        instance.pendingClaimsStreamHandler.onListenStarted = { [weak instance] in
            // Emit current state to late subscribers.
            DispatchQueue.main.async {
                guard let instance else { return }
                MainActor.assumeIsolated {
                    let current = ZeroSettle.shared.pendingClaims.map { $0.toFlutterMap() }
                    instance.lastPendingClaimsSnapshot = current
                    instance.pendingClaimsStreamHandler.send(current)
                }
            }
        }
        Task { @MainActor in
            instance.pendingClaimsCancellable = ZeroSettle.shared.objectWillChange
                .sink { [weak instance] _ in
                    // objectWillChange fires *before* the mutation, so read on the next
                    // runloop tick to see the post-mutation value.
                    DispatchQueue.main.async {
                        guard let instance else { return }
                        MainActor.assumeIsolated {
                            let current = ZeroSettle.shared.pendingClaims.map { $0.toFlutterMap() }
                            // Cheap structural dedupe: same count + same productId/OTID per index.
                            if pendingClaimsSnapshotsEqual(instance.lastPendingClaimsSnapshot, current) {
                                return
                            }
                            instance.lastPendingClaimsSnapshot = current
                            instance.pendingClaimsStreamHandler.send(current)
                        }
                    }
                }
        }

        // Register MigrationTipView PlatformView factory
        let migrateTipFactory = ZSMigrateTipViewFactory(messenger: registrar.messenger())
        registrar.register(migrateTipFactory, withId: "zerosettle/migrate_tip_view")

        // Static dismissed-state helpers for ZSMigrationManager. Routed
        // through a separate channel because they're not scoped to a
        // particular Dart `MigrationManager` handle — they read/write
        // UserDefaults globally / per-userId.
        let migrationStaticChannel = FlutterMethodChannel(
            name: "zerosettle/migration_manager_static",
            binaryMessenger: registrar.messenger()
        )
        migrationStaticChannel.setMethodCallHandler { call, result in
            let args = call.arguments as? [String: Any]
            switch call.method {
            case "isPermanentlyDismissed":
                guard let userId = args?["userId"] as? String else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "userId required", details: nil))
                    return
                }
                result(ZSMigrationManager.isPermanentlyDismissed(forUserId: userId))

            case "setDismissed":
                guard let userId = args?["userId"] as? String,
                      let dismissed = args?["dismissed"] as? Bool else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "userId + dismissed required", details: nil))
                    return
                }
                ZSMigrationManager.setDismissed(dismissed, forUserId: userId)
                result(nil)

            case "resetDismissedState":
                ZSMigrationManager.resetDismissedState()
                result(nil)

            default:
                result(FlutterMethodNotImplemented)
            }
        }

        // Static dismissed-state helpers for ZSOfferManager. Same shape as
        // the migration variant — UserDefaults-backed, scoped per-userId.
        let offerStaticChannel = FlutterMethodChannel(
            name: "zerosettle/offer_manager_static",
            binaryMessenger: registrar.messenger()
        )
        offerStaticChannel.setMethodCallHandler { call, result in
            let args = call.arguments as? [String: Any]
            switch call.method {
            case "isPermanentlyDismissed":
                guard let userId = args?["userId"] as? String else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "userId required", details: nil))
                    return
                }
                result(ZSOfferManager.isPermanentlyDismissed(forUserId: userId))

            case "setDismissed":
                guard let userId = args?["userId"] as? String,
                      let dismissed = args?["dismissed"] as? Bool else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "userId + dismissed required", details: nil))
                    return
                }
                ZSOfferManager.setDismissed(dismissed, forUserId: userId)
                result(nil)

            case "resetDismissedState":
                ZSOfferManager.resetDismissedState()
                result(nil)

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    // MARK: - Universal Link Handling

    public func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([Any]) -> Void
    ) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else {
            return false
        }
        return MainActor.assumeIsolated {
            ZeroSettle.shared.handleUniversalLink(url)
        }
    }

    // MARK: - Method Channel Handler

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        Task { @MainActor in
            self.handleOnMainActor(call, result: result)
        }
    }

    @MainActor
    private func handleOnMainActor(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]

        switch call.method {

        // -- Configuration --

        case "setBaseUrlOverride":
            let urlString = args?["url"] as? String
            #if DEBUG
            if let urlString, let url = URL(string: urlString) {
                ZeroSettle.baseURLOverride = url
            } else {
                ZeroSettle.baseURLOverride = nil
            }
            #endif
            result(nil)

        case "setEclAvailabilityOverride":
            // ECL (External Content Links) is a Google Play concept — there is
            // no iOS equivalent. Accept the call so Flutter callers get a clean
            // no-op rather than a MissingPluginException on iOS.
            result(nil)

        case "setSwitchAndSaveTestMode":
            // Switch & Save is the Play→web ECL migration flow — a Google Play
            // concept with no iOS equivalent. Accept the call as a clean no-op
            // so the Dart API is uniform across platforms.
            result(nil)

        case "configure":
            guard let publishableKey = args?["publishableKey"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "publishableKey is required", details: nil))
                return
            }
            let syncStoreKit = args?["syncStoreKitTransactions"] as? Bool ?? true
            let appleMerchantId = args?["appleMerchantId"] as? String
            let preloadCheckout = args?["preloadCheckout"] as? Bool ?? false
            let maxPreloadedWebViews = args?["maxPreloadedWebViews"] as? Int
            // Android-only knobs Dart still sends — read them so they don't
            // surface as "unknown argument" on stricter handlers, but drop
            // them silently because iOS Kit has no Play Billing surface.
            // Symmetric to the Android plugin's iOS-only args drop (see
            // IdentityHandler.kt's `droppedArgs` block).
            _ = args?["playLicenseKey"] as? String
            _ = args?["syncPlayPurchases"] as? Bool
            _ = args?["strictAck"] as? Bool
            // ApplePaySetupBehavior is `Sendable` without an explicit raw
            // value type, so we map strings via switch. When omitted, fall
            // through to the iOS Configuration init's default
            // (`.presentBuiltInUI`) by using the no-arg initializer path.
            let applePaySetupBehaviorRaw = args?["applePaySetupBehavior"] as? String
            let config: ZeroSettle.Configuration
            if let applePaySetupBehaviorRaw {
                guard let behavior = ApplePaySetupBehavior.fromRawString(applePaySetupBehaviorRaw) else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "unknown applePaySetupBehavior: \(applePaySetupBehaviorRaw)", details: nil))
                    return
                }
                config = ZeroSettle.Configuration(
                    publishableKey: publishableKey,
                    syncStoreKitTransactions: syncStoreKit,
                    appleMerchantId: appleMerchantId,
                    preloadCheckout: preloadCheckout,
                    maxPreloadedWebViews: maxPreloadedWebViews,
                    applePaySetupBehavior: behavior
                )
            } else {
                config = ZeroSettle.Configuration(
                    publishableKey: publishableKey,
                    syncStoreKitTransactions: syncStoreKit,
                    appleMerchantId: appleMerchantId,
                    preloadCheckout: preloadCheckout,
                    maxPreloadedWebViews: maxPreloadedWebViews
                )
            }
            ZeroSettle.shared.configure(config)
            ZeroSettle.shared.delegate = self
            result(nil)

        // -- Bootstrap --

        case "bootstrap":
            guard let userId = args?["userId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "userId is required", details: nil))
                return
            }
            Task { @MainActor in
                do {
                    let catalog = try await ZeroSettle.shared.bootstrap(userId: userId)
                    self.cachedCurrentUserId = userId
                    self.pushCurrentUserIdUpdate()
                    result(catalog.toFlutterMap())
                } catch {
                    result(error.toFlutterError())
                }
            }

        case "identify":
            guard let type = args?["type"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "type is required", details: nil))
                return
            }
            let identity: Identity
            switch type {
            case "user":
                guard let id = args?["id"] as? String else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "id is required for user identity", details: nil))
                    return
                }
                identity = .user(id: id, name: args?["name"] as? String, email: args?["email"] as? String)
            case "anonymous":
                identity = .anonymous
            case "deferred":
                identity = .deferred
            default:
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "unknown identity type: \(type)", details: nil))
                return
            }
            Task { @MainActor in
                do {
                    let catalog = try await ZeroSettle.shared.identify(identity)
                    // Mirror the Kit's internal currentUserId on the plugin
                    // side so getCurrentUserId() can return it.
                    switch identity {
                    case .user(let id, _, _):
                        self.cachedCurrentUserId = id
                    case .anonymous, .deferred:
                        self.cachedCurrentUserId = nil
                    }
                    self.pushCurrentUserIdUpdate()
                    result(catalog?.toFlutterMap())
                } catch {
                    result(error.toFlutterError())
                }
            }

        case "logout":
            Task { @MainActor in
                ZeroSettle.shared.logout()
                self.cachedCurrentUserId = nil
                self.pushCurrentUserIdUpdate()
                result(nil)
            }

        case "setCustomer":
            Task { @MainActor in
                ZeroSettle.shared.setCustomer(name: args?["name"] as? String, email: args?["email"] as? String)
                result(nil)
            }

        case "transferStoreKitOwnershipToCurrentUser":
            guard let productId = args?["productId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "productId is required", details: nil))
                return
            }
            Task { @MainActor in
                do {
                    try await ZeroSettle.shared.transferStoreKitOwnershipToCurrentUser(productId: productId)
                    result(nil)
                } catch {
                    result(error.toFlutterError())
                }
            }

        case "transferPlayOwnershipToCurrentUser":
            // Android-only — peer of `transferStoreKitOwnershipToCurrentUser`.
            // Returning a tagged `not_implemented` error (rather than the
            // generic `FlutterMethodNotImplemented` default) matches the
            // pattern used for other intentionally-unavailable methods
            // (e.g. `presentSaveTheSaleSheet`); Dart's `_wrap` rethrows
            // as a `ZeroSettleException` callers can pattern-match on.
            result(FlutterError(
                code: "not_implemented",
                message: "transferPlayOwnershipToCurrentUser is Android-only. " +
                    "On iOS, use transferStoreKitOwnershipToCurrentUser(productId).",
                details: nil
            ))

        case "hasActiveEntitlement":
            guard let productId = args?["productId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "productId is required", details: nil))
                return
            }
            Task { @MainActor in
                result(ZeroSettle.shared.hasActiveEntitlement(for: productId))
            }

        case "product":
            guard let productId = args?["productId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "productId is required", details: nil))
                return
            }
            Task { @MainActor in
                result(ZeroSettle.shared.product(for: productId)?.toFlutterMap())
            }

        // -- Products --

        case "fetchProducts":
            let userId = args?["userId"] as? String
            Task { @MainActor in
                do {
                    let catalog = try await ZeroSettle.shared.fetchProducts(userId: userId)
                    result(catalog.toFlutterMap())
                } catch {
                    result(error.toFlutterError())
                }
            }

        case "getProducts":
            let products = ZeroSettle.shared.products.map { $0.toFlutterMap() }
            result(products)

        // -- Payment Sheet --

        case "presentPaymentSheet":
            guard let productId = args?["productId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "productId is required", details: nil))
                return
            }
            let userId = args?["userId"] as? String
            let dismissible = args?["dismissible"] as? Bool ?? true

            guard let product = ZeroSettle.shared.products.first(where: { $0.id == productId }) else {
                result(FlutterError(code: "product_not_found", message: "Product not found: \(productId)", details: nil))
                return
            }

            guard let viewController = Self.topViewController() else {
                result(FlutterError(code: "no_view_controller", message: "Could not find root view controller", details: nil))
                return
            }

            CheckoutSheet<PaymentSheetHeader>.present(
                from: viewController,
                product: product,
                userId: userId,
                dismissible: dismissible,
                header: { PaymentSheetHeader(product: product) },
                onComplete: { completionResult in
                    switch completionResult {
                    case .success(let transaction):
                        result(transaction.toFlutterMap())
                    case .failure(let error):
                        if let zsError = error as? ZeroSettleError {
                            switch zsError {
                            case .cancelled:
                                result(FlutterError(code: "cancelled", message: "User cancelled checkout", details: nil))
                            default:
                                result(zsError.toFlutterError())
                            }
                        } else {
                            result(FlutterError(code: "checkout_failed", message: error.localizedDescription, details: nil))
                        }
                    }
                }
            )

        // -- Purchase (1.3.0) --

        case "purchase":
            guard let productId = args?["productId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "productId is required", details: nil))
                return
            }
            let presentationRaw = args?["presentation"] as? String
            let presentation: CheckoutType?
            if let presentationRaw {
                guard let parsed = CheckoutType(rawValue: presentationRaw) else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "unknown presentation: \(presentationRaw)", details: nil))
                    return
                }
                presentation = parsed
            } else {
                presentation = nil
            }
            Task { @MainActor in
                do {
                    let transaction = try await ZeroSettle.shared.purchase(
                        productId: productId,
                        presentation: presentation
                    )
                    result(transaction.toFlutterMap())
                } catch {
                    result(error.toFlutterError())
                }
            }

        case "purchaseViaStoreKit":
            guard let productId = args?["productId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "productId is required", details: nil))
                return
            }
            Task { @MainActor in
                do {
                    let skTransaction = try await ZeroSettle.shared.purchaseViaStoreKit(productId: productId)
                    result(skTransaction.toZeroSettleFlutterMap(productId: productId))
                } catch {
                    result(error.toFlutterError())
                }
            }

        case "purchaseViaPlayBilling":
            // Android-only — peer of `purchaseViaStoreKit`. Returning a
            // tagged `not_implemented` error matches the pattern for
            // intentionally-unavailable methods on the iOS side; Dart's
            // `_wrap` rethrows as a `ZeroSettleException`.
            result(FlutterError(
                code: "not_implemented",
                message: "purchaseViaPlayBilling is Android-only. " +
                    "On iOS, use purchaseViaStoreKit(productId).",
                details: nil
            ))

        case "preloadPaymentSheet":
            guard let productId = args?["productId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "productId is required", details: nil))
                return
            }
            let userId = args?["userId"] as? String
            Task { @MainActor in
                _ = await CheckoutSheet<EmptyView>.preload(productId: productId, userId: userId)
                result(nil)
            }

        case "warmUpPaymentSheet":
            guard let productId = args?["productId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "productId is required", details: nil))
                return
            }
            let userId = args?["userId"] as? String
            Task { @MainActor in
                await CheckoutSheet<EmptyView>.warmUp(productId: productId, userId: userId)
                result(nil)
            }

        // -- Entitlements --

        case "restoreEntitlements":
            Task { @MainActor in
                do {
                    let entitlements: [Entitlement]
                    if let userId = args?["userId"] as? String {
                        entitlements = try await ZeroSettle.shared.restoreEntitlements(userId: userId)
                    } else {
                        entitlements = try await ZeroSettle.shared.restoreEntitlements()
                    }
                    result(entitlements.map { $0.toFlutterMap() })
                } catch {
                    result(error.toFlutterError())
                }
            }

        case "getEntitlements":
            let entitlements = ZeroSettle.shared.entitlements.map { $0.toFlutterMap() }
            result(entitlements)

        // -- Subscription Management --

        case "openCustomerPortal", "showManageSubscription":
            // Both APIs were removed in ZeroSettleKit. Apps should call presentCancelFlow
            // for cancellation, or use StoreKit's AppStore.showManageSubscriptions directly.
            result(FlutterError(
                code: "not_implemented",
                message: "openCustomerPortal/showManageSubscription were removed; use presentCancelFlow for cancel, or StoreKit directly for Apple billing management",
                details: nil
            ))

        // -- Universal Links --

        case "handleUniversalLink":
            guard let urlString = args?["url"] as? String,
                  let url = URL(string: urlString) else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Valid URL is required", details: nil))
                return
            }
            let handled = ZeroSettle.shared.handleUniversalLink(url)
            result(handled)

        // -- Transaction History --

        case "fetchTransactionHistory":
            Task { @MainActor in
                do {
                    let transactions: [CheckoutTransaction]
                    if let userId = args?["userId"] as? String {
                        transactions = try await ZeroSettle.shared.fetchTransactionHistory(userId: userId)
                    } else {
                        transactions = try await ZeroSettle.shared.fetchTransactionHistory()
                    }
                    result(transactions.map { $0.toFlutterMap() })
                } catch {
                    result(error.toFlutterError())
                }
            }

        // -- Cancel Flow --

        case "presentCancelFlow":
            guard let productId = args?["productId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "productId is required", details: nil))
                return
            }
            Task { @MainActor in
                let cancelResult: CancelFlow.Result
                if let userId = args?["userId"] as? String {
                    cancelResult = await ZeroSettle.shared.presentCancelFlow(
                        productId: productId,
                        userId: userId
                    )
                } else {
                    cancelResult = await ZeroSettle.shared.presentCancelFlow(productId: productId)
                }
                switch cancelResult {
                case .cancelled: result("cancelled")
                case .retained: result("retained")
                case .dismissed: result("dismissed")
                case .paused(let resumesAt):
                    if let resumesAt {
                        result("paused:" + iso8601Formatter.string(from: resumesAt))
                    } else {
                        result("paused:")
                    }
                }
            }

        case "fetchCancelFlowConfig":
            let userId = args?["userId"] as? String
            Task { @MainActor in
                do {
                    let config = try await ZeroSettle.shared.fetchCancelFlowConfig(userId: userId)
                    result(config.toFlutterMap())
                } catch {
                    result(error.toFlutterError())
                }
            }

        case "pauseSubscription":
            guard let productId = args?["productId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "productId is required", details: nil))
                return
            }
            // Kit 1.3.0 takes `pauseDurationDays: Int?`. Accept either the new
            // arg name or the legacy `pauseOptionId` (treated as duration days
            // for backward compat with the old Flutter API surface).
            let pauseDurationDays = (args?["pauseDurationDays"] as? Int) ?? (args?["pauseOptionId"] as? Int)
            Task { @MainActor in
                do {
                    let resumesAt: Date?
                    if let userId = args?["userId"] as? String {
                        resumesAt = try await ZeroSettle.shared.pauseSubscription(
                            productId: productId,
                            userId: userId,
                            pauseDurationDays: pauseDurationDays
                        )
                    } else {
                        resumesAt = try await ZeroSettle.shared.pauseSubscription(
                            productId: productId,
                            pauseDurationDays: pauseDurationDays
                        )
                    }
                    if let resumesAt {
                        result(iso8601Formatter.string(from: resumesAt))
                    } else {
                        result(nil)
                    }
                } catch {
                    result(error.toFlutterError())
                }
            }

        case "resumeSubscription":
            guard let productId = args?["productId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "productId is required", details: nil))
                return
            }
            Task { @MainActor in
                do {
                    if let userId = args?["userId"] as? String {
                        try await ZeroSettle.shared.resumeSubscription(
                            productId: productId,
                            userId: userId
                        )
                    } else {
                        try await ZeroSettle.shared.resumeSubscription(productId: productId)
                    }
                    result(nil)
                } catch {
                    result(error.toFlutterError())
                }
            }

        // -- Cancel Flow (Headless) --

        case "acceptSaveOffer":
            guard let productId = args?["productId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "productId is required", details: nil))
                return
            }
            Task { @MainActor in
                do {
                    let offerResult: CancelFlow.SaveOfferResult
                    if let userId = args?["userId"] as? String {
                        offerResult = try await ZeroSettle.shared.acceptSaveOffer(productId: productId, userId: userId)
                    } else {
                        offerResult = try await ZeroSettle.shared.acceptSaveOffer(productId: productId)
                    }
                    result([
                        "message": offerResult.message,
                        "discountPercent": offerResult.discountPercent,
                        "durationMonths": offerResult.durationMonths,
                    ] as [String: Any])
                } catch {
                    result(error.toFlutterError())
                }
            }

        case "submitCancelFlowResponse":
            guard let responseMap = args else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "response is required", details: nil))
                return
            }
            let answers = (responseMap["answers"] as? [[String: Any]])?.map { answerMap in
                CancelFlow.Answer(
                    questionId: answerMap["questionId"] as! Int,
                    selectedOptionId: answerMap["selectedOptionId"] as! Int,
                    freeText: answerMap["freeText"] as? String
                )
            } ?? []
            let outcome: CancelFlow.Outcome
            switch responseMap["outcome"] as? String {
            case "cancelled": outcome = .cancelled
            case "retained": outcome = .retained
            case "paused": outcome = .paused
            case "dismissed": outcome = .dismissed
            default: outcome = .cancelled
            }
            let response = CancelFlow.Response(
                productId: responseMap["productId"] as! String,
                userId: responseMap["userId"] as! String,
                outcome: outcome,
                answers: answers,
                offerShown: responseMap["offerShown"] as? Bool ?? false,
                offerAccepted: responseMap["offerAccepted"] as? Bool ?? false,
                pauseShown: responseMap["pauseShown"] as? Bool ?? false,
                pauseAccepted: responseMap["pauseAccepted"] as? Bool ?? false,
                pauseDurationDays: responseMap["pauseDurationDays"] as? Int
            )
            Task { @MainActor in
                do {
                    try await ZeroSettle.shared.submitCancelFlowResponse(response)
                    result(nil)
                } catch {
                    result(error.toFlutterError())
                }
            }

        case "getCancelFlowConfig":
            if let config = ZeroSettle.shared.cancelFlowConfig {
                result(config.toFlutterMap())
            } else {
                result(nil)
            }

        case "cancelSubscription":
            guard let productId = args?["productId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "productId is required", details: nil))
                return
            }
            let immediate = args?["immediate"] as? Bool ?? false
            Task { @MainActor in
                do {
                    if let userId = args?["userId"] as? String {
                        try await ZeroSettle.shared.cancelSubscription(productId: productId, userId: userId, immediate: immediate)
                    } else {
                        try await ZeroSettle.shared.cancelSubscription(productId: productId, immediate: immediate)
                    }
                    result(nil)
                } catch {
                    result(error.toFlutterError())
                }
            }

        // -- Funnel Analytics --

        case "trackEvent":
            guard let eventType = args?["eventType"] as? String,
                  let productId = args?["productId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "eventType and productId are required", details: nil))
                return
            }
            let screenName = args?["screenName"] as? String
            let metadata = args?["metadata"] as? [String: String]

            guard let funnelType = FunnelEventType(rawValue: eventType) else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Unknown event type: \(eventType)", details: nil))
                return
            }

            ZeroSettle.trackEvent(funnelType, productId: productId, screenName: screenName, metadata: metadata)
            result(nil)

        // -- Migration Tracking --

        case "trackMigrationConversion":
            Task { @MainActor in
                do {
                    if let userId = args?["userId"] as? String {
                        try await ZeroSettle.shared.trackMigrationConversion(userId: userId)
                    } else {
                        try await ZeroSettle.shared.trackMigrationConversion()
                    }
                    result(nil)
                } catch {
                    result(error.toFlutterError())
                }
            }

        // -- Migration Tip --

        case "resetMigrateTipState":
            MigrationManager.resetDismissedState()
            result(nil)

        // -- State Queries --

        case "getSdkVersion":
            result(Configuration.sdkVersion)

        case "getIsConfigured":
            result(ZeroSettle.shared.isConfigured)

        case "getPendingCheckout":
            result(ZeroSettle.shared.pendingCheckout)

        case "getRemoteConfig":
            if let config = ZeroSettle.shared.remoteConfig {
                result(config.toFlutterMap())
            } else {
                result(nil)
            }

        case "getDetectedJurisdiction":
            result(ZeroSettle.shared.detectedJurisdiction?.rawValue)

        // -- State Queries (1.3.0) --

        case "getCurrentUserId":
            // ZeroSettleKit's `currentUserId` is `internal`, so we shadow it
            // in the plugin via cachedCurrentUserId, kept in sync from
            // identify/bootstrap/logout.
            result(cachedCurrentUserId)

        case "getIsBootstrapped":
            result(ZeroSettle.shared.isBootstrapped)

        // -- Pending Claims (1.3.0) --

        case "getPendingClaims":
            result(ZeroSettle.shared.pendingClaims.map { $0.toFlutterMap() })

        // -- StoreKit Helpers (1.3.0) --

        case "recommendedAppAccountToken":
            do {
                let token = try ZeroSettle.shared.recommendedAppAccountToken()
                result(token.uuidString)
            } catch {
                result(error.toFlutterError())
            }

        // -- Apple Pay (1.3.2) --

        case "presentApplePaySetup":
            ZeroSettle.shared.presentApplePaySetup()
            result(nil)

        case "getIsApplePayOnly":
            result(ZeroSettle.shared.isApplePayOnly)

        case "getApplePayState":
            result(ZeroSettle.shared.applePayAvailability.state.rawString)

        // -- UCB (User Choice Billing) --
        // UCB is an Android/Play concept; always false on iOS.

        case "getIsUcbEnabled":
            result(false)

        case "releasePendingCheckout":
            // iOS has no equivalent — no-op that returns success.
            result(nil)

        // -- Pending Actions (Android only) --
        // Pending actions are a Play/Android concept. iOS always returns an
        // empty list and no-ops dismiss so Dart callers don't need to gate
        // on Platform.isAndroid at the call site.

        case "getPendingActions":
            result([[String: Any]]())

        case "dismissPendingAction":
            result(nil)

        // -- Migration Manager (Headless) --

        case "resolveMigrationManagerHandle":
            let stripeCustomerId = args?["stripeCustomerId"] as? String
            Task { @MainActor in
                do {
                    let manager = try ZeroSettle.shared.migrationManager(
                        stripeCustomerId: stripeCustomerId
                    )
                    let handleId = UUID().uuidString
                    self.installMigrationHandle(handleId: handleId, manager: manager)
                    result(handleId)
                } catch {
                    result(error.toFlutterError())
                }
            }

        // -- Offer Manager (Headless) --

        case "resolveOfferManagerHandle":
            let stripeCustomerId = args?["stripeCustomerId"] as? String
            Task { @MainActor in
                // ZSOfferManager became non-throwing + eager in Kit 1.3.4 to
                // fix the orphan-manager hazard. No try/catch needed; the
                // factory always returns the canonical shared instance.
                let manager = ZeroSettle.shared.offerManager(
                    stripeCustomerId: stripeCustomerId
                )
                let handleId = UUID().uuidString
                self.installOfferHandle(handleId: handleId, manager: manager)
                result(handleId)
            }

        // -- Upgrade Offer --

        case "presentUpgradeOffer":
            let productId = args?["productId"] as? String
            Task { @MainActor in
                let upgradeResult: UpgradeOffer.Result
                if let userId = args?["userId"] as? String {
                    upgradeResult = await ZeroSettle.shared.presentUpgradeOffer(
                        productId: productId,
                        userId: userId
                    )
                } else {
                    upgradeResult = await ZeroSettle.shared.presentUpgradeOffer(productId: productId)
                }
                switch upgradeResult {
                case .upgraded: result("upgraded")
                case .declined: result("declined")
                case .dismissed: result("dismissed")
                }
            }

        case "fetchUpgradeOfferConfig":
            let productId = args?["productId"] as? String
            Task { @MainActor in
                do {
                    let config: UpgradeOffer.Config
                    if let userId = args?["userId"] as? String {
                        config = try await ZeroSettle.shared.fetchUpgradeOfferConfig(
                            productId: productId,
                            userId: userId
                        )
                    } else {
                        config = try await ZeroSettle.shared.fetchUpgradeOfferConfig(productId: productId)
                    }
                    result(config.toFlutterMap())
                } catch {
                    result(error.toFlutterError())
                }
            }

        // -- User Offer (Task 9) --

        case "fetchUserOffer":
            Task { @MainActor in
                do {
                    let response = try await ZeroSettle.shared.fetchUserOffer()
                    result(response.toFlutterUserOfferMap())
                } catch {
                    result(error.toFlutterError())
                }
            }

        // -- Save the Sale --

        case "presentSaveTheSaleSheet":
            // ZSSaveTheSaleSheet was removed in ZeroSettleKit; the modern flow is
            // presentCancelFlow which surfaces save offers via CancelFlowConfig.
            result(FlutterError(code: "not_implemented", message: "presentSaveTheSaleSheet was removed; use presentCancelFlow instead", details: nil))

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Migration Manager Bridge

    /// Builds the per-handle MethodChannel + EventChannels for a freshly
    /// resolved `ZSMigrationManager` and stores the entry in
    /// `migrationHandles`. Method dispatch and stream handlers are wired in
    /// follow-up tasks (5–7) — at this point we just create the channels
    /// and the entry so the registry skeleton is testable.
    @MainActor
    private func installMigrationHandle(
        handleId: String,
        manager: ZSMigrationManager
    ) {
        guard let messenger = self.messenger else { return }
        let methodChannel = FlutterMethodChannel(
            name: "zerosettle/migration_manager_\(handleId)",
            binaryMessenger: messenger
        )
        let stateChannel = FlutterEventChannel(
            name: "zerosettle/migration_manager_\(handleId)_state",
            binaryMessenger: messenger
        )
        let failuresChannel = FlutterEventChannel(
            name: "zerosettle/migration_manager_\(handleId)_failures",
            binaryMessenger: messenger
        )
        let entry = MigrationManagerHandleEntry(
            manager: manager,
            methodChannel: methodChannel,
            stateChannel: stateChannel,
            failuresChannel: failuresChannel
        )
        migrationHandles[handleId] = entry

        // Method dispatch — imperative APIs (present, dismiss,
        // startCheckout, etc.) and disposeHandle.
        methodChannel.setMethodCallHandler { [weak self] call, result in
            Task { @MainActor in
                self?.handleMigrationManagerCall(
                    handleId: handleId, call: call, result: result
                )
            }
        }

        // State stream — pushes a coherent snapshot of all five
        // @Published properties on every change.
        stateChannel.setStreamHandler(MigrationStateStreamHandler(entry: entry))

        // Failures stream — wires `ZSMigrationManager.onCheckoutFailure`
        // (single-slot closure) onto a Flutter EventChannel so adopters
        // receive checkout failures as a Stream<CheckoutFailure>.
        failuresChannel.setStreamHandler(MigrationFailuresStreamHandler(entry: entry))
    }

    @MainActor
    private func handleMigrationManagerCall(
        handleId: String,
        call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        guard let entry = migrationHandles[handleId] else {
            result(FlutterError(
                code: "handle_not_found",
                message: "MigrationManager handle \(handleId) not found",
                details: nil
            ))
            return
        }
        let manager = entry.manager
        let args = call.arguments as? [String: Any]

        switch call.method {
        case "getState":
            result(manager.toFlutterStateMap())

        case "present":
            manager.present()
            result(nil)

        case "dismiss":
            manager.dismiss()
            result(nil)

        case "startCheckout":
            let stripeCustomerId = args?["stripeCustomerId"] as? String
            Task { @MainActor in
                let url = await manager.startCheckout(
                    stripeCustomerId: stripeCustomerId
                )
                result(url?.absoluteString)
            }

        case "markCheckoutSucceeded":
            let transactionId = args?["transactionId"] as? String
            Task { @MainActor in
                await manager.markCheckoutSucceeded(transactionId: transactionId)
                result(nil)
            }

        case "showAppleSubscriptionManagement":
            Task { @MainActor in
                await manager.showAppleSubscriptionManagement()
                result(nil)
            }

        case "disposeHandle":
            entry.cancellables.removeAll()
            entry.methodChannel.setMethodCallHandler(nil)
            entry.stateChannel.setStreamHandler(nil)
            entry.failuresChannel.setStreamHandler(nil)
            migrationHandles.removeValue(forKey: handleId)
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Offer Manager Bridge

    /// Builds the per-handle MethodChannel + EventChannel for a freshly
    /// resolved `ZSOfferManager` and stores the entry in `offerHandles`.
    /// Method dispatch and the state stream handler are wired in
    /// follow-up tasks (14–15) — at this point we just create the
    /// channels and the entry so the registry skeleton is testable.
    ///
    /// Unlike the migration variant, there's no failures channel —
    /// `ZSOfferManager` has no `onCheckoutFailure` closure callback.
    @MainActor
    private func installOfferHandle(
        handleId: String,
        manager: ZSOfferManager
    ) {
        guard let messenger = self.messenger else { return }
        let methodChannel = FlutterMethodChannel(
            name: "zerosettle/offer_manager_\(handleId)",
            binaryMessenger: messenger
        )
        let stateChannel = FlutterEventChannel(
            name: "zerosettle/offer_manager_\(handleId)_state",
            binaryMessenger: messenger
        )
        let entry = OfferManagerHandleEntry(
            manager: manager,
            methodChannel: methodChannel,
            stateChannel: stateChannel
        )
        offerHandles[handleId] = entry

        // Method dispatch — imperative APIs (present, dismiss,
        // startCheckout, preloadCheckout, etc.) and disposeHandle.
        methodChannel.setMethodCallHandler { [weak self] call, result in
            Task { @MainActor in
                self?.handleOfferManagerCall(
                    handleId: handleId, call: call, result: result
                )
            }
        }

        // State stream — pushes a coherent snapshot of all five
        // @Published properties on every change.
        stateChannel.setStreamHandler(OfferStateStreamHandler(entry: entry))
    }

    @MainActor
    private func handleOfferManagerCall(
        handleId: String,
        call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        guard let entry = offerHandles[handleId] else {
            result(FlutterError(
                code: "handle_not_found",
                message: "OfferManager handle \(handleId) not found",
                details: nil
            ))
            return
        }
        let manager = entry.manager
        let args = call.arguments as? [String: Any]

        switch call.method {
        case "getState":
            result(manager.toFlutterStateMap())

        case "present":
            manager.present()
            result(nil)

        case "dismiss":
            manager.dismiss()
            result(nil)

        case "startCheckout":
            let stripeCustomerId = args?["stripeCustomerId"] as? String
            Task { @MainActor in
                let url = await manager.startCheckout(
                    stripeCustomerId: stripeCustomerId
                )
                result(url?.absoluteString)
            }

        case "preloadCheckout":
            let stripeCustomerId = args?["stripeCustomerId"] as? String
            Task { @MainActor in
                let url = await manager.preloadCheckout(
                    stripeCustomerId: stripeCustomerId
                )
                result(url?.absoluteString)
            }

        case "markCheckoutSucceeded":
            let transactionId = args?["transactionId"] as? String
            Task { @MainActor in
                await manager.markCheckoutSucceeded(transactionId: transactionId)
                result(nil)
            }

        case "showAppleSubscriptionManagement":
            Task { @MainActor in
                await manager.showAppleSubscriptionManagement()
                result(nil)
            }

        case "disposeHandle":
            entry.cancellables.removeAll()
            entry.methodChannel.setMethodCallHandler(nil)
            entry.stateChannel.setStreamHandler(nil)
            offerHandles.removeValue(forKey: handleId)
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Root View Controller

    @MainActor
    private static func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
              let rootVC = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return nil
        }
        var top = rootVC
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}

// MARK: - ZeroSettleDelegate

extension ZeroSettlePlugin: ZeroSettleDelegate {

    public func zeroSettleCheckoutDidBegin(productId: String) {
        checkoutStreamHandler.send([
            "event": "checkoutDidBegin",
            "productId": productId,
        ])
    }

    public func zeroSettleCheckoutDidComplete(transaction: CheckoutTransaction) {
        checkoutStreamHandler.send([
            "event": "checkoutDidComplete",
            "transaction": transaction.toFlutterMap(),
        ])
        // Task 12 — also emit onto the unified events stream.
        eventsStreamHandler.send([
            "type": "purchaseSucceeded",
            "productId": transaction.productId,
            "transactionId": transaction.id,
        ])
    }

    public func zeroSettleCheckoutDidCancel(productId: String) {
        checkoutStreamHandler.send([
            "event": "checkoutDidCancel",
            "productId": productId,
        ])
    }

    public func zeroSettleCheckoutDidFail(productId: String, error: Error) {
        checkoutStreamHandler.send([
            "event": "checkoutDidFail",
            "productId": productId,
            "error": error.localizedDescription,
        ])
        // Task 12 — also emit onto the unified events stream.
        eventsStreamHandler.send([
            "type": "purchaseFailed",
            "productId": productId,
            "reason": error.localizedDescription,
        ])
    }

    public func zeroSettleEntitlementsDidUpdate(_ entitlements: [Entitlement]) {
        entitlementStreamHandler.send(entitlements.map { $0.toFlutterMap() })
        // Task 12 — also emit onto the unified events stream.
        // Filter to active-only to match Android's count semantics — Android's
        // EntitlementPoller receives the API response which is active-only;
        // iOS's delegate callback receives all entitlements (active + expired).
        let activeCount = entitlements.filter { $0.isActive }.count
        eventsStreamHandler.send([
            "type": "entitlementsRefreshed",
            "count": activeCount,
        ])
    }

    public func zeroSettleDidSyncStoreKitTransaction(productId: String, transactionId: UInt64) {
        checkoutStreamHandler.send([
            "event": "storeKitTransactionSynced",
            "productId": productId,
            "transactionId": transactionId,
        ])
    }

    public func zeroSettleStoreKitSyncFailed(error: Error) {
        checkoutStreamHandler.send([
            "event": "storeKitSyncFailed",
            "error": error.localizedDescription,
        ])
        // Task 12 — also emit onto the unified events stream.
        // iOS delegate does not surface purchaseToken or retry count, so we
        // emit degraded fields. `terminal=true` because ZeroSettleKit's
        // StoreKit sync retry queue gives up before this delegate fires.
        eventsStreamHandler.send([
            "type": "syncFailed",
            "purchaseToken": "",
            "attempts": 1,
            "terminal": true,
        ])
    }
}

// MARK: - Event Stream Handlers

private class EntitlementStreamHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    func send(_ data: Any) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(data)
        }
    }
}

private class CheckoutStreamHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    func send(_ data: Any) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(data)
        }
    }
}

private class PendingClaimsStreamHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    /// Optional callback fired when Dart starts listening — used by the
    /// plugin to push the current snapshot so late subscribers don't have
    /// to wait for the next mutation.
    var onListenStarted: (() -> Void)?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        onListenStarted?()
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    func send(_ data: Any) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(data)
        }
    }
}

/// Gap 5 — generic stream handler used by the four reactive state
/// channels (`products`, `currentUserId`, `pendingCheckout`,
/// `isBootstrapped`). All four share the same shape: cache the latest
/// emission, replay it to late subscribers via `onListenStarted`. Sending
/// `NSNull()` is supported so `currentUserId` can publish a logout event.
private class ReactiveStateStreamHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    var onListenStarted: (() -> Void)?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        onListenStarted?()
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    func send(_ data: Any) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(data)
        }
    }
}

private class ApplePayStateStreamHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    /// Optional callback fired when Dart starts listening — used by the
    /// plugin to push the current Apple Pay availability state so late
    /// subscribers see it without waiting for the next change.
    var onListenStarted: (() -> Void)?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        onListenStarted?()
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    func send(_ data: Any) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(data)
        }
    }
}

/// One-shot [FlutterStreamHandler] that emits a single Bool value when Dart
/// subscribes, then does nothing further. Used to stub Android-only channels
/// on iOS — callers get a deterministic `false` instead of a stream that
/// never emits, which would leave Dart in an indefinitely pending state.
private class OneShotBoolStreamHandler: NSObject, FlutterStreamHandler {
    private let value: Bool

    init(value: Bool) {
        self.value = value
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        events(value)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        return nil
    }
}

/// One-shot [FlutterStreamHandler] that emits an empty array when Dart
/// subscribes, then does nothing further. Used to stub Android-only
/// `pendingActionsUpdates` on iOS — callers get a deterministic `[]`
/// instead of a stream that never emits, which would leave Dart in an
/// indefinitely pending state. Analogous to [OneShotBoolStreamHandler].
private class OneShotEmptyListStreamHandler: NSObject, FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        events([[String: Any]]())
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        return nil
    }
}

/// Task 12 — discrete event stream handler for `zerosettle/events`.
/// Same shape as `CheckoutStreamHandler` — no caching, no late-subscriber
/// replay. Events are one-shot signals (purchase completed, sync failed, etc.)
/// and replaying them to a late subscriber would cause double-processing.
private class EventsStreamHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    func send(_ data: Any) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(data)
        }
    }
}

/// Cheap structural dedupe for pending-claim snapshots — same count + same
/// `productId` and `originalTransactionId` per index. Used to avoid emitting
/// no-op updates when `objectWillChange` fires for unrelated mutations on
/// the shared `ZeroSettle` instance.
private func pendingClaimsSnapshotsEqual(_ a: [[String: Any]], _ b: [[String: Any]]) -> Bool {
    guard a.count == b.count else { return false }
    for (lhs, rhs) in zip(a, b) {
        if (lhs["productId"] as? String) != (rhs["productId"] as? String) { return false }
        if (lhs["originalTransactionId"] as? String) != (rhs["originalTransactionId"] as? String) { return false }
    }
    return true
}

/// Gap 5 — cheap structural dedupe for product snapshots. Compares same
/// count + same `id` per index. Catalog mutations always change the id
/// list when meaningful (add/remove/reorder); pure price updates aren't
/// frequent enough to merit deep-equality. Same idea as
/// `pendingClaimsSnapshotsEqual`.
private func productsSnapshotsEqual(_ a: [[String: Any]], _ b: [[String: Any]]) -> Bool {
    guard a.count == b.count else { return false }
    for (lhs, rhs) in zip(a, b) {
        if (lhs["id"] as? String) != (rhs["id"] as? String) { return false }
    }
    return true
}

// MARK: - Serialization Helpers

private let iso8601Formatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

extension Price {
    func toFlutterMap() -> [String: Any] {
        return [
            "amountCents": amountCents,
            "currencyCode": currencyCode,
        ]
    }
}

extension Promotion {
    func toFlutterMap() -> [String: Any] {
        var map: [String: Any] = [
            "id": id,
            "displayName": displayName,
            "promotionalPrice": promotionalPrice.toFlutterMap(),
            "type": type.rawValue,
        ]
        if let expiresAt {
            map["expiresAt"] = iso8601Formatter.string(from: expiresAt)
        }
        return map
    }
}

// MARK: - UserOffer Flutter Wire Encoders (Task 9: fetchUserOffer)
//
// Encodes `UserOffer.Response` into the wire shape consumed by Dart's
// `UserOfferResponse.fromMap` in `lib/models/user_offer.dart`.
//
// Type coercions:
//   Response.appId            : Int  → String  (Dart reads String?)
//   Response.serverTime       : Date → ISO8601 String
//   OfferData.experimentVariantId: Int? → String?
//   Proration.nextBillingDate : Date? → ISO8601 String?
//   AppleSubscription.expiresAt: Date? → ISO8601 String?
//   ActionType raw value is snake_case; emit camelCase wire string.
//   SourceStorefront raw value is snake_case; emit camelCase wire string.
//   Subscription is a tagged-union enum; flatten to {type, productId?}.
//
// Null-omission rule: optional fields absent from the map rather than
// emitted as nil (matches Android encoder and Dart parser expectations).

private extension UserOffer.ActionType {
    var userOfferWireString: String {
        switch self {
        case .noAction:             return "noAction"
        case .migrateStorekitToWeb: return "migrateStorekitToWeb"
        case .upgradeStorekitToWeb: return "upgradeStorekitToWeb"
        case .upgradeWebToWeb:      return "upgradeWebToWeb"
        }
    }
}

private extension UserOffer.SourceStorefront {
    var userOfferWireString: String {
        switch self {
        case .storeKit:  return "storeKit"
        case .playStore: return "playStore"
        }
    }
}

private extension UserOffer.CheckoutPresentation {
    var userOfferWireString: String {
        switch self {
        case .webview:   return "webview"
        case .nativePay: return "nativePay"
        case .safariVc:  return "safariVc"
        case .safari:    return "safari"
        }
    }
}

private extension UserOffer.Subscription {
    /// Flattens the tagged-union enum to the `{type, productId?}` shape
    /// that Dart's `UserOfferSubscription.fromMap` expects.
    func toFlutterMap() -> [String: Any] {
        switch self {
        case .none:
            return ["type": "none"]
        case .activeWeb(let s):
            return ["type": "activeWeb", "productId": s.productId]
        case .activeStorekit(let s):
            return ["type": "activeStorekit", "productId": s.productId]
        case .migrationTrial(let s):
            return ["type": "migrationTrial", "productId": s.productId]
        case .cancelledActive(let s):
            return ["type": "cancelledActive", "productId": s.productId]
        case .unknown(let raw):
            return ["type": raw]
        }
    }
}

private extension UserOffer.Display {
    func toFlutterMap() -> [String: Any] {
        return [
            "title": title,
            "body": body,
            "ctaText": ctaText,
            "dismissText": dismissText,
            "acceptedTitle": acceptedTitle,
            "acceptedBody": acceptedBody,
            "completedTitle": completedTitle,
            "completedBody": completedBody,
            "appleCancelInstructions": appleCancelInstructions,
        ]
    }
}

private extension UserOffer.Proration {
    func toFlutterMap() -> [String: Any] {
        var map: [String: Any] = [
            "amountCents": amountCents,
            "currency": currency,
        ]
        if let nextBillingDate {
            map["nextBillingDate"] = iso8601Formatter.string(from: nextBillingDate)
        }
        return map
    }
}

private extension UserOffer.AppleSubscription {
    func toFlutterMap() -> [String: Any] {
        var map: [String: Any] = [
            "isActive": isActive,
            "statusCode": statusCode,
            "autoRenewEnabled": autoRenewEnabled,
        ]
        if let expiresAt {
            map["expiresAt"] = iso8601Formatter.string(from: expiresAt)
        }
        return map
    }
}

private extension UserOffer.OfferData {
    func toFlutterUserOfferMap() -> [String: Any] {
        var map: [String: Any] = [
            "actionType": actionType.userOfferWireString,
            "isEligible": isEligible,
            "checkoutProductId": checkoutProductId,
            "savingsPercent": savingsPercent,
            "freeTrialDays": freeTrialDays,
            "minSubscriptionDays": minSubscriptionDays,
            "rolloutPercent": rolloutPercent,
            "requiresAppleCancel": requiresAppleCancel,
        ]
        if let fromProductId {
            map["fromProductId"] = fromProductId
        }
        if let maxSubscriptionDays {
            map["maxSubscriptionDays"] = maxSubscriptionDays
        }
        if let display {
            map["display"] = display.toFlutterMap()
        }
        if let proration {
            map["proration"] = proration.toFlutterMap()
        }
        if let appleSubscription {
            map["appleSubscription"] = appleSubscription.toFlutterMap()
        }
        if let checkoutPresentation {
            map["checkoutPresentation"] = checkoutPresentation.userOfferWireString
        }
        // experimentVariantId: Int? → String? (Dart reads String?)
        if let experimentVariantId {
            map["experimentVariantId"] = String(experimentVariantId)
        }
        if let source {
            map["source"] = source.userOfferWireString
        }
        return map
    }
}

private extension UserOffer.Response {
    /// Encodes the response for the `fetchUserOffer` Flutter wire. Keys match
    /// Dart's `UserOfferResponse.fromMap` in `lib/models/user_offer.dart`.
    func toFlutterUserOfferMap() -> [String: Any] {
        return [
            "userId": userId,
            // appId is Int in the Swift model; Dart expects String.
            "appId": String(appId),
            "isSandbox": isSandbox,
            "serverTime": iso8601Formatter.string(from: serverTime),
            "subscription": subscription.toFlutterMap(),
            "offer": offer.toFlutterUserOfferMap(),
        ]
    }
}

extension ZeroSettleKit.ZSProduct {
    func toFlutterMap() -> [String: Any] {
        var map: [String: Any] = [
            "id": id,
            "displayName": displayName,
            "productDescription": productDescription,
            "type": type.rawValue,
            "syncedToAppStoreConnect": syncedToAppStoreConnect,
            "storeKitAvailable": storeKitAvailable,
        ]
        if let webPrice {
            map["webPrice"] = webPrice.toFlutterMap()
        }
        if let appStorePrice {
            map["appStorePrice"] = appStorePrice.toFlutterMap()
        }
        if let promotion {
            map["promotion"] = promotion.toFlutterMap()
        }
        if let storeKitPrice {
            map["storeKitPrice"] = storeKitPrice.toFlutterMap()
        }
        if let savingsPercent {
            map["savingsPercent"] = savingsPercent
        }
        if let subscriptionGroupId {
            map["subscriptionGroupId"] = subscriptionGroupId
        }
        if let billingInterval {
            map["billingInterval"] = billingInterval
        }
        if let freeTrialDuration {
            map["freeTrialDuration"] = freeTrialDuration
        }
        if let isTrialEligible {
            map["isTrialEligible"] = isTrialEligible
        }
        return map
    }
}

extension Entitlement {
    func toFlutterMap() -> [String: Any] {
        var map: [String: Any] = [
            "id": id,
            "productId": productId,
            "source": source.rawValue,
            "isActive": isActive,
            "purchasedAt": iso8601Formatter.string(from: purchasedAt),
        ]
        if let expiresAt {
            map["expiresAt"] = iso8601Formatter.string(from: expiresAt)
        }
        map["status"] = status.rawString
        if let pausedAt {
            map["pausedAt"] = iso8601Formatter.string(from: pausedAt)
        }
        if let pauseResumesAt {
            map["pauseResumesAt"] = iso8601Formatter.string(from: pauseResumesAt)
        }
        map["willRenew"] = willRenew
        map["isTrial"] = isTrial
        if let trialEndsAt {
            map["trialEndsAt"] = iso8601Formatter.string(from: trialEndsAt)
        }
        if let cancelledAt {
            map["cancelledAt"] = iso8601Formatter.string(from: cancelledAt)
        }
        if let storekitOriginalTransactionId {
            map["storekitOriginalTransactionId"] = storekitOriginalTransactionId
        }
        if let originalPurchaseDate {
            map["originalPurchaseDate"] = iso8601Formatter.string(from: originalPurchaseDate)
        }
        return map
    }
}

extension CheckoutTransaction {
    func toFlutterMap() -> [String: Any] {
        var map: [String: Any] = [
            "id": id,
            "productId": productId,
            "status": status.rawValue,
            "source": source.rawValue,
            "purchasedAt": iso8601Formatter.string(from: purchasedAt),
        ]
        if let expiresAt {
            map["expiresAt"] = iso8601Formatter.string(from: expiresAt)
        }
        if let productName {
            map["productName"] = productName
        }
        if let amountCents {
            map["amountCents"] = amountCents
        }
        if let currency {
            map["currency"] = currency
        }
        if let storekitStatus {
            map["storekitStatus"] = storekitStatus
        }
        return map
    }
}

extension PendingClaim {
    func toFlutterMap() -> [String: Any] {
        return [
            "productId": productId,
            "originalTransactionId": originalTransactionId,
            "existingOwnerHint": existingOwnerHint,
        ]
    }
}

extension StoreKit.Transaction {
    /// Map a native `StoreKit.Transaction` onto the same Dart shape as
    /// `CheckoutTransaction.fromMap` expects. `status` and `source` are
    /// hard-coded — a successfully-returned StoreKit transaction is
    /// verified, so `completed` / `store_kit` are correct. `amountCents`
    /// and `currency` are intentionally omitted: StoreKit.Transaction
    /// doesn't carry localized price info — adopters should read the
    /// product catalog if they need price.
    func toZeroSettleFlutterMap(productId: String) -> [String: Any] {
        var map: [String: Any] = [
            "id": String(id),
            "productId": productID,
            "originalTransactionId": String(originalID),
            "purchasedAt": iso8601Formatter.string(from: purchaseDate),
            "status": "completed",
            "source": "store_kit",
        ]
        if let expirationDate {
            map["expiresAt"] = iso8601Formatter.string(from: expirationDate)
        }
        return map
    }
}

extension ProductCatalog {
    func toFlutterMap() -> [String: Any] {
        var map: [String: Any] = [
            "products": products.map { $0.toFlutterMap() },
        ]
        if let config {
            map["config"] = config.toFlutterMap()
        }
        return map
    }
}

extension JurisdictionCheckoutConfig {
    func toFlutterMap() -> [String: Any] {
        return [
            "sheetType": sheetType.rawValue,
            "isEnabled": isEnabled,
        ]
    }
}

extension CheckoutConfig {
    func toFlutterMap() -> [String: Any] {
        var jurisdictionsMap: [String: Any] = [:]
        for (key, value) in jurisdictions {
            jurisdictionsMap[key.rawValue] = value.toFlutterMap()
        }
        var map: [String: Any] = [
            "sheetType": sheetType.rawValue,
            "isEnabled": isEnabled,
            "jurisdictions": jurisdictionsMap,
            "isApplePayOnly": isApplePayOnly,
        ]
        if let paymentMethods {
            map["paymentMethods"] = paymentMethods
        }
        return map
    }
}

extension MigrationPrompt {
    func toFlutterMap() -> [String: Any] {
        return [
            "productId": productId,
            "discountPercent": discountPercent,
            "title": title,
            "message": message,
            "ctaText": ctaText,
        ]
    }
}

extension RemoteConfig {
    func toFlutterMap() -> [String: Any] {
        var map: [String: Any] = [
            "checkout": checkout.toFlutterMap(),
        ]
        if let migration {
            map["migration"] = migration.toFlutterMap()
        }
        return map
    }
}

extension CancelFlow.Config {
    func toFlutterMap() -> [String: Any] {
        var map: [String: Any] = [
            "enabled": enabled,
            "questions": questions.map { $0.toFlutterMap() },
        ]
        if let offer {
            map["offer"] = offer.toFlutterMap()
        }
        if let pause {
            map["pause"] = pause.toFlutterMap()
        }
        if let variantId {
            map["variantId"] = variantId
        }
        return map
    }
}

extension CancelFlow.Question {
    func toFlutterMap() -> [String: Any] {
        return [
            "id": id,
            "order": order,
            "questionText": questionText,
            "questionType": questionType.rawValue,
            "isRequired": isRequired,
            "options": options.map { $0.toFlutterMap() },
        ]
    }
}

extension CancelFlow.Option {
    func toFlutterMap() -> [String: Any] {
        return [
            "id": id,
            "order": order,
            "label": label,
            "triggersOffer": triggersOffer,
            "triggersPause": triggersPause,
        ]
    }
}

extension CancelFlow.Offer {
    func toFlutterMap() -> [String: Any] {
        return [
            "enabled": enabled,
            "title": title,
            "body": body,
            "ctaText": ctaText,
            "type": type,
            "value": value,
        ]
    }
}

extension CancelFlow.PauseConfig {
    func toFlutterMap() -> [String: Any] {
        return [
            "enabled": enabled,
            "title": title,
            "body": body,
            "ctaText": ctaText,
            "options": options.map { $0.toFlutterMap() },
        ]
    }
}

extension CancelFlow.PauseOption {
    func toFlutterMap() -> [String: Any] {
        var map: [String: Any] = [
            "id": id,
            "order": order,
            "label": label,
            "durationType": durationType,
        ]
        if let durationDays {
            map["durationDays"] = durationDays
        }
        if let resumeDate {
            map["resumeDate"] = iso8601Formatter.string(from: resumeDate)
        }
        return map
    }
}

// MARK: - Upgrade Offer Flutter Map

extension UpgradeOffer.Config {
    func toFlutterMap() -> [String: Any] {
        var map: [String: Any] = ["available": available]
        if let reason { map["reason"] = reason.rawString }
        if let currentProduct { map["currentProduct"] = currentProduct.toFlutterMap() }
        if let targetProduct { map["targetProduct"] = targetProduct.toFlutterMap() }
        if let savingsPercent { map["savingsPercent"] = savingsPercent }
        if let upgradeType { map["upgradeType"] = upgradeType.rawValue }
        if let proration { map["proration"] = proration.toFlutterMap() }
        if let display { map["display"] = display.toFlutterMap() }
        if let variantId { map["variantId"] = variantId }
        return map
    }
}

extension UpgradeOffer.ProductInfo {
    func toFlutterMap() -> [String: Any] {
        var map: [String: Any] = [
            "referenceId": referenceId,
            "name": name,
            "priceCents": price.amountCents,
            "currency": price.currencyCode,
            "billingLabel": billingLabel,
        ]
        // `durationDays` is not available on iOS `ProductInfo`. Omit the key
        // rather than emitting `0` — the Dart model treats it as `int?` and
        // the Android encoder omits it when unknown. Emitting `0` here would
        // make the same "unknown" state read as `0` on iOS and `null` on
        // Android — a cross-platform parity bug.
        if let monthlyEquivalent {
            map["monthlyEquivalentCents"] = monthlyEquivalent.amountCents
        }
        return map
    }
}

extension UpgradeOffer.Proration {
    func toFlutterMap() -> [String: Any] {
        var map: [String: Any] = [
            "prorationAmountCents": amountCents,
            "currency": currency,
        ]
        if let nextBillingDate {
            map["nextBillingDate"] = Int(nextBillingDate.timeIntervalSince1970)
        }
        return map
    }
}

extension UpgradeOffer.Display {
    func toFlutterMap() -> [String: Any] {
        var map: [String: Any] = [
            "title": title,
            "body": body,
            "ctaText": ctaText,
            "dismissText": dismissText,
        ]
        if let storekitMigrationBody { map["storekitMigrationBody"] = storekitMigrationBody }
        if let storekitCancelInstructions { map["cancelInstructions"] = storekitCancelInstructions }
        return map
    }
}

// MARK: - Migration Manager Stream Handlers

/// Bridges `ZSMigrationManager`'s 5 `@Published` properties onto a Flutter
/// EventChannel. We use the manual-sink pattern (5 independent
/// `.sink` subscriptions all calling a shared `emitSnapshot`) instead of
/// `Publishers.CombineLatest4(...).combineLatest(...)` because the chained
/// form produces a tuple-of-tuples that's awkward to type-check, and the
/// per-property approach gives us the same dedup guarantees once paired
/// with `removeDuplicates()` per stream — when any single property changes
/// we re-read the manager's full state and push a coherent snapshot.
private final class MigrationStateStreamHandler: NSObject, FlutterStreamHandler {
    private weak var entry: MigrationManagerHandleEntry?

    init(entry: MigrationManagerHandleEntry) {
        self.entry = entry
    }

    func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        guard let entry else { return nil }
        entry.stateSink = events

        // ZSMigrationManager is @MainActor — touching its `@Published`
        // backing publishers (`$state`, etc.) and reading its properties
        // must happen on the main actor. `onListen` itself is nonisolated,
        // so we hop over before subscribing.
        Task { @MainActor in
            // Emit the current snapshot immediately so late subscribers
            // don't have to wait for the next mutation.
            events(entry.manager.toFlutterStateMap())

            // Subscribe to each of the 5 published properties. On any
            // change we re-read the manager's current state and push the
            // merged map. This sidesteps Combine's 4-arity ceiling and
            // keeps the read on the main actor (which the manager
            // requires).
            let emit: () -> Void = { [weak entry] in
                guard let entry else { return }
                Task { @MainActor in
                    entry.stateSink?(entry.manager.toFlutterStateMap())
                }
            }
            let manager = entry.manager
            manager.$state
                .dropFirst()
                .receive(on: DispatchQueue.main)
                .sink { _ in emit() }
                .store(in: &entry.cancellables)
            manager.$offerData
                .dropFirst()
                .receive(on: DispatchQueue.main)
                .sink { _ in emit() }
                .store(in: &entry.cancellables)
            manager.$checkoutError
                .dropFirst()
                .receive(on: DispatchQueue.main)
                .sink { _ in emit() }
                .store(in: &entry.cancellables)
            manager.$isLoading
                .dropFirst()
                .receive(on: DispatchQueue.main)
                .sink { _ in emit() }
                .store(in: &entry.cancellables)
            manager.$storekitCancelRequired
                .dropFirst()
                .receive(on: DispatchQueue.main)
                .sink { _ in emit() }
                .store(in: &entry.cancellables)
        }

        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        entry?.stateSink = nil
        return nil
    }
}

// MARK: - Migration Manager Flutter Map Extensions

private extension ZSMigrationManager {
    func toFlutterStateMap() -> [String: Any] {
        var map: [String: Any] = [
            "state": state.rawString,
            "isLoading": isLoading,
            "storekitCancelRequired": storekitCancelRequired,
        ]
        if let offerData = offerData {
            map["offerData"] = offerData.toFlutterMap()
        }
        if let err = checkoutError {
            map["checkoutErrorMessage"] = err.localizedDescription
        }
        return map
    }
}

private extension MigrationOffer.State {
    var rawString: String {
        switch self {
        case .loading:    return "loading"
        case .ineligible: return "ineligible"
        case .eligible:   return "eligible"
        case .presented:  return "presented"
        case .accepted:   return "accepted"
        case .completed:  return "completed"
        case .dismissed:  return "dismissed"
        }
    }
}

private extension MigrationOffer.OfferData {
    func toFlutterMap() -> [String: Any] {
        var map: [String: Any] = [
            "prompt": prompt.toFlutterMap(),
            "freeTrialDays": freeTrialDays,
            "activeStoreKitProductId": activeStoreKitProductId,
        ]
        if let end = storekitSubscriptionEnd {
            map["storekitSubscriptionEnd"] = iso8601Formatter.string(from: end)
        }
        if let otid = activeStoreKitOriginalTransactionId {
            map["activeStoreKitOriginalTransactionId"] = otid
        }
        return map
    }
}

// MARK: - Offer Manager Stream Handler

/// Bridges `ZSOfferManager`'s 5 `@Published` properties onto a Flutter
/// EventChannel. Same manual-sink pattern as `MigrationStateStreamHandler`
/// — when any single property changes we re-read the manager's full state
/// and push a coherent snapshot.
private final class OfferStateStreamHandler: NSObject, FlutterStreamHandler {
    private weak var entry: OfferManagerHandleEntry?

    init(entry: OfferManagerHandleEntry) {
        self.entry = entry
    }

    func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        guard let entry else { return nil }
        entry.stateSink = events

        // ZSOfferManager is @MainActor — touching its `@Published` backing
        // publishers (`$state`, etc.) and reading its properties must
        // happen on the main actor. `onListen` itself is nonisolated, so
        // we hop over before subscribing.
        Task { @MainActor in
            // Emit the current snapshot immediately so late subscribers
            // don't have to wait for the next mutation.
            events(entry.manager.toFlutterStateMap())

            // Subscribe to each of the 5 published properties. On any
            // change we re-read the manager's current state and push the
            // merged map. This sidesteps Combine's 4-arity ceiling and
            // keeps the read on the main actor (which the manager
            // requires).
            let emit: () -> Void = { [weak entry] in
                guard let entry else { return }
                Task { @MainActor in
                    entry.stateSink?(entry.manager.toFlutterStateMap())
                }
            }
            let manager = entry.manager
            manager.$state
                .dropFirst()
                .receive(on: DispatchQueue.main)
                .sink { _ in emit() }
                .store(in: &entry.cancellables)
            manager.$offerData
                .dropFirst()
                .receive(on: DispatchQueue.main)
                .sink { _ in emit() }
                .store(in: &entry.cancellables)
            manager.$checkoutError
                .dropFirst()
                .receive(on: DispatchQueue.main)
                .sink { _ in emit() }
                .store(in: &entry.cancellables)
            manager.$isLoading
                .dropFirst()
                .receive(on: DispatchQueue.main)
                .sink { _ in emit() }
                .store(in: &entry.cancellables)
            manager.$storekitCancelRequired
                .dropFirst()
                .receive(on: DispatchQueue.main)
                .sink { _ in emit() }
                .store(in: &entry.cancellables)
        }

        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        entry?.stateSink = nil
        return nil
    }
}

// MARK: - Offer Manager Flutter Map Extensions

private extension ZSOfferManager {
    func toFlutterStateMap() -> [String: Any] {
        var map: [String: Any] = [
            "state": state.rawString,
            "isLoading": isLoading,
            "storekitCancelRequired": storekitCancelRequired,
        ]
        if let offerData = offerData {
            map["offerData"] = offerData.toFlutterMap()
        }
        if let err = checkoutError {
            map["checkoutErrorMessage"] = err.localizedDescription
        }
        return map
    }
}

private extension Offer.State {
    var rawString: String {
        switch self {
        case .loading:    return "loading"
        case .ineligible: return "ineligible"
        case .eligible:   return "eligible"
        case .presented:  return "presented"
        case .accepted:   return "accepted"
        case .completed:  return "completed"
        case .dismissed:  return "dismissed"
        }
    }
}

private extension Offer.FlowType {
    var rawString: String { rawValue }
}

private extension Offer.UpgradeType {
    var rawString: String { rawValue }
}

private extension Offer.CheckoutPresentation {
    var rawString: String { rawValue }
}

private extension Offer.Display {
    func toFlutterMap() -> [String: Any] {
        return [
            "offerTitle": offerTitle,
            "offerMessage": offerMessage,
            "offerCta": offerCta,
            "acceptedTitle": acceptedTitle,
            "acceptedMessage": acceptedMessage,
            "acceptedCta": acceptedCta,
            "completedTitle": completedTitle,
            "completedMessage": completedMessage,
        ]
    }
}

private extension Offer.PerProductOffer {
    func toFlutterMap() -> [String: Any] {
        return [
            "productId": productId,
            "savingsPercent": savingsPercent,
            "display": display.toFlutterMap(),
        ]
    }
}

private extension Offer.OfferData {
    func toFlutterMap() -> [String: Any] {
        var map: [String: Any] = [
            "flowType": flowType.rawString,
            "productId": productId,
            "eligibleProductIds": eligibleProductIds,
            "savingsPercent": savingsPercent,
            "display": display.toFlutterMap(),
            "freeTrialDays": freeTrialDays,
            "minSubscriptionDays": minSubscriptionDays,
        ]
        if let maxSub = maxSubscriptionDays {
            map["maxSubscriptionDays"] = maxSub
        }
        if let rollout = rolloutPercent {
            map["rolloutPercent"] = rollout
        }
        if let upgradeType {
            map["upgradeType"] = upgradeType.rawString
        }
        if let fromProductId {
            map["fromProductId"] = fromProductId
        }
        if let toProductId {
            map["toProductId"] = toProductId
        }
        if let variantId {
            map["variantId"] = variantId
        }
        if let perProductPrompts {
            var dict: [String: [String: Any]] = [:]
            for (key, value) in perProductPrompts {
                dict[key] = value.toFlutterMap()
            }
            map["perProductPrompts"] = dict
        }
        if let checkoutPresentation {
            map["checkoutPresentation"] = checkoutPresentation.rawString
        }
        return map
    }
}

/// Bridges `ZSMigrationManager.onCheckoutFailure` (single-slot closure) onto
/// a Flutter EventChannel. Per-handle scope means there's at most one
/// Flutter listener per manager instance, so overwriting the closure is
/// safe — adopters who configured one in Swift would not also be using the
/// Flutter bridge.
private final class MigrationFailuresStreamHandler: NSObject, FlutterStreamHandler {
    private weak var entry: MigrationManagerHandleEntry?

    init(entry: MigrationManagerHandleEntry) {
        self.entry = entry
    }

    func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        guard let entry else { return nil }
        entry.failuresSink = events

        // Hop to MainActor — `ZSMigrationManager` is @MainActor and so is
        // its `onCheckoutFailure` property.
        Task { @MainActor in
            entry.manager.onCheckoutFailure = { [weak entry] failure in
                guard let entry else { return }
                Task { @MainActor in
                    entry.failuresSink?(failure.toFlutterMap())
                }
            }
        }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        entry?.failuresSink = nil
        // Don't clear the closure on cancel — listener might re-subscribe.
        return nil
    }
}

/// `CheckoutFailure` is a Swift enum with associated values — flatten to a
/// shape Dart can deserialize: `{ kind, message, statusCode?, url? }`.
private extension CheckoutFailure {
    func toFlutterMap() -> [String: Any] {
        switch self {
        case .networkUnreachable(let err):
            return [
                "kind": "networkUnreachable",
                "message": err.localizedDescription,
            ]
        case .loadFailed(let err):
            return [
                "kind": "loadFailed",
                "message": err.localizedDescription,
            ]
        case .serverError(let statusCode, let url):
            return [
                "kind": "serverError",
                "message": "Server error \(statusCode) at \(url.absoluteString)",
                "statusCode": statusCode,
                "url": url.absoluteString,
            ]
        case .unknown(let err):
            return [
                "kind": "unknown",
                "message": err.localizedDescription,
            ]
        }
    }
}

// MARK: - Apple Pay Raw-String Mapping

/// `ApplePaySetupBehavior` is declared `Sendable` without an explicit raw
/// value type on the iOS Kit. We map to/from string form here so the wire
/// format stays stable across Kit versions.
extension ApplePaySetupBehavior {
    static func fromRawString(_ value: String) -> ApplePaySetupBehavior? {
        switch value {
        case "presentBuiltInUI": return .presentBuiltInUI
        case "delegateToApp": return .delegateToApp
        default: return nil
        }
    }
}

/// `ApplePayAvailability.State` is declared `Equatable, Sendable` without an
/// explicit raw value type. The persistence raw values used by the Kit
/// (`UserDefaults` keys for `debugStateOverride`) are mirrored here so the
/// stream payloads, single reads, and persisted state all use the same wire
/// strings.
extension ApplePayAvailability.State {
    var rawString: String {
        switch self {
        case .ready: return "ready"
        case .setupRequired: return "setupRequired"
        case .unavailable: return "unavailable"
        }
    }
}

// MARK: - Error Mapping

extension Error {
    func toFlutterError() -> FlutterError {
        if let zsError = self as? ZeroSettleError {
            return zsError.toFlutterError()
        }
        return FlutterError(code: "api_error", message: localizedDescription, details: nil)
    }
}

extension ZeroSettleError {
    func toFlutterError() -> FlutterError {
        switch self {
        case .notConfigured:
            return FlutterError(code: "not_configured", message: errorDescription, details: nil)
        case .invalidPublishableKey:
            return FlutterError(code: "invalid_publishable_key", message: errorDescription, details: nil)
        case .cancelled:
            return FlutterError(code: "cancelled", message: errorDescription, details: nil)
        case .productNotFound(let productId):
            return FlutterError(code: "product_not_found", message: errorDescription, details: productId)
        case .checkoutFailed:
            return FlutterError(code: "checkout_failed", message: errorDescription, details: nil)
        case .transactionVerificationFailed(let detail):
            return FlutterError(code: "transaction_verification_failed", message: errorDescription, details: detail)
        case .apiError:
            return FlutterError(code: "api_error", message: errorDescription, details: nil)
        case .checkoutConfigExpired:
            return FlutterError(code: "checkout_config_expired", message: errorDescription, details: nil)
        case .userIdRequired(let productId):
            return FlutterError(code: "user_id_required", message: errorDescription, details: productId)
        case .webCheckoutDisabledForJurisdiction(let jurisdiction):
            return FlutterError(code: "web_checkout_disabled", message: errorDescription, details: jurisdiction.rawValue)
        case .purchasePending:
            return FlutterError(code: "purchase_pending", message: errorDescription, details: nil)
        case .userNotIdentified:
            return FlutterError(code: "user_not_identified", message: errorDescription, details: nil)
        case .checkoutNotStarted:
            return FlutterError(code: "checkout_not_started", message: errorDescription, details: nil)
        case .applePayUnavailable:
            return FlutterError(code: "apple_pay_unavailable", message: errorDescription, details: nil)
        case .applePaySetupRequired(let autoPresentedSetup):
            // Forward the autoPresentedSetup flag (added in Kit 1.3.4) so the
            // Dart `ZSApplePaySetupRequiredException` can tell adopters whether
            // the SDK already opened the system Wallet (true → presentBuiltInUI
            // path) or not (false → delegateToApp path; app handles setup UX).
            return FlutterError(
                code: "apple_pay_setup_required",
                message: errorDescription,
                details: ["autoPresentedSetup": autoPresentedSetup]
            )
        default:
            return FlutterError(code: "api_error", message: errorDescription, details: nil)
        }
    }
}

// MARK: - Payment Sheet Header

/// Custom native header displayed above the payment WebView in the sheet.
struct PaymentSheetHeader: View {
    let product: ZeroSettleKit.ZSProduct

    var body: some View {
        VStack(spacing: 0) {
            // Product name
            Text(product.displayName)
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            // Description
            if !product.productDescription.isEmpty {
                Text(product.productDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
            }

            // Price comparison
            HStack(spacing: 12) {
                // Web price
                VStack(alignment: .leading, spacing: 2) {
                    Text("Web Price")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(product.webPrice?.formatted ?? "—")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                }

                // App Store price + savings
                if let skPrice = product.storeKitPrice {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("App Store")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(skPrice.formatted)
                            .font(.title2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .strikethrough(color: .secondary.opacity(0.6))
                    }

                    if let pct = product.savingsPercent {
                        Text("Save \(pct)%")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.green, in: Capsule())
                    }
                }

                Spacer()
            }
            .padding(.top, 10)

            // Promotion banner
            if let promo = product.promotion {
                HStack(spacing: 6) {
                    Image(systemName: "tag.fill")
                        .font(.caption)
                    Text(promo.displayName)
                        .font(.caption.weight(.medium))
                    Text(promo.promotionalPrice.formatted)
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                .padding(.top, 10)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
}
