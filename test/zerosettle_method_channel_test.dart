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

  // Captures every channel call so individual tests can inspect args.
  final List<MethodCall> channelCalls = [];

  setUp(() {
    channelCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        channelCalls.add(methodCall);
        switch (methodCall.method) {
          case 'configure':
            return null;
          case 'bootstrap':
            return sampleCatalog;
          case 'identify':
            return sampleCatalog;
          case 'logout':
            return null;
          case 'setCustomer':
            return null;
          case 'transferStoreKitOwnershipToCurrentUser':
            return null;
          case 'hasActiveEntitlement':
            return true;
          case 'product':
            return sampleProduct;
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
          case 'fetchTransactionHistory':
            return [sampleTransaction];
          case 'fetchCancelFlowConfig':
            return {'enabled': false, 'questions': <Map<String, dynamic>>[]};
          case 'pauseSubscription':
            return '2026-04-01T00:00:00.000Z';
          case 'resumeSubscription':
            return null;
          case 'cancelSubscription':
            return null;
          case 'acceptSaveOffer':
            return {'discountPercent': 20};
          case 'submitCancelFlowResponse':
            return null;
          case 'getCancelFlowConfig':
            return null;
          case 'presentCancelFlow':
            return 'cancelled';
          case 'presentUpgradeOffer':
            return 'dismissed';
          case 'fetchUpgradeOfferConfig':
            return {'available': false};
          case 'trackMigrationConversion':
            return null;
          case 'resetMigrateTipState':
            return null;
          case 'trackEvent':
            return null;
          case 'presentSaveTheSaleSheet':
            return 'dismissed';
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

  // ==== 1.3.0: Identity / identify channel ====

  test('identify channel call has type/id/name/email arg shape', () async {
    await platform.identify(
      type: 'user',
      id: 'u1',
      name: 'Alice',
      email: 'alice@example.com',
    );
    final call = channelCalls.firstWhere((c) => c.method == 'identify');
    final args = Map<String, dynamic>.from(call.arguments as Map);
    expect(args['type'], 'user');
    expect(args['id'], 'u1');
    expect(args['name'], 'Alice');
    expect(args['email'], 'alice@example.com');
  });

  test('identify channel call omits null fields', () async {
    await platform.identify(type: 'user', id: 'u1');
    final call = channelCalls.firstWhere((c) => c.method == 'identify');
    final args = Map<String, dynamic>.from(call.arguments as Map);
    expect(args['type'], 'user');
    expect(args['id'], 'u1');
    expect(args.containsKey('name'), isFalse);
    expect(args.containsKey('email'), isFalse);
  });

  test('identify channel call for anonymous has only type', () async {
    await platform.identify(type: 'anonymous');
    final call = channelCalls.firstWhere((c) => c.method == 'identify');
    final args = Map<String, dynamic>.from(call.arguments as Map);
    expect(args['type'], 'anonymous');
    expect(args.containsKey('id'), isFalse);
    expect(args.containsKey('name'), isFalse);
    expect(args.containsKey('email'), isFalse);
  });

  test('identify channel call for deferred has only type', () async {
    await platform.identify(type: 'deferred');
    final call = channelCalls.firstWhere((c) => c.method == 'identify');
    final args = Map<String, dynamic>.from(call.arguments as Map);
    expect(args['type'], 'deferred');
    expect(args.length, 1);
  });

  // ==== 1.3.0: hasActiveEntitlement / product / transfer ====

  test('hasActiveEntitlement channel call carries productId', () async {
    final result = await platform.hasActiveEntitlement(productId: 'p1');
    expect(result, isTrue);
    final call = channelCalls.firstWhere((c) => c.method == 'hasActiveEntitlement');
    expect((call.arguments as Map)['productId'], 'p1');
  });

  test('product channel call carries productId and returns map', () async {
    final result = await platform.product(productId: 'premium_monthly');
    expect(result, isNotNull);
    expect(result!['id'], 'premium_monthly');
    final call = channelCalls.firstWhere((c) => c.method == 'product');
    expect((call.arguments as Map)['productId'], 'premium_monthly');
  });

  test('transferStoreKitOwnershipToCurrentUser channel call carries productId', () async {
    await platform.transferStoreKitOwnershipToCurrentUser(productId: 'p1');
    final call = channelCalls.firstWhere(
      (c) => c.method == 'transferStoreKitOwnershipToCurrentUser',
    );
    expect((call.arguments as Map)['productId'], 'p1');
  });

  // ==== 1.3.0: pauseSubscription signature change to pauseDurationDays ====

  test('pauseSubscription channel call uses pauseDurationDays (not pauseOptionId)', () async {
    // Once Agent 2 lands the signature change, the platform method call
    // should put `pauseDurationDays` (not `pauseOptionId`) on the wire.
    // Until then, this fails at compile time.
    // ignore: avoid_dynamic_calls
    final result = await (platform as dynamic).pauseSubscriptionForCurrentUser(
      productId: 'p1',
      pauseDurationDays: 30,
    );
    expect(result, isNotNull);
    final call = channelCalls.firstWhere((c) => c.method == 'pauseSubscription');
    final args = Map<String, dynamic>.from(call.arguments as Map);
    expect(args.containsKey('pauseDurationDays'), isTrue);
    expect(args['pauseDurationDays'], 30);
    expect(args.containsKey('pauseOptionId'), isFalse);
    expect(args.containsKey('userId'), isFalse);
  });

  // ==== 1.3.0: No-userId channel calls reuse existing channel names ====
  // Per the spec, Agent 2 reuses existing channel names and dispatches based
  // on userId presence. The new no-userId platform overloads should send
  // calls without a `userId` arg key.

  test('restoreEntitlements (no userId) channel call has no userId key', () async {
    // ignore: avoid_dynamic_calls
    await (platform as dynamic).restoreEntitlementsForCurrentUser();
    final call = channelCalls.firstWhere((c) => c.method == 'restoreEntitlements');
    final args = call.arguments as Map?;
    if (args != null) {
      expect(args.containsKey('userId'), isFalse);
    }
  });

  test('fetchTransactionHistory (no userId) channel call has no userId key', () async {
    // ignore: avoid_dynamic_calls
    await (platform as dynamic).fetchTransactionHistoryForCurrentUser();
    final call = channelCalls.firstWhere((c) => c.method == 'fetchTransactionHistory');
    final args = call.arguments as Map?;
    if (args != null) {
      expect(args.containsKey('userId'), isFalse);
    }
  });

  test('acceptSaveOffer (no userId) channel call carries productId only', () async {
    // ignore: avoid_dynamic_calls
    await (platform as dynamic).acceptSaveOfferForCurrentUser(productId: 'p1');
    final call = channelCalls.firstWhere((c) => c.method == 'acceptSaveOffer');
    final args = Map<String, dynamic>.from(call.arguments as Map);
    expect(args['productId'], 'p1');
    expect(args.containsKey('userId'), isFalse);
  });

  test('presentCancelFlow (no userId) channel call carries productId only', () async {
    // ignore: avoid_dynamic_calls
    await (platform as dynamic).presentCancelFlowForCurrentUser(productId: 'p1');
    final call = channelCalls.firstWhere((c) => c.method == 'presentCancelFlow');
    final args = Map<String, dynamic>.from(call.arguments as Map);
    expect(args['productId'], 'p1');
    expect(args.containsKey('userId'), isFalse);
  });

  test('resumeSubscription (no userId) channel call carries productId only', () async {
    // ignore: avoid_dynamic_calls
    await (platform as dynamic).resumeSubscriptionForCurrentUser(productId: 'p1');
    final call = channelCalls.firstWhere((c) => c.method == 'resumeSubscription');
    final args = Map<String, dynamic>.from(call.arguments as Map);
    expect(args['productId'], 'p1');
    expect(args.containsKey('userId'), isFalse);
  });

  test('cancelSubscription (no userId) channel call carries productId + immediate', () async {
    // ignore: avoid_dynamic_calls
    await (platform as dynamic).cancelSubscriptionForCurrentUser(productId: 'p1', immediate: true);
    final call = channelCalls.firstWhere((c) => c.method == 'cancelSubscription');
    final args = Map<String, dynamic>.from(call.arguments as Map);
    expect(args['productId'], 'p1');
    expect(args['immediate'], isTrue);
    expect(args.containsKey('userId'), isFalse);
  });

  test('presentUpgradeOffer (no userId) channel call carries productId only', () async {
    // ignore: avoid_dynamic_calls
    await (platform as dynamic).presentUpgradeOfferForCurrentUser(productId: 'p1');
    final call = channelCalls.firstWhere((c) => c.method == 'presentUpgradeOffer');
    final args = Map<String, dynamic>.from(call.arguments as Map);
    expect(args['productId'], 'p1');
    expect(args.containsKey('userId'), isFalse);
  });

  test('fetchUpgradeOfferConfig (no userId) channel call carries productId only', () async {
    // ignore: avoid_dynamic_calls
    await (platform as dynamic).fetchUpgradeOfferConfigForCurrentUser(productId: 'p1');
    final call = channelCalls.firstWhere((c) => c.method == 'fetchUpgradeOfferConfig');
    final args = Map<String, dynamic>.from(call.arguments as Map);
    expect(args['productId'], 'p1');
    expect(args.containsKey('userId'), isFalse);
  });

  test('trackMigrationConversion (no userId) channel call has no userId key', () async {
    // ignore: avoid_dynamic_calls
    await (platform as dynamic).trackMigrationConversionForCurrentUser();
    final call = channelCalls.firstWhere((c) => c.method == 'trackMigrationConversion');
    final args = call.arguments as Map?;
    if (args != null) {
      expect(args.containsKey('userId'), isFalse);
    }
  });

  // ==== 1.3.0: configure channel includes new keys ====

  test('configure channel call includes appleMerchantId / preloadCheckout / maxPreloadedWebViews', () async {
    // ignore: avoid_dynamic_calls
    await (platform as dynamic).configure(
      publishableKey: 'zs_pk_test_123',
      appleMerchantId: 'merchant.com.example',
      preloadCheckout: true,
      maxPreloadedWebViews: 3,
    );
    final call = channelCalls.firstWhere((c) => c.method == 'configure');
    final args = Map<String, dynamic>.from(call.arguments as Map);
    expect(args['publishableKey'], 'zs_pk_test_123');
    expect(args['appleMerchantId'], 'merchant.com.example');
    expect(args['preloadCheckout'], isTrue);
    expect(args['maxPreloadedWebViews'], 3);
  });

  test('configure channel call without new keys still works (back-compat)', () async {
    await platform.configure(publishableKey: 'zs_pk_test_123');
    final call = channelCalls.firstWhere((c) => c.method == 'configure');
    final args = Map<String, dynamic>.from(call.arguments as Map);
    expect(args['publishableKey'], 'zs_pk_test_123');
  });
}
