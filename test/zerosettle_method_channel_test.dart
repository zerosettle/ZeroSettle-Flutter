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
          case 'getSdkVersion':
            return '1.4.0';
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
          // 1.3.0 new primitives
          case 'purchase':
            return sampleTransaction;
          case 'purchaseViaStoreKit':
            return {
              'id': '2000000000000001',
              'productId': 'premium_monthly',
              'status': 'completed',
              'source': 'store_kit',
              'purchasedAt': '2025-03-01T08:00:00.000Z',
              'originalTransactionId': '2000000000000000',
            };
          case 'purchaseViaPlayBilling':
            return {
              'id': 'GPA.0000-0000-0000-00000',
              'productId': 'premium_monthly',
              'status': 'completed',
              // Wire source is `play_store` — same EntitlementSource value
              // as a cross-platform Play purchase (see ext/ModelToFlutterMap.kt).
              'source': 'play_store',
              'purchasedAt': '2026-05-12T08:00:00.000Z',
            };
          case 'transferPlayOwnershipToCurrentUser':
            return null;
          case 'getCurrentUserId':
            return 'u_42';
          case 'getIsBootstrapped':
            return true;
          case 'getPendingClaims':
            return [
              {
                'productId': 'premium_monthly',
                'originalTransactionId': '2000000000000000',
                'existingOwnerHint': 'abc123',
              },
            ];
          case 'recommendedAppAccountToken':
            return '550e8400-e29b-41d4-a716-446655440000';
          // 1.3.2 Apple Pay primitives
          case 'presentApplePaySetup':
            return null;
          case 'getIsApplePayOnly':
            return true;
          case 'getApplePayState':
            return 'setupRequired';
          // UCB
          case 'getIsUcbEnabled':
            return true;
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

  // Regression: setBaseUrlOverride was missing its concrete @override in
  // MethodChannelZeroSettle, falling through to the abstract default that
  // throws UnimplementedError. This broke any env with a baseUrlOverride
  // (staging, internalSandbox, internalLive). See c1696f1.
  test('setBaseUrlOverride is implemented by MethodChannelZeroSettle', () async {
    await platform.setBaseUrlOverride('https://example.test/v1');
    final call = channelCalls.firstWhere((c) => c.method == 'setBaseUrlOverride');
    expect((call.arguments as Map)['url'], 'https://example.test/v1');
  });

  test('setBaseUrlOverride with null url omits the url key', () async {
    await platform.setBaseUrlOverride(null);
    final call = channelCalls.firstWhere((c) => c.method == 'setBaseUrlOverride');
    expect((call.arguments as Map).containsKey('url'), isFalse);
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

  test('getSdkVersion invokes the channel', () async {
    await platform.getSdkVersion();
    expect(channelCalls.any((c) => c.method == 'getSdkVersion'), isTrue);
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

  test('configure channel call carries Android-only Play knobs through to the wire', () async {
    // The Play knobs (playLicenseKey / syncPlayPurchases / strictAck) are
    // Android-only — iOS reads them and drops them. The Dart wire must
    // still serialize them through the channel so the Android plugin can
    // forward them into ZeroSettleConfig.
    // ignore: avoid_dynamic_calls
    await (platform as dynamic).configure(
      publishableKey: 'zs_pk_test_123',
      playLicenseKey: 'MIIB-fake-rsa-public-key',
      syncPlayPurchases: false,
      strictAck: true,
    );
    final call = channelCalls.firstWhere((c) => c.method == 'configure');
    final args = Map<String, dynamic>.from(call.arguments as Map);
    expect(args['playLicenseKey'], 'MIIB-fake-rsa-public-key');
    expect(args['syncPlayPurchases'], isFalse);
    expect(args['strictAck'], isTrue);
  });

  test('configure channel call defaults Play knobs to SDK defaults when omitted', () async {
    // playLicenseKey omitted (Dart side guards `if (... != null)` so the
    // key is absent), syncPlayPurchases defaults to true, strictAck
    // defaults to false. These defaults are part of the Dart contract —
    // mirror the SDK's ZeroSettleConfig defaults.
    await platform.configure(publishableKey: 'zs_pk_test_123');
    final call = channelCalls.firstWhere((c) => c.method == 'configure');
    final args = Map<String, dynamic>.from(call.arguments as Map);
    expect(args.containsKey('playLicenseKey'), isFalse);
    expect(args['syncPlayPurchases'], isTrue);
    expect(args['strictAck'], isFalse);
  });

  // ==== 1.3.0 new primitives ====

  test('purchase channel call carries productId only (no presentation)', () async {
    final result = await platform.purchase(productId: 'premium_monthly');
    expect(result['id'], 'txn_abc');
    final call = channelCalls.firstWhere((c) => c.method == 'purchase');
    final args = Map<String, dynamic>.from(call.arguments as Map);
    expect(args['productId'], 'premium_monthly');
    expect(args.containsKey('userId'), isFalse);
    expect(args.containsKey('presentation'), isFalse);
  });

  test('purchase channel call forwards presentation raw value', () async {
    await platform.purchase(productId: 'premium_monthly', presentation: 'native_pay');
    final call = channelCalls.firstWhere((c) => c.method == 'purchase');
    final args = Map<String, dynamic>.from(call.arguments as Map);
    expect(args['productId'], 'premium_monthly');
    expect(args['presentation'], 'native_pay');
  });

  test('purchaseViaStoreKit channel call carries productId only', () async {
    final result = await platform.purchaseViaStoreKit(productId: 'premium_monthly');
    expect(result['id'], '2000000000000001');
    expect(result['source'], 'store_kit');
    final call = channelCalls.firstWhere((c) => c.method == 'purchaseViaStoreKit');
    final args = Map<String, dynamic>.from(call.arguments as Map);
    expect(args['productId'], 'premium_monthly');
    expect(args.containsKey('userId'), isFalse);
  });

  // ==== D1: purchaseViaPlayBilling Android peer ====

  test('purchaseViaPlayBilling channel call carries productId only', () async {
    final result =
        await platform.purchaseViaPlayBilling(productId: 'premium_monthly');
    expect(result['id'], 'GPA.0000-0000-0000-00000');
    // Wire source is `play_store` — same EntitlementSource value as a
    // cross-platform Play purchase (matches ext/ModelToFlutterMap.kt).
    expect(result['source'], 'play_store');
    final call =
        channelCalls.firstWhere((c) => c.method == 'purchaseViaPlayBilling');
    final args = Map<String, dynamic>.from(call.arguments as Map);
    expect(args['productId'], 'premium_monthly');
    // No userId / originalTransactionId / presentation — purchase identity
    // comes from the prior identify() call.
    expect(args.containsKey('userId'), isFalse);
    expect(args.containsKey('originalTransactionId'), isFalse);
    expect(args.containsKey('presentation'), isFalse);
  });

  // ==== D2: transferPlayOwnershipToCurrentUser Android peer ====

  test(
      'transferPlayOwnershipToCurrentUser channel call carries productId + originalTransactionId',
      () async {
    await platform.transferPlayOwnershipToCurrentUser(
      productId: 'premium_monthly',
      originalTransactionId: 'GPA.token_abc',
    );
    final call = channelCalls.firstWhere(
      (c) => c.method == 'transferPlayOwnershipToCurrentUser',
    );
    final args = Map<String, dynamic>.from(call.arguments as Map);
    expect(args['productId'], 'premium_monthly');
    expect(args['originalTransactionId'], 'GPA.token_abc');
    // No userId on the wire — current-user-scoped (matches the StoreKit peer).
    expect(args.containsKey('userId'), isFalse);
  });

  test('getCurrentUserId returns user id string', () async {
    expect(await platform.getCurrentUserId(), 'u_42');
    final call = channelCalls.firstWhere((c) => c.method == 'getCurrentUserId');
    expect(call.arguments, isNull);
  });

  test('getIsBootstrapped returns bool', () async {
    expect(await platform.getIsBootstrapped(), isTrue);
    final call = channelCalls.firstWhere((c) => c.method == 'getIsBootstrapped');
    expect(call.arguments, isNull);
  });

  test('getPendingClaims returns claim list', () async {
    final result = await platform.getPendingClaims();
    expect(result, hasLength(1));
    expect(result.first['productId'], 'premium_monthly');
    expect(result.first['originalTransactionId'], '2000000000000000');
    expect(result.first['existingOwnerHint'], 'abc123');
    final call = channelCalls.firstWhere((c) => c.method == 'getPendingClaims');
    expect(call.arguments, isNull);
  });

  test('recommendedAppAccountToken returns UUID string', () async {
    final token = await platform.recommendedAppAccountToken();
    expect(token, '550e8400-e29b-41d4-a716-446655440000');
    final call = channelCalls.firstWhere(
      (c) => c.method == 'recommendedAppAccountToken',
    );
    expect(call.arguments, isNull);
  });

  // ==== 1.3.2: Apple Pay primitives ====

  test('configure channel call forwards applePaySetupBehavior raw value', () async {
    await platform.configure(
      publishableKey: 'zs_pk_test_123',
      applePaySetupBehavior: 'delegateToApp',
    );
    final call = channelCalls.firstWhere((c) => c.method == 'configure');
    final args = Map<String, dynamic>.from(call.arguments as Map);
    expect(args['applePaySetupBehavior'], 'delegateToApp');
  });

  test('configure channel call omits applePaySetupBehavior when null', () async {
    await platform.configure(publishableKey: 'zs_pk_test_123');
    final call = channelCalls.firstWhere((c) => c.method == 'configure');
    final args = Map<String, dynamic>.from(call.arguments as Map);
    expect(args.containsKey('applePaySetupBehavior'), isFalse);
  });

  test('presentApplePaySetup channel call has no arguments', () async {
    await platform.presentApplePaySetup();
    final call =
        channelCalls.firstWhere((c) => c.method == 'presentApplePaySetup');
    expect(call.arguments, isNull);
  });

  test('getIsApplePayOnly returns the platform bool', () async {
    expect(await platform.getIsApplePayOnly(), isTrue);
    final call =
        channelCalls.firstWhere((c) => c.method == 'getIsApplePayOnly');
    expect(call.arguments, isNull);
  });

  test('getApplePayState returns raw state string', () async {
    expect(await platform.getApplePayState(), 'setupRequired');
    final call =
        channelCalls.firstWhere((c) => c.method == 'getApplePayState');
    expect(call.arguments, isNull);
  });

  test('applePayStateUpdates EventChannel forwards string events', () async {
    const channelName = 'zerosettle/apple_pay_state_updates';
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final emissions = <String>[];
    final sub = platform.applePayStateUpdates.listen(emissions.add);

    // Allow listener to register, then emit two values via the EventChannel.
    await Future<void>.delayed(Duration.zero);
    final codec = const StandardMethodCodec();
    for (final raw in ['ready', 'setupRequired']) {
      final data = codec.encodeSuccessEnvelope(raw);
      await messenger.handlePlatformMessage(channelName, data, (_) {});
    }
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(emissions, ['ready', 'setupRequired']);
  });

  // ==== Gap 5: reactive state streams ====

  test('productsUpdates EventChannel decodes a list of product maps', () async {
    const channelName = 'zerosettle/products_updates';
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final emissions = <List<Map<String, dynamic>>>[];
    final sub = platform.productsUpdates.listen(emissions.add);

    await Future<void>.delayed(Duration.zero);
    final codec = const StandardMethodCodec();
    final payload = <Map<String, Object?>>[
      {'id': 'pro_monthly', 'displayName': 'Pro', 'type': 'auto_renewable_subscription'},
    ];
    final data = codec.encodeSuccessEnvelope(payload);
    await messenger.handlePlatformMessage(channelName, data, (_) {});
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(emissions.length, 1);
    expect(emissions.first.first['id'], 'pro_monthly');
  });

  test('currentUserIdUpdates EventChannel forwards null on logout', () async {
    const channelName = 'zerosettle/current_user_id_updates';
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final emissions = <String?>[];
    final sub = platform.currentUserIdUpdates.listen(emissions.add);

    await Future<void>.delayed(Duration.zero);
    final codec = const StandardMethodCodec();
    // Logged in.
    await messenger.handlePlatformMessage(
      channelName,
      codec.encodeSuccessEnvelope('u_alice'),
      (_) {},
    );
    // Logged out → null event must flow through, not be filtered.
    await messenger.handlePlatformMessage(
      channelName,
      codec.encodeSuccessEnvelope(null),
      (_) {},
    );
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(emissions, ['u_alice', null]);
  });

  test('pendingCheckoutUpdates EventChannel forwards bool events', () async {
    const channelName = 'zerosettle/pending_checkout_updates';
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final emissions = <bool>[];
    final sub = platform.pendingCheckoutUpdates.listen(emissions.add);

    await Future<void>.delayed(Duration.zero);
    final codec = const StandardMethodCodec();
    for (final raw in [true, false]) {
      await messenger.handlePlatformMessage(
        channelName,
        codec.encodeSuccessEnvelope(raw),
        (_) {},
      );
    }
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(emissions, [true, false]);
  });

  test('isBootstrappedUpdates EventChannel forwards bool events', () async {
    const channelName = 'zerosettle/is_bootstrapped_updates';
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final emissions = <bool>[];
    final sub = platform.isBootstrappedUpdates.listen(emissions.add);

    await Future<void>.delayed(Duration.zero);
    final codec = const StandardMethodCodec();
    await messenger.handlePlatformMessage(
      channelName,
      codec.encodeSuccessEnvelope(false),
      (_) {},
    );
    await messenger.handlePlatformMessage(
      channelName,
      codec.encodeSuccessEnvelope(true),
      (_) {},
    );
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(emissions, [false, true]);
  });

  // ==== Task 2: isUcbEnabled ====

  test('getIsUcbEnabled invokes the channel and returns the stubbed value', () async {
    final result = await platform.getIsUcbEnabled();
    expect(result, isTrue);
    final call = channelCalls.firstWhere((c) => c.method == 'getIsUcbEnabled');
    expect(call.arguments, isNull);
  });

  test('isUcbEnabledUpdates EventChannel forwards bool events', () async {
    const channelName = 'zerosettle/is_ucb_enabled_updates';
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final emissions = <bool>[];
    final sub = platform.isUcbEnabledUpdates.listen(emissions.add);

    // Allow listener to register, then emit two values via the EventChannel.
    await Future<void>.delayed(Duration.zero);
    final codec = const StandardMethodCodec();
    for (final raw in [true, false]) {
      final data = codec.encodeSuccessEnvelope(raw);
      await messenger.handlePlatformMessage(channelName, data, (_) {});
    }
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(emissions, [true, false]);
  });
}
