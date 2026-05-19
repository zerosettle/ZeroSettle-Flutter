import 'package:flutter/services.dart';

import 'zerosettle_platform_interface.dart';
import 'errors/zs_exception.dart';
import 'models/entitlement.dart';
import 'models/funnel_event.dart';
import 'models/product_catalog.dart';
import 'models/remote_config.dart';
import 'models/enums.dart';
import 'models/zs_product.dart';
import 'models/zs_transaction.dart';
import 'models/cancel_flow.dart';
import 'models/upgrade_offer.dart';
import 'models/identity.dart';
import 'models/pending_claim.dart';
import 'managers/migration_manager.dart';
import 'managers/offer_manager.dart';

export 'models/price.dart';
export 'models/enums.dart';
export 'models/zs_product.dart';
export 'models/entitlement.dart';
export 'models/zs_transaction.dart';
export 'models/promotion.dart';
export 'models/product_catalog.dart';
export 'models/remote_config.dart';
export 'errors/zs_exception.dart';
export 'widgets/zs_migrate_tip_view.dart';
export 'models/cancel_flow.dart';
export 'models/upgrade_offer.dart';
export 'models/funnel_event.dart';
export 'models/identity.dart';
export 'models/pending_claim.dart';
export 'models/migration_offer.dart';
export 'models/offer.dart';
export 'models/checkout_failure.dart';
export 'models/pending_action.dart';
export 'managers/migration_manager.dart' show MigrationManager;
export 'managers/offer_manager.dart' show OfferManager;

/// Main entry point for the ZeroSettle Flutter SDK.
///
/// Use [ZeroSettle.instance] to access the singleton. Call [configure] before
/// any other methods.
///
/// ```dart
/// await ZeroSettle.instance.configure(publishableKey: 'zs_pk_live_...');
/// final catalog = await ZeroSettle.instance.bootstrap(userId: 'user_123');
/// ```
class ZeroSettle {
  ZeroSettle._();

  static final ZeroSettle instance = ZeroSettle._();

  ZeroSettlePlatform get _platform => ZeroSettlePlatform.instance;

  // -- Configuration --

  /// Override the backend base URL for local development.
  /// Set before calling [configure]. Pass `null` to clear.
  Future<void> setBaseUrlOverride(String? url) {
    return _wrap(() => _platform.setBaseUrlOverride(url));
  }

  /// Configure the SDK with your publishable key.
  /// Must be called before any other methods.
  ///
  /// - [publishableKey]: Your publishable key from the ZeroSettle dashboard.
  /// - [syncStoreKitTransactions]: Whether to listen for and forward native
  ///   StoreKit transactions. Set to `false` if you use RevenueCat.
  /// - [appleMerchantId]: Apple Pay merchant identifier for native pay
  ///   checkout. Required when using the `NativePay` package trait. If null,
  ///   the SDK uses the merchant ID from the backend config (managed mode
  ///   default).
  /// - [preloadCheckout]: Whether to preload checkout sessions for all
  ///   products after [identify] completes. Defaults to `false` on Flutter
  ///   (the iOS Kit default; documented here as the safer Flutter default to
  ///   avoid surprising network/memory behavior for existing adopters).
  ///   When `true`, the first checkout opens instantly with no network delay.
  /// - [maxPreloadedWebViews]: Maximum number of WKWebViews to pre-render in
  ///   the background pool. Each WebView costs ~3-7 MB of memory. Pass
  ///   `null` for no limit (all products), a positive `int` to cap the pool
  ///   size, or `0` to disable WebView pre-rendering entirely (PI caching
  ///   still works).
  /// - [applePaySetupBehavior]: How the SDK reacts when the merchant is
  ///   Apple-Pay-only and the device's Wallet has no supported card. iOS
  ///   only — silently ignored on Android. When omitted the SDK uses its
  ///   default ([ApplePaySetupBehavior.presentBuiltInUI]).
  /// - [playLicenseKey]: PEM-encoded RSA public key from the Play Console
  ///   used to verify Play Billing purchase signatures locally before
  ///   syncing to the backend. Android-only — silently ignored on iOS.
  ///   When `null` (default), signature verification is delegated to the
  ///   backend.
  /// - [syncPlayPurchases]: When `true` (default), the Android SDK
  ///   installs a Play Billing purchase listener and forwards purchases
  ///   to the backend. Set to `false` if your app drives Play Billing
  ///   directly (e.g. via a different library). Android-only — silently
  ///   ignored on iOS.
  /// - [strictAck]: When `true`, the Android SDK never acknowledges a
  ///   Play purchase until the backend confirms the sync (no
  ///   fire-and-forget). Defaults to `false` (acknowledge on receipt).
  ///   Android-only — silently ignored on iOS.
  Future<void> configure({
    required String publishableKey,
    bool syncStoreKitTransactions = true,
    String? appleMerchantId,
    bool preloadCheckout = false,
    int? maxPreloadedWebViews,
    ApplePaySetupBehavior? applePaySetupBehavior,
    String? playLicenseKey,
    bool syncPlayPurchases = true,
    bool strictAck = false,
  }) {
    return _wrap(() => _platform.configure(
          publishableKey: publishableKey,
          syncStoreKitTransactions: syncStoreKitTransactions,
          appleMerchantId: appleMerchantId,
          preloadCheckout: preloadCheckout,
          maxPreloadedWebViews: maxPreloadedWebViews,
          applePaySetupBehavior: applePaySetupBehavior?.rawValue,
          playLicenseKey: playLicenseKey,
          syncPlayPurchases: syncPlayPurchases,
          strictAck: strictAck,
        ));
  }

