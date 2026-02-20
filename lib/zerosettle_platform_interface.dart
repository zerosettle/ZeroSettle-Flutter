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

  Future<void> configure({required String publishableKey, bool syncStoreKitTransactions = true}) {
    throw UnimplementedError('configure() has not been implemented.');
  }

  // -- Bootstrap --

  Future<Map<String, dynamic>> bootstrap({required String userId, required int freeTrialDays}) {
    throw UnimplementedError('bootstrap() has not been implemented.');
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
    required int freeTrialDays,
    bool dismissible = true,
  }) {
    throw UnimplementedError('presentPaymentSheet() has not been implemented.');
  }

  Future<void> preloadPaymentSheet({required String productId, String? userId, required int freeTrialDays}) {
    throw UnimplementedError('preloadPaymentSheet() has not been implemented.');
  }

  Future<void> warmUpPaymentSheet({required String productId, String? userId, required int freeTrialDays}) {
    throw UnimplementedError('warmUpPaymentSheet() has not been implemented.');
  }

  // -- Entitlements --

  Future<List<Map<String, dynamic>>> restoreEntitlements({required String userId}) {
    throw UnimplementedError('restoreEntitlements() has not been implemented.');
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

  // -- Save the Sale --

  Future<String> presentSaveTheSaleSheet() {
    throw UnimplementedError('presentSaveTheSaleSheet() has not been implemented.');
  }

  // -- Event Streams --

  Stream<List<Map<String, dynamic>>> get entitlementUpdates {
    throw UnimplementedError('entitlementUpdates has not been implemented.');
  }

  Stream<Map<String, dynamic>> get checkoutEvents {
    throw UnimplementedError('checkoutEvents has not been implemented.');
  }
}
