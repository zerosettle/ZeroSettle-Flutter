import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'zerosettle_method_channel.dart';

abstract class ZeroSettlePlatform extends PlatformInterface {
  ZeroSettlePlatform() : super(token: _token);

  static final Object _token = Object();

  static ZeroSettlePlatform _instance = MethodChannelZeroSettle();

  static ZeroSettlePlatform get instance => _instance;

  static set instance(ZeroSettlePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  // -- Configuration --

  Future<void> configure({
    required String publishableKey,
    bool syncStoreKitTransactions = true,
    String? appleMerchantId,
    bool preloadCheckout = false,
    int? maxPreloadedWebViews,
  }) {
    throw UnimplementedError('configure() has not been implemented.');
  }

  // -- Bootstrap --

  Future<Map<String, dynamic>> bootstrap({required String userId}) {
    throw UnimplementedError('bootstrap() has not been implemented.');
  }

  // -- Identity --

  Future<Map<String, dynamic>?> identify({
    required String type,
    String? id,
    String? name,
    String? email,
  }) {
    throw UnimplementedError('identify() has not been implemented.');
  }

  Future<void> logout() {
    throw UnimplementedError('logout() has not been implemented.');
  }

  Future<void> setCustomer({String? name, String? email}) {
    throw UnimplementedError('setCustomer() has not been implemented.');
  }

  Future<void> transferStoreKitOwnershipToCurrentUser({required String productId}) {
    throw UnimplementedError('transferStoreKitOwnershipToCurrentUser() has not been implemented.');
  }

  Future<bool> hasActiveEntitlement({required String productId}) {
    throw UnimplementedError('hasActiveEntitlement() has not been implemented.');
  }

  Future<Map<String, dynamic>?> product({required String productId}) {
    throw UnimplementedError('product() has not been implemented.');
  }

  // -- Products --

  Future<Map<String, dynamic>> fetchProducts({String? userId}) {
    throw UnimplementedError('fetchProducts() has not been implemented.');
  }

  Future<List<Map<String, dynamic>>> getProducts() {
    throw UnimplementedError('getProducts() has not been implemented.');
  }

  // -- Payment Sheet --

  Future<Map<String, dynamic>> presentPaymentSheet({
    required String productId,
    String? userId,
    bool dismissible = true,
  }) {
    throw UnimplementedError('presentPaymentSheet() has not been implemented.');
  }

  // -- Purchase (1.3.0) --

  /// Unified purchase entry point. Routes to web checkout or StoreKit based
  /// on jurisdiction + remote config; can be overridden per-call by
  /// `presentation`.
  Future<Map<String, dynamic>> purchase({
    required String productId,
    String? presentation,
  }) {
    throw UnimplementedError('purchase() has not been implemented.');
  }

  /// Force a StoreKit (App Store IAP) purchase, bypassing web checkout.
  Future<Map<String, dynamic>> purchaseViaStoreKit({
    required String productId,
  }) {
    throw UnimplementedError('purchaseViaStoreKit() has not been implemented.');
  }

  Future<void> preloadPaymentSheet({required String productId, String? userId}) {
    throw UnimplementedError('preloadPaymentSheet() has not been implemented.');
  }

  Future<void> warmUpPaymentSheet({required String productId, String? userId}) {
    throw UnimplementedError('warmUpPaymentSheet() has not been implemented.');
  }

  // -- Entitlements --

  Future<List<Map<String, dynamic>>> restoreEntitlements({required String userId}) {
    throw UnimplementedError('restoreEntitlements() has not been implemented.');
  }

  /// 1.3.0 no-userId overload — uses the currently identified user.
  Future<List<Map<String, dynamic>>> restoreEntitlementsForCurrentUser() {
    throw UnimplementedError('restoreEntitlementsForCurrentUser() has not been implemented.');
  }

  Future<List<Map<String, dynamic>>> getEntitlements() {
    throw UnimplementedError('getEntitlements() has not been implemented.');
  }

  // -- Subscription Management --

  Future<void> openCustomerPortal({required String userId}) {
    throw UnimplementedError('openCustomerPortal() has not been implemented.');
  }

  Future<void> showManageSubscription({required String userId}) {
    throw UnimplementedError('showManageSubscription() has not been implemented.');
  }

  // -- Universal Links --

  Future<bool> handleUniversalLink(String url) {
    throw UnimplementedError('handleUniversalLink() has not been implemented.');
  }

  // -- State Queries --

  Future<bool> getIsConfigured() {
    throw UnimplementedError('getIsConfigured() has not been implemented.');
  }

  Future<bool> getPendingCheckout() {
    throw UnimplementedError('getPendingCheckout() has not been implemented.');
  }

  Future<Map<String, dynamic>?> getRemoteConfig() {
    throw UnimplementedError('getRemoteConfig() has not been implemented.');
  }

  Future<String?> getDetectedJurisdiction() {
    throw UnimplementedError('getDetectedJurisdiction() has not been implemented.');
  }

  // -- State Queries (1.3.0) --

  /// The currently identified user ID, or null if `identify()` hasn't been
  /// called.
  Future<String?> getCurrentUserId() {
    throw UnimplementedError('getCurrentUserId() has not been implemented.');
  }

  /// Whether `identify()` (or the deprecated `bootstrap()`) has completed.
  Future<bool> getIsBootstrapped() {
    throw UnimplementedError('getIsBootstrapped() has not been implemented.');
  }

  // -- Pending Claims (1.3.0) --

  /// StoreKit purchases the current user could claim from another ZeroSettle
  /// account.
  Future<List<Map<String, dynamic>>> getPendingClaims() {
    throw UnimplementedError('getPendingClaims() has not been implemented.');
  }

  // -- StoreKit Helpers (1.3.0) --

  /// Derive a deterministic UUID for `appAccountToken` from the currently
  /// identified user ID. Returned as a string.
  Future<String> recommendedAppAccountToken() {
    throw UnimplementedError(
      'recommendedAppAccountToken() has not been implemented.',
    );
  }

  // -- Base URL Override --

  Future<void> setBaseUrlOverride(String? url) {
    throw UnimplementedError('setBaseUrlOverride() has not been implemented.');
  }

  // -- Cancel Flow (Headless) --

  Future<Map<String, dynamic>> acceptSaveOffer({required String productId, required String userId}) {
    throw UnimplementedError('acceptSaveOffer() has not been implemented.');
  }

  /// 1.3.0 no-userId overload — uses the currently identified user.
  Future<Map<String, dynamic>> acceptSaveOfferForCurrentUser({required String productId}) {
    throw UnimplementedError('acceptSaveOfferForCurrentUser() has not been implemented.');
  }

  Future<void> submitCancelFlowResponse(Map<String, dynamic> response) {
    throw UnimplementedError('submitCancelFlowResponse() has not been implemented.');
  }

  Future<Map<String, dynamic>?> getCancelFlowConfig() {
    throw UnimplementedError('getCancelFlowConfig() has not been implemented.');
  }

  Future<void> cancelSubscription({required String productId, required String userId, bool immediate = false}) {
    throw UnimplementedError('cancelSubscription() has not been implemented.');
  }

  /// 1.3.0 no-userId overload — uses the currently identified user.
  Future<void> cancelSubscriptionForCurrentUser({required String productId, bool immediate = false}) {
    throw UnimplementedError('cancelSubscriptionForCurrentUser() has not been implemented.');
  }

  // -- Save the Sale --

  Future<String> presentSaveTheSaleSheet() {
    throw UnimplementedError('presentSaveTheSaleSheet() has not been implemented.');
  }

  // -- Cancel Flow --

  Future<String> presentCancelFlow({required String productId, required String userId}) {
    throw UnimplementedError('presentCancelFlow() has not been implemented.');
  }

  /// 1.3.0 no-userId overload — uses the currently identified user.
  Future<String?> presentCancelFlowForCurrentUser({required String productId}) {
    throw UnimplementedError('presentCancelFlowForCurrentUser() has not been implemented.');
  }

  // -- Transaction History --

  Future<List<Map<String, dynamic>>> fetchTransactionHistory({required String userId}) {
    throw UnimplementedError('fetchTransactionHistory() has not been implemented.');
  }

  /// 1.3.0 no-userId overload — uses the currently identified user.
  Future<List<Map<String, dynamic>>> fetchTransactionHistoryForCurrentUser() {
    throw UnimplementedError('fetchTransactionHistoryForCurrentUser() has not been implemented.');
  }

  Future<Map<String, dynamic>> fetchCancelFlowConfig({String? userId}) {
    throw UnimplementedError('fetchCancelFlowConfig() has not been implemented.');
  }

  Future<String?> pauseSubscription({required String productId, required String userId, required int pauseOptionId}) {
    throw UnimplementedError('pauseSubscription() has not been implemented.');
  }

  /// 1.3.0 no-userId overload — uses the currently identified user.
  /// Takes `pauseDurationDays` per Kit 1.3.0 (replaces the old `pauseOptionId`).
  Future<String?> pauseSubscriptionForCurrentUser({required String productId, int? pauseDurationDays}) {
    throw UnimplementedError('pauseSubscriptionForCurrentUser() has not been implemented.');
  }

  Future<void> resumeSubscription({required String productId, required String userId}) {
    throw UnimplementedError('resumeSubscription() has not been implemented.');
  }

  /// 1.3.0 no-userId overload — uses the currently identified user.
  Future<void> resumeSubscriptionForCurrentUser({required String productId}) {
    throw UnimplementedError('resumeSubscriptionForCurrentUser() has not been implemented.');
  }

  // -- Upgrade Offer --

  Future<String> presentUpgradeOffer({String? productId, required String userId}) {
    throw UnimplementedError('presentUpgradeOffer() has not been implemented.');
  }

  /// 1.3.0 no-userId overload — uses the currently identified user.
  Future<String> presentUpgradeOfferForCurrentUser({String? productId}) {
    throw UnimplementedError('presentUpgradeOfferForCurrentUser() has not been implemented.');
  }

  Future<Map<String, dynamic>> fetchUpgradeOfferConfig({String? productId, required String userId}) {
    throw UnimplementedError('fetchUpgradeOfferConfig() has not been implemented.');
  }

  /// 1.3.0 no-userId overload — uses the currently identified user.
  Future<Map<String, dynamic>> fetchUpgradeOfferConfigForCurrentUser({String? productId}) {
    throw UnimplementedError('fetchUpgradeOfferConfigForCurrentUser() has not been implemented.');
  }

  // -- Migration Tracking --

  Future<void> trackMigrationConversion({required String userId}) {
    throw UnimplementedError('trackMigrationConversion() has not been implemented.');
  }

  /// 1.3.0 no-userId overload — uses the currently identified user.
  Future<void> trackMigrationConversionForCurrentUser() {
    throw UnimplementedError('trackMigrationConversionForCurrentUser() has not been implemented.');
  }

  // -- Migration Tip --

  Future<void> resetMigrateTipState() {
    throw UnimplementedError('resetMigrateTipState() has not been implemented.');
  }

  // -- Funnel Analytics --

  Future<void> trackEvent({
    required String eventType,
    required String productId,
    String? screenName,
    Map<String, String>? metadata,
  }) {
    throw UnimplementedError('trackEvent() has not been implemented.');
  }

  // -- Event Streams --

  Stream<List<Map<String, dynamic>>> get entitlementUpdates {
    throw UnimplementedError('entitlementUpdates has not been implemented.');
  }

  Stream<Map<String, dynamic>> get checkoutEvents {
    throw UnimplementedError('checkoutEvents has not been implemented.');
  }

  /// Stream of pending-claim list snapshots. Emits whenever the SDK's
  /// `pendingClaims` mutates (claim added or removed).
  Stream<List<Map<String, dynamic>>> get pendingClaimsUpdates {
    throw UnimplementedError(
      'pendingClaimsUpdates has not been implemented.',
    );
  }
}