  // -- Bootstrap --

  /// Fetch products and restore entitlements.
  ///
  /// Convenience method equivalent to calling [fetchProducts] and
  /// [restoreEntitlements] in sequence.
  ///
  /// - [userId]: Your app's user identifier
  @Deprecated('Use identify(Identity.user(id: ..., name: ..., email: ...)). Removed in zerosettle 2.0.')
  Future<ProductCatalog> bootstrap({required String userId}) {
    return _wrap(() async {
      final map = await _platform.bootstrap(userId: userId);
      return ProductCatalog.fromMap(map);
    });
  }

  /// Identify the current session. Mirrors native `identify(_:)`.
  ///
  /// Returns the product catalog for [Identity.user] / [Identity.anonymous],
  /// or `null` for [Identity.deferred] (no fetch performed yet).
  Future<ProductCatalog?> identify(Identity identity) {
    return _wrap(() async {
      final m = identity.toMap();
      final map = await _platform.identify(
        type: m['type'] as String,
        id: m['id'] as String?,
        name: m['name'] as String?,
        email: m['email'] as String?,
      );
      return map == null ? null : ProductCatalog.fromMap(map);
    });
  }

  /// Clear user-scoped state. Call when the user logs out of your app.
  Future<void> logout() => _wrap(() => _platform.logout());

  /// Update the Stripe customer's name/email metadata.
  Future<void> setCustomer({String? name, String? email}) =>
      _wrap(() => _platform.setCustomer(name: name, email: email));

  /// Transfer a StoreKit-originated entitlement to the currently identified user.
  /// Replaces the deprecated `claimEntitlement`.
  ///
  /// **iOS-only.** On Android the bridge returns `not_implemented` — use
  /// [transferPlayOwnershipToCurrentUser] for the Play Billing equivalent.
  Future<void> transferStoreKitOwnershipToCurrentUser({required String productId}) =>
      _wrap(() => _platform.transferStoreKitOwnershipToCurrentUser(productId: productId));

  /// Transfer a Google Play purchase's ownership to the currently-identified
  /// user. Use after an [identify] call when you want to claim a Play
  /// purchase that was previously made under a different ZeroSettle account.
  ///
  /// Both [productId] and [originalTransactionId] are required — the Play
  /// API needs the purchase token (carried as `originalTransactionId`) in
  /// addition to the product reference to resolve which purchase is being
  /// transferred. Typical usage: render a [PendingClaim], then call this
  /// with the claim's `productId` + `originalTransactionId`.
  ///
  /// **Android-only.** On iOS the bridge returns `not_implemented` — use
  /// [transferStoreKitOwnershipToCurrentUser] for the StoreKit equivalent.
  Future<void> transferPlayOwnershipToCurrentUser({
    required String productId,
    required String originalTransactionId,
  }) =>
      _wrap(() => _platform.transferPlayOwnershipToCurrentUser(
            productId: productId,
            originalTransactionId: originalTransactionId,
          ));

  /// Quick check: does the user have an active entitlement for [productId]?
  Future<bool> hasActiveEntitlement({required String productId}) =>
      _wrap(() => _platform.hasActiveEntitlement(productId: productId));

  /// Look up a single cached product by ID. Returns `null` if not in the catalog.
  Future<Product?> product({required String productId}) {
    return _wrap(() async {
      final map = await _platform.product(productId: productId);
      return map == null ? null : Product.fromMap(map);
    });
  }


  // -- Products --

  /// Fetch the product catalog from ZeroSettle.
  Future<ProductCatalog> fetchProducts({String? userId}) {
    return _wrap(() async {
      final map = await _platform.fetchProducts(userId: userId);
      return ProductCatalog.fromMap(map);
    });
  }

  /// Get the cached products from the last fetch.
  Future<List<Product>> getProducts() {
    return _wrap(() async {
      final list = await _platform.getProducts();
      return list.map((e) => Product.fromMap(e)).toList();
    });
  }

  // -- Payment Sheet --

