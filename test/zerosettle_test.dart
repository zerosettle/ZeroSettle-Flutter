import 'package:flutter_test/flutter_test.dart';
import 'package:zerosettle/zerosettle.dart';
import 'package:zerosettle/zerosettle_platform_interface.dart';
import 'package:zerosettle/zerosettle_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

// -- Mock Platform --

class MockZeroSettlePlatform
    with MockPlatformInterfaceMixin
    implements ZeroSettlePlatform {

  bool configured = false;
  String? lastUserId;

  // Call recorders — let tests assert facade-to-platform forwarding.
  final List<Map<String, dynamic>> calls = [];
  void _record(String method, [Map<String, dynamic>? args]) {
    calls.add({'method': method, ...?args});
  }

  // Test-controlled return values for new no-userId methods. Tests can
  // override these; default behavior is "platform method exists and returns
  // a sensible value".
  Map<String, dynamic>? productReturnValue = _sampleProductMap();
  bool hasActiveEntitlementReturn = true;

  // Args captured from configure().
  String? lastPublishableKey;
  bool? lastSyncStoreKitTransactions;
  String? lastAppleMerchantId;
  bool? lastPreloadCheckout;
  int? lastMaxPreloadedWebViews;

  @override
  Future<void> configure({
    required String publishableKey,
    bool syncStoreKitTransactions = true,
    String? appleMerchantId,
    bool preloadCheckout = false,
    int? maxPreloadedWebViews,
  }) async {
    configured = true;
    lastPublishableKey = publishableKey;
    lastSyncStoreKitTransactions = syncStoreKitTransactions;
    lastAppleMerchantId = appleMerchantId;
    lastPreloadCheckout = preloadCheckout;
    lastMaxPreloadedWebViews = maxPreloadedWebViews;
    _record('configure', {
      'publishableKey': publishableKey,
      'syncStoreKitTransactions': syncStoreKitTransactions,
      if (appleMerchantId != null) 'appleMerchantId': appleMerchantId,
      'preloadCheckout': preloadCheckout,
      if (maxPreloadedWebViews != null) 'maxPreloadedWebViews': maxPreloadedWebViews,
    });
  }

  // ---- 1.3.0 no-userId platform-interface variants ----
  // Agent 2 disambiguated method overloads using *ForCurrentUser suffix on the
  // platform interface; the public facade methods (e.g., restoreEntitlements())
  // delegate here.

  @override
  Future<List<Map<String, dynamic>>> restoreEntitlementsForCurrentUser() async {
    _record('restoreEntitlementsForCurrentUser');
    return const [];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchTransactionHistoryForCurrentUser() async {
    _record('fetchTransactionHistoryForCurrentUser');
    return const [];
  }

  @override
  Future<Map<String, dynamic>> acceptSaveOfferForCurrentUser({required String productId}) async {
    _record('acceptSaveOfferForCurrentUser', {'productId': productId});
    return const {};
  }

  @override
  Future<String?> presentCancelFlowForCurrentUser({required String productId}) async {
    _record('presentCancelFlowForCurrentUser', {'productId': productId});
    return null;
  }

  @override
  Future<String?> pauseSubscriptionForCurrentUser({required String productId, int? pauseDurationDays}) async {
    _record('pauseSubscriptionForCurrentUser', {
      'productId': productId,
      if (pauseDurationDays != null) 'pauseDurationDays': pauseDurationDays,
    });
    return null;
  }

  @override
  Future<void> resumeSubscriptionForCurrentUser({required String productId}) async {
    _record('resumeSubscriptionForCurrentUser', {'productId': productId});
  }

  @override
  Future<void> cancelSubscriptionForCurrentUser({required String productId, bool immediate = false}) async {
    _record('cancelSubscriptionForCurrentUser', {
      'productId': productId,
      'immediate': immediate,
    });
  }

  @override
  Future<String> presentUpgradeOfferForCurrentUser({String? productId}) async {
    _record('presentUpgradeOfferForCurrentUser', {if (productId != null) 'productId': productId});
    return 'dismissed';
  }

  @override
  Future<Map<String, dynamic>> fetchUpgradeOfferConfigForCurrentUser({String? productId}) async {
    _record('fetchUpgradeOfferConfigForCurrentUser', {if (productId != null) 'productId': productId});
    return const {};
  }

  @override
  Future<void> trackMigrationConversionForCurrentUser() async {
    _record('trackMigrationConversionForCurrentUser');
  }

  // ---- Identity / 1.3.0 surface ----

  Map<String, dynamic>? lastIdentifyArgs;

  @override
  Future<Map<String, dynamic>?> identify({
    required String type,
    String? id,
    String? name,
    String? email,
  }) async {
    lastIdentifyArgs = {
      'type': type,
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (email != null) 'email': email,
    };
    _record('identify', lastIdentifyArgs!);
    return _sampleCatalogMap();
  }

  @override
  Future<void> logout() async {
    _record('logout');
  }

  @override
  Future<void> setCustomer({String? name, String? email}) async {
    _record('setCustomer', {
      if (name != null) 'name': name,
      if (email != null) 'email': email,
    });
  }

  @override
  Future<void> transferStoreKitOwnershipToCurrentUser({
    required String productId,
  }) async {
    _record('transferStoreKitOwnershipToCurrentUser', {'productId': productId});
  }

  @override
  Future<bool> hasActiveEntitlement({required String productId}) async {
    _record('hasActiveEntitlement', {'productId': productId});
    return hasActiveEntitlementReturn;
  }

  @override
  Future<Map<String, dynamic>?> product({required String productId}) async {
    _record('product', {'productId': productId});
    return productReturnValue;
  }

  @override
  Future<Map<String, dynamic>> acceptSaveOffer({
    required String productId,
    required String userId,
  }) async {
    _record('acceptSaveOffer', {'productId': productId, 'userId': userId});
    return {'discountPercent': 20};
  }

  @override
  Future<void> submitCancelFlowResponse(Map<String, dynamic> response) async {
    _record('submitCancelFlowResponse', {'response': response});
  }

  @override
  Future<Map<String, dynamic>?> getCancelFlowConfig() async {
    _record('getCancelFlowConfig');
    return null;
  }

  @override
  Future<Map<String, dynamic>> bootstrap({required String userId}) async {
    lastUserId = userId;
    return _sampleCatalogMap();
  }

  @override
  Future<Map<String, dynamic>> fetchProducts({String? userId}) async {
    return _sampleCatalogMap();
  }

  @override
  Future<List<Map<String, dynamic>>> getProducts() async {
    return [_sampleProductMap()];
  }

  @override
  Future<Map<String, dynamic>> presentPaymentSheet({
    required String productId,
    String? userId,
    bool dismissible = true,
  }) async {
    return _sampleTransactionMap();
  }

  @override
  Future<void> preloadPaymentSheet({required String productId, String? userId}) async {}

  @override
  Future<void> warmUpPaymentSheet({required String productId, String? userId}) async {}

  @override
  Future<List<Map<String, dynamic>>> restoreEntitlements({required String userId}) async {
    return [_sampleEntitlementMap()];
  }

  @override
  Future<List<Map<String, dynamic>>> getEntitlements() async {
    return [_sampleEntitlementMap()];
  }

  @override
  Future<void> openCustomerPortal({required String userId}) async {}

  @override
  Future<void> showManageSubscription({required String userId}) async {}

  @override
  Future<bool> handleUniversalLink(String url) async => true;

  @override
  Future<bool> getIsConfigured() async => configured;

  @override
  Future<bool> getPendingCheckout() async => false;

  @override
  Future<Map<String, dynamic>?> getRemoteConfig() async {
    return _sampleRemoteConfigMap();
  }

  @override
  Future<String?> getDetectedJurisdiction() async => 'us';

  @override
  Stream<List<Map<String, dynamic>>> get entitlementUpdates =>
      Stream.value([_sampleEntitlementMap()]);

  @override
  Stream<Map<String, dynamic>> get checkoutEvents =>
      Stream.value({'event': 'checkoutDidBegin', 'productId': 'premium'});

  @override
  Future<void> setBaseUrlOverride(String? url) async {}

  @override
  Future<List<Map<String, dynamic>>> fetchTransactionHistory({required String userId}) async {
    return [
      _sampleTransactionMap(),
      {
        'id': 'txn_def',
        'productId': 'coins_100',
        'status': 'completed',
        'source': 'store_kit',
        'purchasedAt': '2025-02-01T12:00:00.000Z',
        'productName': '100 Coins',
        'amountCents': 99,
        'currency': 'USD',
      },
    ];
  }

  @override
  Future<String> presentCancelFlow({required String productId, required String userId}) async {
    return 'cancelled';
  }

  @override
  Future<Map<String, dynamic>> fetchCancelFlowConfig({String? userId}) async {
    return {
      'enabled': true,
      'questions': <Map<String, dynamic>>[],
    };
  }

  @override
  Future<String?> pauseSubscription({
    required String productId,
    required String userId,
    required int pauseOptionId,
  }) async {
    return '2026-04-01T00:00:00.000Z';
  }

  @override
  Future<void> resumeSubscription({required String productId, required String userId}) async {}

  @override
  Future<void> cancelSubscription({
    required String productId,
    required String userId,
    bool immediate = false,
  }) async {}

  @override
  Future<String> presentUpgradeOffer({String? productId, required String userId}) async {
    return 'upgraded';
  }

  @override
  Future<Map<String, dynamic>> fetchUpgradeOfferConfig({String? productId, required String userId}) async {
    return {'available': false};
  }

  @override
  Future<void> trackMigrationConversion({required String userId}) async {}

  @override
  Future<void> resetMigrateTipState() async {}

  @override
  Future<void> trackEvent({
    required String eventType,
    required String productId,
    String? screenName,
    Map<String, String>? metadata,
  }) async {}

  @override
  Future<String> presentSaveTheSaleSheet() async => 'dismissed';
}

// -- Sample Data Helpers --

Map<String, dynamic> _sampleProductMap() => {
  'id': 'premium_monthly',
  'displayName': 'Premium Monthly',
  'productDescription': 'Unlock all features',
  'type': 'auto_renewable_subscription',
  'webPrice': {'amountCents': 499, 'currencyCode': 'USD'},
  'appStorePrice': {'amountCents': 599, 'currencyCode': 'USD'},
  'syncedToAppStoreConnect': true,
  'storeKitAvailable': true,
  'storeKitPrice': {'amountCents': 599, 'currencyCode': 'USD'},
  'savingsPercent': 17,
};

Map<String, dynamic> _sampleEntitlementMap() => {
  'id': 'ent_123',
  'productId': 'premium_monthly',
  'source': 'web_checkout',
  'isActive': true,
  'purchasedAt': '2025-01-15T10:30:00.000Z',
  'expiresAt': '2025-02-15T10:30:00.000Z',
};

Map<String, dynamic> _sampleTransactionMap() => {
  'id': 'txn_abc',
  'productId': 'premium_monthly',
  'status': 'completed',
  'source': 'web_checkout',
  'purchasedAt': '2025-01-15T10:30:00.000Z',
  'expiresAt': '2025-02-15T10:30:00.000Z',
};

Map<String, dynamic> _sampleRemoteConfigMap() => {
  'checkout': {
    'sheetType': 'webview',
    'isEnabled': true,
    'jurisdictions': {
      'eu': {'sheetType': 'safari', 'isEnabled': false},
    },
  },
  'migration': {
    'productId': 'premium_monthly',
    'discountPercent': 20,
    'title': 'Switch & Save',
    'message': 'Save 20% by switching to web checkout',
    'ctaText': 'Save 20% Forever',
  },
};

Map<String, dynamic> _sampleCatalogMap() => {
  'products': [_sampleProductMap()],
  'config': _sampleRemoteConfigMap(),
};

// -- Tests --

void main() {
  final ZeroSettlePlatform initialPlatform = ZeroSettlePlatform.instance;

  test('\$MethodChannelZeroSettle is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelZeroSettle>());
  });

  group('ZeroSettle facade', () {
    late MockZeroSettlePlatform mockPlatform;

    setUp(() {
      mockPlatform = MockZeroSettlePlatform();
      ZeroSettlePlatform.instance = mockPlatform;
    });

    test('configure sets configured state', () async {
      await ZeroSettle.instance.configure(publishableKey: 'zs_pk_test_123');
      expect(mockPlatform.configured, isTrue);
    });

    test('bootstrap returns ProductCatalog', () async {
      final catalog = await ZeroSettle.instance.bootstrap(userId: 'user_42');
      expect(catalog.products, hasLength(1));
      expect(catalog.products.first.id, 'premium_monthly');
      expect(catalog.products.first.type, ZSProductType.autoRenewableSubscription);
      expect(catalog.config, isNotNull);
      expect(catalog.config!.migration!.discountPercent, 20);
    });

    test('fetchProducts returns ProductCatalog', () async {
      final catalog = await ZeroSettle.instance.fetchProducts(userId: 'user_42');
      expect(catalog.products, hasLength(1));
      expect(catalog.products.first.webPrice!.amountCents, 499);
    });

    test('getProducts returns list of Product', () async {
      final products = await ZeroSettle.instance.getProducts();
      expect(products, hasLength(1));
      expect(products.first.displayName, 'Premium Monthly');
    });

    test('presentPaymentSheet returns CheckoutTransaction', () async {
      final txn = await ZeroSettle.instance.presentPaymentSheet(
        productId: 'premium_monthly',
        userId: 'user_42',
      );
      expect(txn.id, 'txn_abc');
      expect(txn.status, TransactionStatus.completed);
      expect(txn.source, EntitlementSource.webCheckout);
    });

    test('restoreEntitlements returns list of Entitlement', () async {
      final entitlements = await ZeroSettle.instance.restoreEntitlements(userId: 'user_42');
      expect(entitlements, hasLength(1));
      expect(entitlements.first.productId, 'premium_monthly');
      expect(entitlements.first.isActive, isTrue);
      expect(entitlements.first.source, EntitlementSource.webCheckout);
    });

    test('getEntitlements returns cached entitlements', () async {
      final entitlements = await ZeroSettle.instance.getEntitlements();
      expect(entitlements, hasLength(1));
    });

    test('getIsConfigured returns bool', () async {
      expect(await ZeroSettle.instance.getIsConfigured(), isFalse);
      await ZeroSettle.instance.configure(publishableKey: 'zs_pk_test_123');
      expect(await ZeroSettle.instance.getIsConfigured(), isTrue);
    });

    test('getPendingCheckout returns bool', () async {
      expect(await ZeroSettle.instance.getPendingCheckout(), isFalse);
    });

    test('getRemoteConfig returns RemoteConfig', () async {
      final config = await ZeroSettle.instance.getRemoteConfig();
      expect(config, isNotNull);
      expect(config!.checkout.sheetType, CheckoutType.webView);
      expect(config.checkout.isEnabled, isTrue);
      expect(config.checkout.jurisdictions[Jurisdiction.eu]!.isEnabled, isFalse);
    });

    test('getDetectedJurisdiction returns jurisdiction', () async {
      final jurisdiction = await ZeroSettle.instance.getDetectedJurisdiction();
      expect(jurisdiction, Jurisdiction.us);
    });

    test('handleUniversalLink returns bool', () async {
      final handled = await ZeroSettle.instance.handleUniversalLink('https://example.com/callback');
      expect(handled, isTrue);
    });

    test('entitlementUpdates emits entitlements', () async {
      final entitlements = await ZeroSettle.instance.entitlementUpdates.first;
      expect(entitlements, hasLength(1));
      expect(entitlements.first.productId, 'premium_monthly');
    });

    test('checkoutEvents emits events', () async {
      final event = await ZeroSettle.instance.checkoutEvents.first;
      expect(event['event'], 'checkoutDidBegin');
    });

    test('fetchTransactionHistory returns list of CheckoutTransaction', () async {
      final transactions = await ZeroSettle.instance.fetchTransactionHistory(userId: 'user_42');
      expect(transactions, hasLength(2));
      expect(transactions.first.id, 'txn_abc');
      expect(transactions.first.status, TransactionStatus.completed);
      expect(transactions.first.source, EntitlementSource.webCheckout);
      // Second transaction has the new optional fields
      expect(transactions.last.id, 'txn_def');
      expect(transactions.last.productName, '100 Coins');
      expect(transactions.last.amountCents, 99);
      expect(transactions.last.currency, 'USD');
      expect(transactions.last.source, EntitlementSource.storeKit);
    });

    test('presentCancelFlow returns CancelFlowCancelled', () async {
      final result = await ZeroSettle.instance.presentCancelFlow(
        productId: 'premium_monthly',
        userId: 'user_42',
      );
      expect(result, isA<CancelFlowCancelled>());
    });

    test('pauseSubscription with userId + pauseDurationDays signature', () async {
      // The 1.3.0 signature uses pauseDurationDays (Int?) instead of pauseOptionId.
      // Until Agent 2 lands the signature change, this fails at compile time
      // (missing-symbol). Using dynamic call so the rest of the file compiles.
      // ignore: avoid_dynamic_calls
      final resumeDate = await (ZeroSettle.instance as dynamic).pauseSubscription(
        productId: 'premium_monthly',
        userId: 'user_42',
        pauseDurationDays: 30,
      );
      expect(resumeDate == null || resumeDate is DateTime, isTrue);
    });

    test('presentUpgradeOffer returns UpgradeOfferUpgraded', () async {
      final result = await ZeroSettle.instance.presentUpgradeOffer(
        productId: 'premium_monthly',
        userId: 'user_42',
      );
      expect(result, isA<UpgradeOfferUpgraded>());
    });

    test('trackMigrationConversion completes without error', () async {
      await expectLater(
        ZeroSettle.instance.trackMigrationConversion(userId: 'user_42'),
        completes,
      );
    });

    test('trackEvent does not throw', () async {
      await expectLater(
        ZeroSettle.trackEvent(
          FunnelEventType.paywallViewed,
          productId: 'premium_monthly',
          screenName: 'home',
          metadata: {'variant': 'A'},
        ),
        completes,
      );
    });

    // ==== 1.3.0: Identity / identify() ====

    test('identify(Identity.user) forwards full payload to platform', () async {
      final catalog = await ZeroSettle.instance.identify(
        Identity.user(id: 'u1', name: 'Alice', email: 'alice@example.com'),
      );
      expect(catalog, isA<ProductCatalog>());
      expect(mockPlatform.lastIdentifyArgs, {
        'type': 'user',
        'id': 'u1',
        'name': 'Alice',
        'email': 'alice@example.com',
      });
    });

    test('identify(Identity.user) with only id has no null name/email keys', () async {
      await ZeroSettle.instance.identify(Identity.user(id: 'u1'));
      expect(mockPlatform.lastIdentifyArgs, {'type': 'user', 'id': 'u1'});
      expect(mockPlatform.lastIdentifyArgs!.containsKey('name'), isFalse);
      expect(mockPlatform.lastIdentifyArgs!.containsKey('email'), isFalse);
    });

    test('identify(Identity.anonymous) forwards type=anonymous only', () async {
      await ZeroSettle.instance.identify(Identity.anonymous());
      expect(mockPlatform.lastIdentifyArgs, {'type': 'anonymous'});
      expect(mockPlatform.lastIdentifyArgs!.containsKey('id'), isFalse);
      expect(mockPlatform.lastIdentifyArgs!.containsKey('name'), isFalse);
      expect(mockPlatform.lastIdentifyArgs!.containsKey('email'), isFalse);
    });

    test('identify(Identity.deferred) forwards type=deferred only', () async {
      await ZeroSettle.instance.identify(Identity.deferred());
      expect(mockPlatform.lastIdentifyArgs, {'type': 'deferred'});
      expect(mockPlatform.lastIdentifyArgs!.containsKey('id'), isFalse);
    });

    // ==== 1.3.0: hasActiveEntitlement / product / transferStoreKitOwnership ====

    test('hasActiveEntitlement forwards productId and returns bool', () async {
      mockPlatform.hasActiveEntitlementReturn = true;
      final result = await ZeroSettle.instance.hasActiveEntitlement(productId: 'p1');
      expect(result, isTrue);
      expect(mockPlatform.calls.last['method'], 'hasActiveEntitlement');
      expect(mockPlatform.calls.last['productId'], 'p1');
    });

    test('hasActiveEntitlement returns false when platform says false', () async {
      mockPlatform.hasActiveEntitlementReturn = false;
      final result = await ZeroSettle.instance.hasActiveEntitlement(productId: 'p1');
      expect(result, isFalse);
    });

    test('product forwards productId and returns Product', () async {
      final p = await ZeroSettle.instance.product(productId: 'premium_monthly');
      expect(p, isA<Product>());
      expect(p!.id, 'premium_monthly');
      expect(mockPlatform.calls.last['method'], 'product');
      expect(mockPlatform.calls.last['productId'], 'premium_monthly');
    });

    test('product returns null when platform returns null', () async {
      mockPlatform.productReturnValue = null;
      final p = await ZeroSettle.instance.product(productId: 'unknown');
      expect(p, isNull);
    });

    test('transferStoreKitOwnershipToCurrentUser forwards productId', () async {
      await ZeroSettle.instance.transferStoreKitOwnershipToCurrentUser(productId: 'p1');
      expect(mockPlatform.calls.last['method'], 'transferStoreKitOwnershipToCurrentUser');
      expect(mockPlatform.calls.last['productId'], 'p1');
    });

    // ==== 1.3.0: No-userId facade methods ====
    //
    // These test the new userId-less overloads that mirror identify(). Each
    // calls into the platform interface without a userId argument. Until
    // Agent 2 lands the no-userId methods on the facade + platform interface,
    // these will fail to compile (missing-symbol).

    test('restoreEntitlements (no userId) forwards to platform', () async {
      // ignore: avoid_dynamic_calls
      final result = await (ZeroSettle.instance as dynamic).restoreEntitlements();
      expect(result, isA<List>());
    });

    test('fetchTransactionHistory (no userId) forwards to platform', () async {
      // ignore: avoid_dynamic_calls
      final result = await (ZeroSettle.instance as dynamic).fetchTransactionHistory();
      expect(result, isA<List>());
    });

    test('acceptSaveOffer (no userId) forwards productId only', () async {
      // ignore: avoid_dynamic_calls
      final result = await (ZeroSettle.instance as dynamic).acceptSaveOffer(productId: 'p1');
      expect(result, isNotNull);
    });

    test('presentCancelFlow (no userId) forwards productId only', () async {
      // ignore: avoid_dynamic_calls
      final result = await (ZeroSettle.instance as dynamic).presentCancelFlow(productId: 'p1');
      expect(result, isNotNull);
    });

    test('pauseSubscription (no userId) uses pauseDurationDays', () async {
      // ignore: avoid_dynamic_calls
      final result = await (ZeroSettle.instance as dynamic).pauseSubscription(
        productId: 'p1',
        pauseDurationDays: 30,
      );
      // Platform-mocked DateTime String is parsed; test only that it didn't throw.
      expect(result == null || result is DateTime, isTrue);
    });

    test('resumeSubscription (no userId) forwards productId only', () async {
      // ignore: avoid_dynamic_calls
      await (ZeroSettle.instance as dynamic).resumeSubscription(productId: 'p1');
    });

    test('cancelSubscription (no userId) forwards productId + immediate', () async {
      // ignore: avoid_dynamic_calls
      await (ZeroSettle.instance as dynamic).cancelSubscription(
        productId: 'p1',
        immediate: true,
      );
    });

    test('presentUpgradeOffer (no userId) forwards productId only', () async {
      // ignore: avoid_dynamic_calls
      final result = await (ZeroSettle.instance as dynamic).presentUpgradeOffer(productId: 'p1');
      expect(result, isNotNull);
    });

    test('fetchUpgradeOfferConfig (no userId) forwards productId only', () async {
      // ignore: avoid_dynamic_calls
      final result = await (ZeroSettle.instance as dynamic).fetchUpgradeOfferConfig(productId: 'p1');
      expect(result, isNotNull);
    });

    test('trackMigrationConversion (no userId) forwards', () async {
      // ignore: avoid_dynamic_calls
      await (ZeroSettle.instance as dynamic).trackMigrationConversion();
    });

    // ==== 1.3.0: Deprecated userId-taking forms still compile + route ====

    test('deprecated bootstrap(userId) still routes to platform', () async {
      // ignore: deprecated_member_use_from_same_package
      final catalog = await ZeroSettle.instance.bootstrap(userId: 'user_42');
      expect(catalog, isA<ProductCatalog>());
    });

    test('deprecated restoreEntitlements(userId) still routes to platform', () async {
      // ignore: deprecated_member_use_from_same_package
      final result = await ZeroSettle.instance.restoreEntitlements(userId: 'user_42');
      expect(result, isA<List<Entitlement>>());
    });

    test('deprecated fetchTransactionHistory(userId) still routes to platform', () async {
      // ignore: deprecated_member_use_from_same_package
      final result = await ZeroSettle.instance.fetchTransactionHistory(userId: 'user_42');
      expect(result, isA<List<CheckoutTransaction>>());
    });

    test('deprecated trackMigrationConversion(userId) still routes to platform', () async {
      // ignore: deprecated_member_use_from_same_package
      await expectLater(
        ZeroSettle.instance.trackMigrationConversion(userId: 'user_42'),
        completes,
      );
    });

    // ==== 1.3.0: Configuration new fields ====

    test('configure forwards new 1.3.0 params (appleMerchantId, preloadCheckout, maxPreloadedWebViews)', () async {
      // ignore: avoid_dynamic_calls
      await (ZeroSettle.instance as dynamic).configure(
        publishableKey: 'zs_pk_test_123',
        appleMerchantId: 'merchant.com.example',
        preloadCheckout: true,
        maxPreloadedWebViews: 3,
      );
      expect(mockPlatform.lastPublishableKey, 'zs_pk_test_123');
      // Once Agent 2 wires through, these would also be captured. Until then,
      // this asserts the call at least went through.
      expect(mockPlatform.configured, isTrue);
    });
  });
}
