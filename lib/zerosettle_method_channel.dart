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

  @visibleForTesting
  final pendingClaimsEventChannel =
      const EventChannel('zerosettle/pending_claims_updates');

  @visibleForTesting
  final applePayStateEventChannel =
      const EventChannel('zerosettle/apple_pay_state_updates');

  // Gap 5 — reactive state event channels.
  @visibleForTesting
  final productsEventChannel = const EventChannel('zerosettle/products_updates');

  @visibleForTesting
  final currentUserIdEventChannel =
      const EventChannel('zerosettle/current_user_id_updates');

  @visibleForTesting
  final pendingCheckoutEventChannel =
      const EventChannel('zerosettle/pending_checkout_updates');

  @visibleForTesting
  final isBootstrappedEventChannel =
      const EventChannel('zerosettle/is_bootstrapped_updates');

  @visibleForTesting
  final isUcbEnabledEventChannel =
      const EventChannel('zerosettle/is_ucb_enabled_updates');

  @visibleForTesting
  final pendingActionsEventChannel =
      const EventChannel('zerosettle/pending_actions_updates');

  @visibleForTesting
  final eventsEventChannel = const EventChannel('zerosettle/events');

  // -- Configuration --

  @override
  Future<void> setBaseUrlOverride(String? url) async {
    await methodChannel.invokeMethod('setBaseUrlOverride', {
      if (url != null) 'url': url,
    });
  }

  @override
  Future<void> configure({
    required String publishableKey,
    bool syncStoreKitTransactions = true,
    String? appleMerchantId,
    bool preloadCheckout = false,
    int? maxPreloadedWebViews,
    String? applePaySetupBehavior,
    String? playLicenseKey,
    bool syncPlayPurchases = true,
    bool strictAck = false,
  }) async {
    await methodChannel.invokeMethod('configure', {
      'publishableKey': publishableKey,
      'syncStoreKitTransactions': syncStoreKitTransactions,
      if (appleMerchantId != null) 'appleMerchantId': appleMerchantId,
      'preloadCheckout': preloadCheckout,
      if (maxPreloadedWebViews != null) 'maxPreloadedWebViews': maxPreloadedWebViews,
      if (applePaySetupBehavior != null) 'applePaySetupBehavior': applePaySetupBehavior,
      if (playLicenseKey != null) 'playLicenseKey': playLicenseKey,
      'syncPlayPurchases': syncPlayPurchases,
      'strictAck': strictAck,
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
  Future<void> transferPlayOwnershipToCurrentUser({
    required String productId,
    required String originalTransactionId,
  }) async {
    await methodChannel.invokeMethod('transferPlayOwnershipToCurrentUser', {
      'productId': productId,
      'originalTransactionId': originalTransactionId,
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

  // -- Purchase (1.3.0) --

  @override
  Future<Map<String, dynamic>> purchase({
    required String productId,
    String? presentation,
  }) async {
    final result = await methodChannel.invokeMethod<Map>('purchase', {
      'productId': productId,
      if (presentation != null) 'presentation': presentation,
    });
    return Map<String, dynamic>.from(result!);
  }

  @override
  Future<Map<String, dynamic>> purchaseViaStoreKit({
    required String productId,
  }) async {
    final result = await methodChannel.invokeMethod<Map>('purchaseViaStoreKit', {
      'productId': productId,
    });
    return Map<String, dynamic>.from(result!);
  }

  @override
  Future<Map<String, dynamic>> purchaseViaPlayBilling({
    required String productId,
  }) async {
    final result = await methodChannel.invokeMethod<Map>('purchaseViaPlayBilling', {
      'productId': productId,
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
  Future<String> getSdkVersion() async {
    final v = await methodChannel.invokeMethod<String>('getSdkVersion');
    return v ?? '';
  }

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

  // -- State Queries (1.3.0) --

  @override
  Future<String?> getCurrentUserId() async {
    return await methodChannel.invokeMethod<String>('getCurrentUserId');
  }

  @override
  Future<bool> getIsBootstrapped() async {
    final result = await methodChannel.invokeMethod<bool>('getIsBootstrapped');
    return result ?? false;
  }

  // -- Pending Claims (1.3.0) --

  @override
  Future<List<Map<String, dynamic>>> getPendingClaims() async {
    final result = await methodChannel.invokeMethod<List>('getPendingClaims');
    if (result == null) return const [];
    return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // -- StoreKit Helpers (1.3.0) --

  @override
  Future<String> recommendedAppAccountToken() async {
    final result = await methodChannel.invokeMethod<String>(
      'recommendedAppAccountToken',
    );
    return result!;
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

  Stream<List<Map<String, dynamic>>>? _pendingClaimsUpdatesStream;

  @override
  Stream<List<Map<String, dynamic>>> get pendingClaimsUpdates {
    _pendingClaimsUpdatesStream ??= pendingClaimsEventChannel
        .receiveBroadcastStream()
        .map((event) => (event as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList());
    return _pendingClaimsUpdatesStream!;
  }

  // -- Gap 5: reactive state streams --

  Stream<List<Map<String, dynamic>>>? _productsUpdatesStream;

  @override
  Stream<List<Map<String, dynamic>>> get productsUpdates {
    _productsUpdatesStream ??= productsEventChannel
        .receiveBroadcastStream()
        .map((event) => (event as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList());
    return _productsUpdatesStream!;
  }

  Stream<String?>? _currentUserIdUpdatesStream;

  @override
  Stream<String?> get currentUserIdUpdates {
    // The wire emits `null` on logout (Android: StateFlow<String?>; iOS:
    // shadowed cache pushed at identify/logout sites). Use a broadcast
    // stream as-is — Dart sees the `null` value verbatim.
    _currentUserIdUpdatesStream ??= currentUserIdEventChannel
        .receiveBroadcastStream()
        .map((event) => event as String?);
    return _currentUserIdUpdatesStream!;
  }

  Stream<bool>? _pendingCheckoutUpdatesStream;

  @override
  Stream<bool> get pendingCheckoutUpdates {
    _pendingCheckoutUpdatesStream ??= pendingCheckoutEventChannel
        .receiveBroadcastStream()
        .map((event) => event as bool);
    return _pendingCheckoutUpdatesStream!;
  }

  Stream<bool>? _isBootstrappedUpdatesStream;

  @override
  Stream<bool> get isBootstrappedUpdates {
    _isBootstrappedUpdatesStream ??= isBootstrappedEventChannel
        .receiveBroadcastStream()
        .map((event) => event as bool);
    return _isBootstrappedUpdatesStream!;
  }

  // -- Migration Manager (Headless) --

  @override
  Future<String> resolveMigrationManagerHandle({String? stripeCustomerId}) async {
    final result = await methodChannel.invokeMethod<String>(
      'resolveMigrationManagerHandle',
      {
        if (stripeCustomerId != null) 'stripeCustomerId': stripeCustomerId,
      },
    );
    return result!;
  }

  // -- Offer Manager (Headless) --

  @override
  Future<String> resolveOfferManagerHandle({String? stripeCustomerId}) async {
    final result = await methodChannel.invokeMethod<String>(
      'resolveOfferManagerHandle',
      {
        if (stripeCustomerId != null) 'stripeCustomerId': stripeCustomerId,
      },
    );
    return result!;
  }

  // -- Apple Pay (1.3.2) --

  @override
  Future<void> presentApplePaySetup() async {
    await methodChannel.invokeMethod('presentApplePaySetup');
  }

  @override
  Future<bool> getIsApplePayOnly() async {
    final result = await methodChannel.invokeMethod<bool>('getIsApplePayOnly');
    return result ?? false;
  }

  @override
  Future<String> getApplePayState() async {
    final result = await methodChannel.invokeMethod<String>('getApplePayState');
    // Default to "unavailable" if the platform returns null (e.g. Android stub).
    return result ?? 'unavailable';
  }

  Stream<String>? _applePayStateUpdatesStream;

  @override
  Stream<String> get applePayStateUpdates {
    _applePayStateUpdatesStream ??=
        applePayStateEventChannel.receiveBroadcastStream().map((e) => e as String);
    return _applePayStateUpdatesStream!;
  }

  // -- UCB (User Choice Billing) --

  @override
  Future<bool> getIsUcbEnabled() async {
    final v = await methodChannel.invokeMethod<bool>('getIsUcbEnabled');
    return v ?? false;
  }

  Stream<bool>? _isUcbEnabledUpdatesStream;

  @override
  Stream<bool> get isUcbEnabledUpdates {
    _isUcbEnabledUpdatesStream ??= isUcbEnabledEventChannel
        .receiveBroadcastStream()
        .map((event) => event as bool);
    return _isUcbEnabledUpdatesStream!;
  }

  // -- Web Checkout --

  @override
  Future<void> releasePendingCheckout() async {
    await methodChannel.invokeMethod<void>('releasePendingCheckout');
  }

  // -- Task 5: Pending Actions (Android only) --

  @override
  Future<List<Map<String, dynamic>>> getPendingActions() async {
    final result = await methodChannel.invokeMethod<List>('getPendingActions');
    if (result == null) return const [];
    return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Stream<List<Map<String, dynamic>>>? _pendingActionsUpdatesStream;

  @override
  Stream<List<Map<String, dynamic>>> get pendingActionsUpdates {
    _pendingActionsUpdatesStream ??= pendingActionsEventChannel
        .receiveBroadcastStream()
        .map((event) => (event as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList());
    return _pendingActionsUpdatesStream!;
  }

  @override
  Future<void> dismissPendingAction({required String transactionId}) async {
    await methodChannel.invokeMethod<void>('dismissPendingAction', {
      'transactionId': transactionId,
    });
  }

  // -- Task 9: fetchUserOffer --

  @override
  Future<Map<String, dynamic>> fetchUserOffer() async {
    final result = await methodChannel.invokeMethod<Map>('fetchUserOffer');
    return Map<String, dynamic>.from(result!);
  }

  // -- Task 11: SDK analytics/lifecycle events --

  Stream<Map<String, dynamic>>? _eventsUpdatesStream;

  @override
  Stream<Map<String, dynamic>> get eventsUpdates {
    _eventsUpdatesStream ??= eventsEventChannel
        .receiveBroadcastStream()
        .map((event) => Map<String, dynamic>.from(event as Map));
    return _eventsUpdatesStream!;
  }
}