  /// Present the payment sheet for a product.
  ///
  /// Returns a [CheckoutTransaction] on successful payment.
  /// Throws [ZSCancelledException] if the user dismisses the sheet.
  /// Throws [ZSCheckoutFailedException] if the payment fails.
  ///
  /// - [productId]: The product to purchase
  /// - [userId]: Optional user identifier
  /// - [freeTrialDays]: Number of free trial days to grant on web billing subscriptions (defaults to 0)
  /// - [dismissible]: Whether the sheet can be dismissed by the user
  Future<CheckoutTransaction> presentPaymentSheet({
    required String productId,
    String? userId,
    bool dismissible = true,
  }) {
    return _wrap(() async {
      final map = await _platform.presentPaymentSheet(
        productId: productId,
        userId: userId,
        dismissible: dismissible,
      );
      return CheckoutTransaction.fromMap(map);
    });
  }

  /// Preload the payment sheet for faster presentation.
  ///
  /// - [productId]: The product to preload
  /// - [userId]: Optional user identifier
  /// - [freeTrialDays]: Number of free trial days to grant on web billing subscriptions (defaults to 0)
  Future<void> preloadPaymentSheet({required String productId, String? userId}) {
    return _wrap(() => _platform.preloadPaymentSheet(
          productId: productId,
          userId: userId,
        ));
  }

  /// Warm up the payment sheet (preload + cache).
  ///
  /// - [productId]: The product to warm up
  /// - [userId]: Optional user identifier
  /// - [freeTrialDays]: Number of free trial days to grant on web billing subscriptions (defaults to 0)
  Future<void> warmUpPaymentSheet({required String productId, String? userId}) {
    return _wrap(() => _platform.warmUpPaymentSheet(
          productId: productId,
          userId: userId,
        ));
  }

  // -- Purchase (1.3.0) --

  /// Unified purchase entry point. Routes to web checkout (Stripe) or native
  /// StoreKit depending on jurisdiction, remote config, and the per-call
  /// [presentation] override.
  ///
  /// Returns a [CheckoutTransaction] on successful payment.
  /// Throws a [ZeroSettleException] on cancellation, failure, or when web
  /// checkout is disabled for the user's jurisdiction.
  ///
  /// Identity comes from the prior [identify] call; this method does not take
  /// a `userId` parameter.
  ///
  /// - [productId]: The product identifier to purchase.
  /// - [presentation]: Optional override for the checkout sheet style (e.g.
  ///   `CheckoutType.nativePay` to force Apple Pay). When omitted the SDK
  ///   uses the global default from remote config.
  Future<CheckoutTransaction> purchase({
    required String productId,
    CheckoutType? presentation,
  }) {
    return _wrap(() async {
      final map = await _platform.purchase(
        productId: productId,
        presentation: presentation?.rawValue,
      );
      return CheckoutTransaction.fromMap(map);
    });
  }

  /// Force a StoreKit (App Store IAP) purchase, bypassing web checkout. Use
  /// for jurisdictions where web checkout is disabled or when the app wants
  /// explicit control over the purchase channel.
  ///
  /// Returns a [CheckoutTransaction] populated from the underlying
  /// `StoreKit.Transaction`. Note: `amountCents` and `currency` may be `null`
  /// because Apple's `StoreKit.Transaction` doesn't carry localized price
  /// information directly — read it from the `Product` catalog if needed.
  ///
  /// Identity comes from the prior [identify] call; this method does not take
  /// a `userId` parameter.
  ///
  /// Throws a [ZeroSettleException] on cancellation, verification failure, or
  /// when no StoreKit product is available for [productId].
  ///
  /// **iOS-only.** On Android the bridge returns `not_implemented` — use
  /// [purchaseViaPlayBilling] for the Play Billing equivalent.
  Future<CheckoutTransaction> purchaseViaStoreKit({required String productId}) {
    return _wrap(() async {
      final map = await _platform.purchaseViaStoreKit(productId: productId);
      return CheckoutTransaction.fromMap(map);
    });
  }

  /// Purchase via Google Play Billing (Android-specific).
  ///
  /// Routes the purchase through the Google Play Billing dialog and returns
  /// the resulting [CheckoutTransaction] (`source == EntitlementSource.playStore`).
  /// Use this when the developer opts for Play Store distribution alongside
  /// (or instead of) ZeroSettle's web-checkout route on Android.
  ///
  /// Requires `ZeroSettleConfig.syncPlayPurchases = true` on the Android SDK
  /// side; the configure-time flag is what wires the Play billing client to
  /// the SDK. Identity comes from the prior [identify] call.
  ///
  /// **Android-only.** On iOS the bridge returns `not_implemented` — use
  /// [purchaseViaStoreKit] for the StoreKit equivalent.
  ///
  /// Throws a [ZeroSettleException] on cancellation, billing-not-supported,
  /// network failure, or when no Play product is available for [productId].
  Future<CheckoutTransaction> purchaseViaPlayBilling({required String productId}) {
    return _wrap(() async {
      final map = await _platform.purchaseViaPlayBilling(productId: productId);
      return CheckoutTransaction.fromMap(map);
    });
  }

  // -- Entitlements --

