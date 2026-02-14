import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerosettle/zerosettle_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final MethodChannelZeroSettle platform = MethodChannelZeroSettle();
  const MethodChannel channel = MethodChannel('zerosettle');

  final sampleProduct = {
    'id': 'premium_monthly',
    'displayName': 'Premium Monthly',
    'productDescription': 'Unlock all features',
    'type': 'auto_renewable_subscription',
    'webPrice': {'amountMicros': 4990000, 'currencyCode': 'USD'},
    'syncedToASC': true,
    'storeKitAvailable': false,
  };

  final sampleCatalog = {
    'products': [sampleProduct],
    'config': {
      'checkout': {
        'sheetType': 'webview',
        'isEnabled': true,
        'jurisdictions': <String, dynamic>{},
      },
    },
  };

  final sampleTransaction = {
    'id': 'txn_abc',
    'productId': 'premium_monthly',
    'status': 'completed',
    'source': 'web_checkout',
    'purchasedAt': '2025-01-15T10:30:00.000Z',
  };

  final sampleEntitlement = {
    'id': 'ent_123',
    'productId': 'premium_monthly',
    'source': 'web_checkout',
    'isActive': true,
    'purchasedAt': '2025-01-15T10:30:00.000Z',
  };

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'configure':
            return null;
          case 'bootstrap':
            return sampleCatalog;
          case 'fetchProducts':
            return sampleCatalog;
          case 'getProducts':
            return [sampleProduct];
          case 'presentPaymentSheet':
            return sampleTransaction;
          case 'preloadPaymentSheet':
            return null;
          case 'warmUpPaymentSheet':
            return null;
          case 'restoreEntitlements':
            return [sampleEntitlement];
          case 'getEntitlements':
            return [sampleEntitlement];
          case 'openCustomerPortal':
            return null;
          case 'showManageSubscription':
            return null;
          case 'handleUniversalLink':
            return true;
          case 'getIsConfigured':
            return true;
          case 'getPendingCheckout':
            return false;
          case 'getRemoteConfig':
            return sampleCatalog['config'];
          case 'getDetectedJurisdiction':
            return 'us';
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('configure completes without error', () async {
    await platform.configure(publishableKey: 'zs_pk_test_123');
  });

  test('bootstrap returns catalog map', () async {
    final result = await platform.bootstrap(userId: 'user_42');
    expect(result['products'], isList);
    expect((result['products'] as List).length, 1);
  });

  test('fetchProducts returns catalog map', () async {
    final result = await platform.fetchProducts(userId: 'user_42');
    expect(result['products'], isList);
  });

  test('getProducts returns product list', () async {
    final result = await platform.getProducts();
    expect(result, hasLength(1));
    expect(result.first['id'], 'premium_monthly');
  });

  test('presentPaymentSheet returns transaction map', () async {
    final result = await platform.presentPaymentSheet(
      productId: 'premium_monthly',
      userId: 'user_42',
    );
    expect(result['id'], 'txn_abc');
    expect(result['status'], 'completed');
  });

  test('restoreEntitlements returns entitlement list', () async {
    final result = await platform.restoreEntitlements(userId: 'user_42');
    expect(result, hasLength(1));
    expect(result.first['productId'], 'premium_monthly');
  });

  test('getEntitlements returns entitlement list', () async {
    final result = await platform.getEntitlements();
    expect(result, hasLength(1));
  });

  test('handleUniversalLink returns true', () async {
    final result = await platform.handleUniversalLink('https://example.com');
    expect(result, isTrue);
  });

  test('getIsConfigured returns true', () async {
    expect(await platform.getIsConfigured(), isTrue);
  });

  test('getPendingCheckout returns false', () async {
    expect(await platform.getPendingCheckout(), isFalse);
  });

  test('getRemoteConfig returns config map', () async {
    final result = await platform.getRemoteConfig();
    expect(result, isNotNull);
    expect(result!['checkout'], isNotNull);
  });

  test('getDetectedJurisdiction returns jurisdiction string', () async {
    expect(await platform.getDetectedJurisdiction(), 'us');
  });
}
