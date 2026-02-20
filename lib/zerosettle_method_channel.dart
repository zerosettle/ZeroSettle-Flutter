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
  Future<void> configure({required String publishableKey, bool syncStoreKitTransactions = true}) async {
    await methodChannel.invokeMethod('configure', {
      'publishableKey': publishableKey,
      'syncStoreKitTransactions': syncStoreKitTransactions,
    });
  }

  // -- Bootstrap --

  @override
  Future<Map<String, dynamic>> bootstrap({required String userId, required int freeTrialDays}) async {
    final result = await methodChannel.invokeMethod<Map>('bootstrap', {
      'userId': userId,
      'freeTrialDays': freeTrialDays,
    });
    return Map<String, dynamic>.from(result!);
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
    required int freeTrialDays,
    bool dismissible = true,
  }) async {
    final result = await methodChannel.invokeMethod<Map>('presentPaymentSheet', {
      'productId': productId,
      'userId': userId,
      'freeTrialDays': freeTrialDays,
      'dismissible': dismissible,
    });
    return Map<String, dynamic>.from(result!);
  }

  @override
  Future<void> preloadPaymentSheet({required String productId, String? userId, required int freeTrialDays}) async {
    await methodChannel.invokeMethod('preloadPaymentSheet', {
      'productId': productId,
      'userId': userId,
      'freeTrialDays': freeTrialDays,
    });
  }

  @override
  Future<void> warmUpPaymentSheet({required String productId, String? userId, required int freeTrialDays}) async {
    await methodChannel.invokeMethod('warmUpPaymentSheet', {
      'productId': productId,
      'userId': userId,
      'freeTrialDays': freeTrialDays,
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

  // -- Save the Sale --

  @override
  Future<String> presentSaveTheSaleSheet() async {
    final result = await methodChannel.invokeMethod<String>('presentSaveTheSaleSheet');
    return result ?? 'dismissed';
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