  /// Restore entitlements from both web checkout and StoreKit.
  ///
  /// **1.3.0**: Call [identify] first; then call without `userId`. Passing
  /// `userId` is deprecated and will be removed in zerosettle 2.0.
  ///
  /// Merges entitlements from both StoreKit (local) and web checkout
  /// (backend). Throws [ZSUserNotIdentifiedException] when called without
  /// `userId` if no user is identified.
  Future<List<Entitlement>> restoreEntitlements({
    @Deprecated('Call identify() once, then use the userId-less form. Removed in zerosettle 2.0.')
    String? userId,
  }) {
    return _wrap(() async {
      final list = userId == null
          ? await _platform.restoreEntitlementsForCurrentUser()
          : await _platform.restoreEntitlements(userId: userId);
      return list.map((e) => Entitlement.fromMap(e)).toList();
    });
  }

  /// Get the current cached entitlements.
  Future<List<Entitlement>> getEntitlements() {
    return _wrap(() async {
      final list = await _platform.getEntitlements();
      return list.map((e) => Entitlement.fromMap(e)).toList();
    });
  }

  /// Stream of entitlement updates from the native SDK.
  Stream<List<Entitlement>> get entitlementUpdates {
    return _platform.entitlementUpdates.map(
      (list) => list.map((e) => Entitlement.fromMap(e)).toList(),
    );
  }

  /// Stream of product catalog updates from the native SDK. Mirrors the
  /// native SDK's reactive `products` observable — emits the current catalog
  /// on listen and every subsequent change. Use this instead of polling
  /// [getProducts] when you want to react to catalog mutations
  /// (e.g. server-driven price changes or A/B-tested product visibility).
  Stream<List<Product>> get productsUpdates {
    return _platform.productsUpdates.map(
      (list) => list.map((e) => Product.fromMap(e)).toList(),
    );
  }

  /// Stream of the currently-identified user id, or `null` when no user is
  /// identified (initial state and after [logout]). Emits the current value
  /// on listen and every subsequent change. Convenience for binding
  /// signed-in/out UI to a single stream rather than polling
  /// [getCurrentUserId] after each [identify] / [logout] call.
  Stream<String?> get currentUserIdUpdates => _platform.currentUserIdUpdates;

  /// Stream of the "is a web checkout in-flight?" flag. Emits the current
  /// value on listen, then `true` when [purchase] enters the web flow and
  /// `false` when it returns (success, cancel, or failure). Useful for
  /// driving a loading overlay without juggling Future state in your widget.
  Stream<bool> get pendingCheckoutUpdates =>
      _platform.pendingCheckoutUpdates;

  /// Stream of the "has [identify] completed successfully?" flag. Emits the
  /// current value on listen, then `true` on first successful identify and
  /// `false` on [logout]. Use this to gate post-identify UI (catalog,
  /// entitlements, etc.).
  Stream<bool> get isBootstrappedUpdates =>
      _platform.isBootstrappedUpdates;

  // -- Transaction History --

  /// Fetch the full transaction history for the currently identified user.
  ///
  /// Unlike [restoreEntitlements] which only returns **active** entitlements,
  /// this method returns all transactions regardless of status — including
  /// consumed consumables, expired subscriptions, refunds, and failed
  /// transactions.
  ///
  /// **1.3.0**: Call [identify] first; then call without `userId`. Passing
  /// `userId` is deprecated and will be removed in zerosettle 2.0.
  Future<List<CheckoutTransaction>> fetchTransactionHistory({
    @Deprecated('Call identify() once, then use the userId-less form. Removed in zerosettle 2.0.')
    String? userId,
  }) {
    return _wrap(() async {
      final list = userId == null
          ? await _platform.fetchTransactionHistoryForCurrentUser()
          : await _platform.fetchTransactionHistory(userId: userId);
      return list.map((e) => CheckoutTransaction.fromMap(e)).toList();
    });
  }

  // -- Subscription Management --

  /// Open the Stripe customer portal for subscription management.
  /// **Removed in ZeroSettleKit 1.x.** The Dart facade is kept for source
  /// compatibility but the iOS bridge throws `not_implemented`. Use
  /// [presentCancelFlow] (or the headless [cancelSubscription]) for
  /// subscription retention / cancellation flows. Removed in zerosettle 2.0.
  @Deprecated('Removed in ZeroSettleKit 1.x. Use presentCancelFlow() (or headless cancelSubscription()). Removed in zerosettle 2.0.')
  Future<void> openCustomerPortal({required String userId}) {
    return _wrap(() => _platform.openCustomerPortal(userId: userId));
  }

  /// **Removed in ZeroSettleKit 1.x.** The Dart facade is kept for source
  /// compatibility but the iOS bridge throws `not_implemented`. Use
  /// [presentCancelFlow] (or the headless [cancelSubscription]) for
  /// subscription retention / cancellation flows. Removed in zerosettle 2.0.
  @Deprecated('Removed in ZeroSettleKit 1.x. Use presentCancelFlow() (or headless cancelSubscription()). Removed in zerosettle 2.0.')
  Future<void> showManageSubscription({required String userId}) {
    return _wrap(() => _platform.showManageSubscription(userId: userId));
  }

