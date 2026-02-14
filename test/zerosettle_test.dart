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

  @override
  Future<void> configure({required String publishableKey, bool syncStoreKitTransactions = true}) async {
    configured = true;
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
    int freeTrialDays = 0,
    bool dismissible = true,
  }) async {
    return _sampleTransactionMap();
  }

  @override
  Future<void> preloadPaymentSheet({required String productId, String? userId, int freeTrialDays = 0}) async {}

  @override
  Future<void> warmUpPaymentSheet({required String productId, String? userId, int freeTrialDays = 0}) async {}

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
}

// -- Sample Data Helpers --

Map<String, dynamic> _sampleProductMap() => {
  'id': 'premium_monthly',
  'displayName': 'Premium Monthly',
  'productDescription': 'Unlock all features',
  'type': 'auto_renewable_subscription',
  'webPrice': {'amountMicros': 4990000, 'currencyCode': 'USD'},
  'appStorePrice': {'amountMicros': 5990000, 'currencyCode': 'USD'},
  'syncedToASC': true,
  'storeKitAvailable': true,
  'storeKitPrice': {'amountMicros': 5990000, 'currencyCode': 'USD'},
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
      expect(catalog.products.first.webPrice.amountMicros, 4990000);
    });

    test('getProducts returns list of ZSProduct', () async {
      final products = await ZeroSettle.instance.getProducts();
      expect(products, hasLength(1));
      expect(products.first.displayName, 'Premium Monthly');
    });

    test('presentPaymentSheet returns ZSTransaction', () async {
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
      expect(config!.checkout.sheetType, CheckoutType.webview);
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
  });
}
