import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'zerosettle_platform_interface.dart';

/// An implementation of [ZeroSettlePlatform] that uses method channels.
class MethodChannelZeroSettle extends ZeroSettlePlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('zerosettle');

  @visibleForTesting
  final entitlementEventChannel = const EventChannel('zerosettle/entitlement_updates');

  @visibleForTesting
  final checkoutEventChannel = const EventChannel('zerosettle/checkout_events');

  // -- Configuration --

  @override
  Future<void> configure({
    required String publishableKey,
    bool syncStoreKitTransactions = true,
    String? appleMerchantId,
    bool preloadCheckout = false,
    int? maxPreloadedWebViews,
  }) async {
    await methodChannel.invokeMethod('configure', {
      'publishableKey': publishableKey,
      'syncStoreKitTransactions': syncStoreKitTransactions,
      if (appleMerchantId != null) 'appleMerchantId': appleMerchantId,
      'preloadCheckout': preloadCheckout,
      if (maxPreloadedWebViews != null) 'maxPreloadedWebViews': maxPreloadedWebViews,
    });
  }

  // -- Bootstrap --

  @override
  Future<Map<String, dynamic>> bootstrap({required String userId}) async {
    final result = await methodChannel.invokeMethod<Map>('bootstrap', {
      'userId': userId,
    });
    return Map<String, dynamic>.from(result!);
  }

  @override
  Future<Map<String, dynamic>?> identify({
    required String type,
    String? id,
    String? name,
    String? email,
  }) async {
    final result = await methodChannel.invokeMethod<Map>('identify', {
      'type': type,
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (email != null) 'email': email,
    });
    return result == null ? null : Map<String, dynamic>.from(result);
  }

  @override
  Future<void> logout() async {
    await methodChannel.invokeMethod('logout');
  }

  @override
  Future<void> setCustomer({String? name, String? email}) async {
    await methodChannel.invokeMethod('setCustomer', {
      if (name != null) 'name': name,
      if (email != null) 'email': email,
    });
  }

  @override
  Future<void> transferStoreKitOwnershipToCurrentUser({required String productId}) async {
    await methodChannel.invokeMethod('transferStoreKitOwnershipToCurrentUser', {
      'productId': productId,
    });
  }

  @override
  Future<bool> hasActiveEntitlement({required String productId}) async {
    final result = await methodChannel.invokeMethod<bool>('hasActiveEntitlement', {
      'productId': productId,
    });
    return result ?? false;
  }

  @override
  Future<Map<String, dynamic>?> product({required String productId}) async {
    final result = await methodChannel.invokeMethod<Map>('product', {
      'productId': productId,
    });
    return result == null ? null : Map<String, dynamic>.from(result);
  }

  // -- Products --

  @override
  Future<Map<String, dynamic>> fetchProducts({String? userId}) async {
    final result = await methodChannel.invokeMethod<Map>('fetchProducts', {
      'userId': userId,
    });
    return Map<String, dynamic>.from(result!);
  }

  @override
  Future<List<Map<String, dynamic>>> getProducts() async {
    final result = await methodChannel.invokeMethod<List>('getProducts');
    return result!.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // -- Payment Sheet --

  @override
  Future<Map<String, dynamic>> presentPaymentSheet({
    required String productId,
    String? userId,
    bool dismissible = true,
  }) async {
    final result = await methodChannel.invokeMethod<Map>('presentPaymentSheet', {
      'productId': productId,
      'userId': userId,
      'dismissible': dismissible,
    });
    return Map<String, dynamic>.from(result!);
  }

  @override
  Future<void> preloadPaymentSheet({required String productId, String? userId}) async {
    await methodChannel.invokeMethod('preloadPaymentSheet', {
      'productId': productId,
      'userId': userId,
    });
  }

  @override
  Future<void> warmUpPaymentSheet({required String productId, String? userId}) async {
    await methodChannel.invokeMethod('warmUpPaymentSheet', {
      'productId': productId,
      'userId': userId,
    });
  }

  // -- Entitlements --

  @override
  Future<List<Map<String, dynamic>>> restoreEntitlements({required String userId}) async {
    final result = await methodChannel.invokeMethod<List>('restoreEntitlements', {
      'userId': userId,
    });
    return result!.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> restoreEntitlementsForCurrentUser() async {
    final result = await methodChannel.invokeMethod<List>('restoreEntitlements');
    return result!.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getEntitlements() async {
    final result = await methodChannel.invokeMethod<List>('getEntitlements');
    return result!.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // -- Subscription Management --

  @override
  Future<void> openCustomerPortal({required String userId}) async {
    await methodChannel.invokeMethod('openCustomerPortal', {
      'userId': userId,
    });
  }

  @override
  Future<void> showManageSubscription({required String userId}) async {
    await methodChannel.invokeMethod('showManageSubscription', {
      'userId': userId,
    });
  }

  // -- Universal Links --

  @override
  Future<bool> handleUniversalLink(String url) async {
    final result = await methodChannel.invokeMethod<bool>('handleUniversalLink', {
      'url': url,
    });
    return result ?? false;
  }

  // -- State Queries --

  @override
  Future<bool> getIsConfigured() async {
    final result = await methodChannel.invokeMethod<bool>('getIsConfigured');
    return result ?? false;
  }

  @override
  Future<bool> getPendingCheckout() async {
    final result = await methodChannel.invokeMethod<bool>('getPendingCheckout');
    return result ?? false;
  }

  @override
  Future<Map<String, dynamic>?> getRemoteConfig() async {
    final result = await methodChannel.invokeMethod<Map>('getRemoteConfig');
    return result != null ? Map<String, dynamic>.from(result) : null;
  }

  @override
  Future<String?> getDetectedJurisdiction() async {
    return await methodChannel.invokeMethod<String>('getDetectedJurisdiction');
  }

  // -- Cancel Flow (Headless) --

  @override
  Future<Map<String, dynamic>> acceptSaveOffer({required String productId, required String userId}) async {
    final result = await methodChannel.invokeMethod<Map>('acceptSaveOffer', {
      'productId': productId,
      'userId': userId,
    });
    return Map<String, dynamic>.from(result!);
  }

  @override
  Future<Map<String, dynamic>> acceptSaveOfferForCurrentUser({required String productId}) async {
    final result = await methodChannel.invokeMethod<Map>('acceptSaveOffer', {
      'productId': productId,
    });
    return Map<String, dynamic>.from(result!);
  }

  @override
  Future<void> submitCancelFlowResponse(Map<String, dynamic> response) async {
    await methodChannel.invokeMethod('submitCancelFlowResponse', response);
  }

  @override
  Future<Map<String, dynamic>?> getCancelFlowConfig() async {
    final result = await methodChannel.invokeMethod<Map>('getCancelFlowConfig');
    return result != null ? Map<String, dynamic>.from(result) : null;
  }

  @override
  Future<void> cancelSubscription({required String productId, required String userId, bool immediate = false}) async {
    await methodChannel.invokeMethod('cancelSubscription', {
      'productId': productId,
      'userId': userId,
      'immediate': immediate,
    });
  }

  @override
  Future<void> cancelSubscriptionForCurrentUser({required String productId, bool immediate = false}) async {
    await methodChannel.invokeMethod('cancelSubscription', {
      'productId': productId,
      'immediate': immediate,
    });
  }

  // -- Save the Sale --

  @override
  Future<String> presentSaveTheSaleSheet() async {
    final result = await methodChannel.invokeMethod<String>('presentSaveTheSaleSheet');
    return result ?? 'dismissed';
  }

  // -- Cancel Flow --

  @override
  Future<String> presentCancelFlow({required String productId, required String userId}) async {
    final result = await methodChannel.invokeMethod<String>('presentCancelFlow', {
      'productId': productId,
      'userId': userId,
    });
    return result ?? 'dismissed';
  }

  @override
  Future<String?> presentCancelFlowForCurrentUser({required String productId}) async {
    return await methodChannel.invokeMethod<String>('presentCancelFlow', {
      'productId': productId,
    });
  }

  // -- Transaction History --

  @override
  Future<List<Map<String, dynamic>>> fetchTransactionHistory({required String userId}) async {
    final result = await methodChannel.invokeMethod<List>('fetchTransactionHistory', {
      'userId': userId,
    });
    return result!.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchTransactionHistoryForCurrentUser() async {
    final result = await methodChannel.invokeMethod<List>('fetchTransactionHistory');
    return result!.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Future<Map<String, dynamic>> fetchCancelFlowConfig({String? userId}) async {
    final result = await methodChannel.invokeMethod<Map>('fetchCancelFlowConfig', {
      if (userId != null) 'userId': userId,
    });
    return Map<String, dynamic>.from(result!);
  }

  @override
  Future<String?> pauseSubscription({required String productId, required String userId, required int pauseOptionId}) async {
    final result = await methodChannel.invokeMethod<String>('pauseSubscription', {
      'productId': productId,
      'userId': userId,
      'pauseOptionId': pauseOptionId,
    });
    return result;
  }

  @override
  Future<String?> pauseSubscriptionForCurrentUser({required String productId, int? pauseDurationDays}) async {
    final result = await methodChannel.invokeMethod<String>('pauseSubscription', {
      'productId': productId,
      if (pauseDurationDays != null) 'pauseDurationDays': pauseDurationDays,
    });
    return result;
  }

  @override
  Future<void> resumeSubscription({required String productId, required String userId}) async {
    await methodChannel.invokeMethod('resumeSubscription', {
      'productId': productId,
      'userId': userId,
    });
  }

  @override
  Future<void> resumeSubscriptionForCurrentUser({required String productId}) async {
    await methodChannel.invokeMethod('resumeSubscription', {
      'productId': productId,
    });
  }


  // -- Upgrade Offer --

  @override
  Future<String> presentUpgradeOffer({String? productId, required String userId}) async {
    final result = await methodChannel.invokeMethod<String>('presentUpgradeOffer', {
      if (productId != null) 'productId': productId,
      'userId': userId,
    });
    return result ?? 'dismissed';
  }

  @override
  Future<String> presentUpgradeOfferForCurrentUser({String? productId}) async {
    final result = await methodChannel.invokeMethod<String>('presentUpgradeOffer', {
      if (productId != null) 'productId': productId,
    });
    return result ?? 'dismissed';
  }

  @override
  Future<Map<String, dynamic>> fetchUpgradeOfferConfig({String? productId, required String userId}) async {
    final result = await methodChannel.invokeMethod<Map>('fetchUpgradeOfferConfig', {
      if (productId != null) 'productId': productId,
      'userId': userId,
    });
    return Map<String, dynamic>.from(result!);
  }

  @override
  Future<Map<String, dynamic>> fetchUpgradeOfferConfigForCurrentUser({String? productId}) async {
    final result = await methodChannel.invokeMethod<Map>('fetchUpgradeOfferConfig', {
      if (productId != null) 'productId': productId,
    });
    return Map<String, dynamic>.from(result!);
  }

  // -- Migration Tracking --

  @override
  Future<void> trackMigrationConversion({required String userId}) async {
    await methodChannel.invokeMethod('trackMigrationConversion', {
      'userId': userId,
    });
  }

  @override
  Future<void> trackMigrationConversionForCurrentUser() async {
    await methodChannel.invokeMethod('trackMigrationConversion');
  }

  // -- Migration Tip --

  @override
  Future<void> resetMigrateTipState() async {
    await methodChannel.invokeMethod('resetMigrateTipState');
  }

  // -- Funnel Analytics --

  @override
  Future<void> trackEvent({
    required String eventType,
    required String productId,
    String? screenName,
    Map<String, String>? metadata,
  }) async {
    await methodChannel.invokeMethod('trackEvent', {
      'eventType': eventType,
      'productId': productId,
      if (screenName != null) 'screenName': screenName,
      if (metadata != null) 'metadata': metadata,
    });
  }

  // -- Event Streams --

  Stream<List<Map<String, dynamic>>>? _entitlementUpdatesStream;

  @override
  Stream<List<Map<String, dynamic>>> get entitlementUpdates {
    _entitlementUpdatesStream ??= entitlementEventChannel
        .receiveBroadcastStream()
        .map((event) => (event as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList());
    return _entitlementUpdatesStream!;
  }

  Stream<Map<String, dynamic>>? _checkoutEventsStream;

  @override
  Stream<Map<String, dynamic>> get checkoutEvents {
    _checkoutEventsStream ??= checkoutEventChannel
        .receiveBroadcastStream()
        .map((event) => Map<String, dynamic>.from(event as Map));
    return _checkoutEventsStream!;
  }
}