  // -- Universal Links --

  /// Handle a universal link callback from web checkout.
  /// Returns `true` if the URL was handled by ZeroSettle.
  Future<bool> handleUniversalLink(String url) {
    return _wrap(() => _platform.handleUniversalLink(url));
  }

  // -- State Queries --

  /// The native SDK version string (e.g. `"1.4.0"`).
  Future<String> getSdkVersion() => _wrap(() => _platform.getSdkVersion());

  /// Whether the SDK has been configured.
  Future<bool> getIsConfigured() {
    return _wrap(() => _platform.getIsConfigured());
  }

  /// Whether a checkout is currently in progress.
  Future<bool> getPendingCheckout() {
    return _wrap(() => _platform.getPendingCheckout());
  }

  /// Get the remote configuration from the last fetch.
  Future<RemoteConfig?> getRemoteConfig() {
    return _wrap(() async {
      final map = await _platform.getRemoteConfig();
      return map != null ? RemoteConfig.fromMap(map) : null;
    });
  }

  /// Get the detected jurisdiction.
  Future<Jurisdiction?> getDetectedJurisdiction() {
    return _wrap(() async {
      final raw = await _platform.getDetectedJurisdiction();
      return raw != null ? Jurisdiction.fromRawValue(raw) : null;
    });
  }

  /// The currently identified user ID, or `null` if no user is identified.
  ///
  /// Returns `null` when:
  /// - [identify] has not yet been called (or [logout] has cleared state),
  /// - the most recent [identify] used [Identity.anonymous] (the SDK
  ///   generates an anonymous session id internally, but it is not
  ///   surfaced to Flutter — use [Identity.user] if you need to read the
  ///   identifier back), or
  /// - the most recent [identify] used [Identity.deferred].
  ///
  /// Use this for conditional UI ("Logged in as ...") or to gate user-scoped
  /// flows.
  Future<String?> getCurrentUserId() {
    return _wrap(() => _platform.getCurrentUserId());
  }

  /// Whether [identify] (or the deprecated bootstrap path) has completed
  /// and entitlements have been fetched.
  ///
  /// Adopters can poll this to know when the SDK is ready for purchase /
  /// entitlement-gated features after a fresh app launch.
  Future<bool> getIsBootstrapped() {
    return _wrap(() => _platform.getIsBootstrapped());
  }

  // -- Pending Claims (1.3.0) --

  /// Returns the list of [PendingClaim]s currently surfaced by the SDK —
  /// StoreKit purchases the current user could claim from a different
  /// ZeroSettle account.
  ///
  /// To act on a claim, render the appropriate UX and call
  /// [transferStoreKitOwnershipToCurrentUser] with the [PendingClaim]'s
  /// `productId`. The SDK never auto-claims.
  Future<List<PendingClaim>> getPendingClaims() {
    return _wrap(() async {
      final list = await _platform.getPendingClaims();
      return list.map((e) => PendingClaim.fromMap(e)).toList();
    });
  }

  /// Stream of [PendingClaim] list snapshots, emitting whenever the SDK's
  /// pending-claim list mutates (claim added or removed).
  Stream<List<PendingClaim>> get pendingClaimsUpdates {
    return _platform.pendingClaimsUpdates.map(
      (list) => list.map((e) => PendingClaim.fromMap(e)).toList(),
    );
  }

  // -- StoreKit Helpers (1.3.0) --

  /// Returns the recommended `appAccountToken` to use when calling StoreKit
  /// directly (e.g. `StoreKit.Product.purchase(options: [.appAccountToken(...)])`).
  ///
  /// The token is derived deterministically from the currently identified
  /// user ID via UUIDv5, so non-UUID user IDs (Firebase, Auth0, etc.) hash
  /// correctly. Returned as a UUID string.
  ///
  /// Throws a [ZeroSettleException] (`user_not_identified`) if [identify]
  /// hasn't been called.
  Future<String> recommendedAppAccountToken() {
    return _wrap(() => _platform.recommendedAppAccountToken());
  }

  // -- Apple Pay (1.3.2) --

  /// Launches the system Wallet setup flow so the user can add a card for
  /// Apple Pay. Mirrors `ZeroSettle.shared.presentApplePaySetup()` on iOS.
  ///
  /// Use this from a [ZSApplePaySetupRequiredException] handler, or from a
  /// banner CTA when [ApplePayAvailabilityState.setupRequired] is observed
  /// via [applePayStateUpdates].
  ///
  /// On Android this is a no-op stub (returns `notImplemented` from the
  /// platform); the surrounding facade swallows it silently as a non-error.
  Future<void> presentApplePaySetup() {
    return _wrap(() => _platform.presentApplePaySetup());
  }

  /// Whether the SDK is currently treating this merchant as Apple-Pay-only.
  /// Drives banner CTA swap and the imperative-checkout pre-flight gate on
  /// iOS. Mirrors `ZeroSettle.shared.isApplePayOnly`.
  Future<bool> getIsApplePayOnly() {
    return _wrap(() => _platform.getIsApplePayOnly());
  }

  /// Reads the current [ApplePayAvailabilityState] once. Mirrors
  /// `ZeroSettle.shared.applePayAvailability.state` on iOS.
  Future<ApplePayAvailabilityState> getApplePayState() {
    return _wrap(() async {
      final raw = await _platform.getApplePayState();
      return ApplePayAvailabilityState.fromRawValue(raw);
    });
  }

  /// Hot stream of [ApplePayAvailabilityState] changes from the iOS Kit's
  /// `applePayAvailability.statePublisher`. Emits the current state on
  /// subscription so late subscribers don't have to wait.
  Stream<ApplePayAvailabilityState> get applePayStateUpdates {
    return _platform.applePayStateUpdates
        .map(ApplePayAvailabilityState.fromRawValue);
  }

  // -- UCB (User Choice Billing) --

  /// Whether User Choice Billing is active for this tenant/market.
  /// Always `false` on iOS (UCB is an Android/Play concept).
  Future<bool> getIsUcbEnabled() => _wrap(() => _platform.getIsUcbEnabled());

  /// Reactive [getIsUcbEnabled]. Emits `false` once on iOS.
  Stream<bool> get isUcbEnabledUpdates => _platform.isUcbEnabledUpdates;

  // -- Web Checkout --

  /// Cancels an in-flight web checkout. No-op on iOS.
  Future<void> releasePendingCheckout() =>
      _wrap(() => _platform.releasePendingCheckout());

  // -- Cancel Flow --

  /// Present the cancel flow questionnaire for a subscription cancellation.
  ///
  /// Fetches the cancel flow configuration from the backend via the native
  /// SDK, then presents a native questionnaire sheet. If the flow is disabled
  /// or has no questions, returns [CancelFlowCancelled] immediately.
  ///
  /// **1.3.0**: Call [identify] first; then call without `userId`. Passing
  /// `userId` is deprecated and will be removed in zerosettle 2.0.
  ///
  /// - [productId]: The product the user wants to cancel
  /// - [userId]: (Deprecated) Your app's user identifier
  Future<CancelFlowResult> presentCancelFlow({
    required String productId,
    @Deprecated('Call identify() once, then use the userId-less form. Removed in zerosettle 2.0.')
    String? userId,
  }) {
    return _wrap(() async {
      final String? resultString;
      if (userId == null) {
        resultString = await _platform.presentCancelFlowForCurrentUser(productId: productId);
      } else {
        resultString = await _platform.presentCancelFlow(productId: productId, userId: userId);
      }
      return CancelFlowResult.fromRawValue(resultString ?? 'dismissed');
    });
  }

  /// Fetch the cancel flow configuration without presenting any UI.
  ///
  /// Use this for headless/custom cancel flow implementations.
  ///
  /// - [userId]: Optional user ID for A/B experiment targeting
  Future<CancelFlowConfig> fetchCancelFlowConfig({String? userId}) {
    return _wrap(() async {
      final map = await _platform.fetchCancelFlowConfig(userId: userId);
      return CancelFlowConfig.fromMap(map);
    });
  }

  /// Pause a subscription.
  ///
  /// Returns the resume date as a [DateTime] if the backend provides one,
  /// or `null` if no specific resume date was set.
  ///
  /// **1.3.0**: Call [identify] first; then call without `userId`. Passing
  /// `userId` is deprecated and will be removed in zerosettle 2.0. The
  /// `pauseOptionId` parameter has been replaced by `pauseDurationDays` per
  /// Kit 1.3.0; callers should pass `pauseDurationDays` instead.
  ///
  /// - [productId]: The product to pause
  /// - [pauseDurationDays]: The number of days to pause for. `null` lets the
  ///   backend choose the default.
  /// - [userId]: (Deprecated) Your app's user identifier
  /// - [pauseOptionId]: (Deprecated) The legacy pause-option ID; passed as
  ///   `pauseDurationDays` to the bridge.
  Future<DateTime?> pauseSubscription({
    required String productId,
    int? pauseDurationDays,
    @Deprecated('Call identify() once, then use the userId-less form. Removed in zerosettle 2.0.')
    String? userId,
    @Deprecated('Use pauseDurationDays. Removed in zerosettle 2.0.')
    int? pauseOptionId,
  }) {
    // Precedence: `pauseDurationDays` (new) wins over `pauseOptionId` (legacy).
    final int? duration = pauseDurationDays ?? pauseOptionId;
    return _wrap(() async {
      final String? iso;
      if (userId == null) {
        iso = await _platform.pauseSubscriptionForCurrentUser(
          productId: productId,
          pauseDurationDays: duration,
        );
      } else {
        // Legacy method channel still requires a non-null pauseOptionId
        // (its arg name predates the 1.3.0 rename); pass duration through.
        iso = await _platform.pauseSubscription(
          productId: productId,
          userId: userId,
          pauseOptionId: duration ?? 0,
        );
      }
      return iso != null ? DateTime.parse(iso) : null;
    });
  }

  /// Resume a paused subscription.
  ///
  /// **1.3.0**: Call [identify] first; then call without `userId`. Passing
  /// `userId` is deprecated and will be removed in zerosettle 2.0.
  ///
  /// - [productId]: The product to resume
  /// - [userId]: (Deprecated) Your app's user identifier
  Future<void> resumeSubscription({
    required String productId,
    @Deprecated('Call identify() once, then use the userId-less form. Removed in zerosettle 2.0.')
    String? userId,
  }) {
    return _wrap(() {
      if (userId == null) {
        return _platform.resumeSubscriptionForCurrentUser(productId: productId);
      }
      return _platform.resumeSubscription(productId: productId, userId: userId);
    });
  }

  // -- Cancel Flow (Headless) --

  /// Accept the save offer for a subscription about to be cancelled.
  ///
  /// Returns a [CancelFlowSaveOfferResult] with the discount details.
  ///
  /// **1.3.0**: Call [identify] first; then call without `userId`. Passing
  /// `userId` is deprecated and will be removed in zerosettle 2.0.
  ///
  /// - [productId]: The product the offer applies to
  /// - [userId]: (Deprecated) Your app's user identifier
  Future<CancelFlowSaveOfferResult> acceptSaveOffer({
    required String productId,
    @Deprecated('Call identify() once, then use the userId-less form. Removed in zerosettle 2.0.')
    String? userId,
  }) {
    return _wrap(() async {
      final map = userId == null
          ? await _platform.acceptSaveOfferForCurrentUser(productId: productId)
          : await _platform.acceptSaveOffer(productId: productId, userId: userId);
      return CancelFlowSaveOfferResult.fromMap(map);
    });
  }

  /// Submit the complete cancel flow response for analytics and processing.
  ///
  /// - [response]: The cancel flow response containing answers and outcome
  Future<void> submitCancelFlowResponse(CancelFlowResponse response) {
    return _wrap(() => _platform.submitCancelFlowResponse(response.toMap()));
  }

  /// Get the cancel flow configuration from the cached config.
  ///
  /// Returns `null` if no config is available.
  Future<CancelFlowConfig?> getCancelFlowConfig() {
    return _wrap(() async {
      final map = await _platform.getCancelFlowConfig();
      return map != null ? CancelFlowConfig.fromMap(map) : null;
    });
  }

  /// Cancel a subscription immediately or at end of period.
  ///
  /// **1.3.0**: Call [identify] first; then call without `userId`. Passing
  /// `userId` is deprecated and will be removed in zerosettle 2.0.
  ///
  /// - [productId]: The product to cancel
  /// - [immediate]: Whether to cancel immediately (default: false, cancels at period end)
  /// - [userId]: (Deprecated) Your app's user identifier
  Future<void> cancelSubscription({
    required String productId,
    bool immediate = false,
    @Deprecated('Call identify() once, then use the userId-less form. Removed in zerosettle 2.0.')
    String? userId,
  }) {
    return _wrap(() {
      if (userId == null) {
        return _platform.cancelSubscriptionForCurrentUser(
          productId: productId,
          immediate: immediate,
        );
      }
      return _platform.cancelSubscription(
        productId: productId,
        userId: userId,
        immediate: immediate,
      );
    });
  }

  // -- Upgrade Offer --

  /// Present the upgrade offer sheet for a subscription upgrade.
  ///
  /// Fetches the upgrade offer configuration from the backend via the native
  /// SDK, then presents a native upgrade sheet. If no upgrade is available,
  /// returns [UpgradeOfferDismissed] immediately.
  ///
  /// **1.3.0**: Call [identify] first; then call without `userId`. Passing
  /// `userId` is deprecated and will be removed in zerosettle 2.0.
  ///
  /// - [productId]: The current product the user holds
  /// - [userId]: (Deprecated) Your app's user identifier
  Future<UpgradeOfferResult> presentUpgradeOffer({
    String? productId,
    @Deprecated('Call identify() once, then use the userId-less form. Removed in zerosettle 2.0.')
    String? userId,
  }) {
    return _wrap(() async {
      final resultString = userId == null
          ? await _platform.presentUpgradeOfferForCurrentUser(productId: productId)
          : await _platform.presentUpgradeOffer(productId: productId, userId: userId);
      return UpgradeOfferResult.fromRawValue(resultString);
    });
  }

  /// Fetch the upgrade offer configuration without presenting any UI.
  ///
  /// Use this for headless/custom upgrade offer implementations.
  ///
  /// **1.3.0**: Call [identify] first; then call without `userId`. Passing
  /// `userId` is deprecated and will be removed in zerosettle 2.0.
  ///
  /// - [productId]: The current product to check upgrades for
  /// - [userId]: (Deprecated) Your app's user identifier
  Future<UpgradeOfferConfig> fetchUpgradeOfferConfig({
    String? productId,
    @Deprecated('Call identify() once, then use the userId-less form. Removed in zerosettle 2.0.')
    String? userId,
  }) {
    return _wrap(() async {
      final map = userId == null
          ? await _platform.fetchUpgradeOfferConfigForCurrentUser(productId: productId)
          : await _platform.fetchUpgradeOfferConfig(productId: productId, userId: userId);
      return UpgradeOfferConfig.fromMap(map);
    });
  }


  // -- Checkout Events --

  /// Stream of checkout lifecycle events from the native SDK.
  Stream<Map<String, dynamic>> get checkoutEvents {
    return _platform.checkoutEvents;
  }

  // -- Save the Sale --

  /// Present the save-the-sale retention sheet.
  ///
  /// Shows two options: Pause Account and Stay & Save 40%.
  /// Returns the user's choice as a [ZSSaveTheSaleResult].
  Future<ZSSaveTheSaleResult> presentSaveTheSaleSheet() {
    return _wrap(() async {
      final raw = await _platform.presentSaveTheSaleSheet();
      return ZSSaveTheSaleResult.fromRawValue(raw);
    });
  }

  // -- Migration Tracking --

  /// Track a successful migration conversion.
  ///
  /// Call this after a user successfully completes a web checkout purchase
  /// as part of a migration campaign (switching from native store billing to
  /// web checkout).
  ///
  /// **1.3.0**: Call [identify] first; then call without `userId`. Passing
  /// `userId` is deprecated and will be removed in zerosettle 2.0.
  ///
  /// - [userId]: (Deprecated) Your app's user identifier
  Future<void> trackMigrationConversion({
    @Deprecated('Call identify() once, then use the userId-less form. Removed in zerosettle 2.0.')
    String? userId,
  }) {
    return _wrap(() {
      if (userId == null) {
        return _platform.trackMigrationConversionForCurrentUser();
      }
      return _platform.trackMigrationConversion(userId: userId);
    });
  }

  // -- Migration Manager (Headless) --

  /// Returns a [MigrationManager] handle bound to the currently-identified
  /// user and the optional [stripeCustomerId]. The iOS-side manager is
  /// cached; calling this twice returns handles wired to the same underlying
  /// state.
  ///
  /// Call [MigrationManager.dispose] when your widget tears down to release
  /// the per-handle channel subscriptions.
  Future<MigrationManager> migrationManager({String? stripeCustomerId}) {
    return _wrap(() async {
      final id = await _platform.resolveMigrationManagerHandle(
        stripeCustomerId: stripeCustomerId,
      );
      return MigrationManager.fromHandleId(id);
    });
  }

  // -- Offer Manager (Headless) --

  /// Returns an [OfferManager] handle bound to the currently-identified
  /// user and the optional [stripeCustomerId]. The iOS-side manager is
  /// cached; calling this twice returns handles wired to the same
  /// underlying state.
  ///
  /// `OfferManager` covers both migration (StoreKit → web) and upgrade
  /// (storekit_to_web, web_to_web) flows — the server picks which one
  /// to render via the `offer` field on the products response.
  ///
  /// Call [OfferManager.dispose] when your widget tears down to release
  /// the per-handle channel subscriptions.
  Future<OfferManager> offerManager({String? stripeCustomerId}) {
    return _wrap(() async {
      final id = await _platform.resolveOfferManagerHandle(
        stripeCustomerId: stripeCustomerId,
      );
      return OfferManager.fromHandleId(id);
    });
  }

  // -- Migration Tip --

  /// Resets the persisted dismissal state for the migration tip view.
  /// After calling this, the migration tip will appear again for eligible users.
  ///
  /// This is primarily useful during development and testing.
  Future<void> resetMigrateTipState() {
    return _wrap(() => _platform.resetMigrateTipState());
  }

  // -- Funnel Analytics --

  /// Fire-and-forget analytics event for paywall and checkout funnel tracking.
  ///
  /// Sends the event to the ZeroSettle backend asynchronously via the native
  /// SDK. Errors are silently swallowed and never thrown.
  ///
  /// - [type]: The funnel event type
  /// - [productId]: The product identifier associated with this event
  /// - [screenName]: Optional screen name where the event occurred
  /// - [metadata]: Optional key-value pairs for additional context
  static Future<void> trackEvent(
    FunnelEventType type, {
    required String productId,
    String? screenName,
    Map<String, String>? metadata,
  }) async {
    try {
      await ZeroSettlePlatform.instance.trackEvent(
        eventType: type.value,
        productId: productId,
        screenName: screenName,
        metadata: metadata,
      );
    } catch (_) {
      // Silent failure — fire-and-forget
    }
  }

  // -- Error wrapping --

  Future<T> _wrap<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on PlatformException catch (e) {
      throw ZeroSettleException.fromPlatformException(e);
    }
  }
}
