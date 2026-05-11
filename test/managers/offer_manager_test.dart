import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerosettle/zerosettle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OfferManager manager;
  const handleId = 'offer_test_handle_42';
  final methodChannel = MethodChannel('zerosettle/offer_manager_$handleId');

  final List<MethodCall> methodCalls = [];

  setUp(() {
    methodCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
      methodCalls.add(call);
      switch (call.method) {
        case 'getState':
          return <String, dynamic>{
            'state': 'eligible',
            'isLoading': false,
            'storekitCancelRequired': false,
          };
        case 'startCheckout':
          return 'https://checkout.zerosettle.io/cs_test_offer';
        case 'preloadCheckout':
          return 'https://checkout.zerosettle.io/cs_preload_offer';
        default:
          return null;
      }
    });
    manager = OfferManager.fromHandleId(handleId);
  });

  tearDown(() async {
    await manager.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  test('handleId getter returns the constructor argument', () {
    expect(manager.handleId, handleId);
  });

  test('getState parses state map', () async {
    final s = await manager.getState();
    expect(s.state, OfferState.eligible);
    expect(s.isLoading, isFalse);
    expect(methodCalls.last.method, 'getState');
  });

  test('present invokes channel', () async {
    await manager.present();
    expect(methodCalls.any((c) => c.method == 'present'), isTrue);
  });

  test('dismiss invokes channel', () async {
    await manager.dismiss();
    expect(methodCalls.any((c) => c.method == 'dismiss'), isTrue);
  });

  test('startCheckout returns parsed URL', () async {
    final url = await manager.startCheckout();
    expect(url, isNotNull);
    expect(url!.host, 'checkout.zerosettle.io');
    expect(url.path, '/cs_test_offer');
  });

  test('startCheckout forwards stripeCustomerId arg', () async {
    await manager.startCheckout(stripeCustomerId: 'cus_test_xyz');
    final call = methodCalls.firstWhere((c) => c.method == 'startCheckout');
    expect((call.arguments as Map)['stripeCustomerId'], 'cus_test_xyz');
  });

  test('preloadCheckout returns parsed URL', () async {
    final url = await manager.preloadCheckout();
    expect(url, isNotNull);
    expect(url!.host, 'checkout.zerosettle.io');
    expect(url.path, '/cs_preload_offer');
  });

  test('preloadCheckout forwards stripeCustomerId arg', () async {
    await manager.preloadCheckout(stripeCustomerId: 'cus_preload_xyz');
    final call =
        methodCalls.firstWhere((c) => c.method == 'preloadCheckout');
    expect((call.arguments as Map)['stripeCustomerId'], 'cus_preload_xyz');
  });

  test('markCheckoutSucceeded forwards transactionId', () async {
    await manager.markCheckoutSucceeded(transactionId: 'txn_offer_1');
    final call =
        methodCalls.firstWhere((c) => c.method == 'markCheckoutSucceeded');
    expect((call.arguments as Map)['transactionId'], 'txn_offer_1');
  });

  test('showAppleSubscriptionManagement invokes channel', () async {
    await manager.showAppleSubscriptionManagement();
    expect(
      methodCalls.any((c) => c.method == 'showAppleSubscriptionManagement'),
      isTrue,
    );
  });

  test('dispose tears down without throwing', () async {
    await manager.dispose();
    // Calling again is a no-op.
    await manager.dispose();
  });

  test('calling method after dispose throws', () async {
    await manager.dispose();
    expect(
      () => manager.present(),
      // ignore: deprecated_member_use_from_same_package
      throwsA(isA<ZSException>()),
    );
  });

  test('preloadCheckout after dispose throws', () async {
    await manager.dispose();
    expect(
      () => manager.preloadCheckout(),
      // ignore: deprecated_member_use_from_same_package
      throwsA(isA<ZSException>()),
    );
  });

  group('OfferManager method-level deprecations + startCheckout docstring', () {
    final source = File('lib/managers/offer_manager.dart').readAsStringSync();

    test('present() is annotated @Deprecated', () {
      final presentIdx = source.indexOf('Future<void> present(');
      expect(presentIdx, isPositive, reason: 'present() declaration not found');
      final lines = source.substring(0, presentIdx).split('\n');
      final precedingNonBlank = lines.reversed
          .skipWhile((l) => l.trim().isEmpty)
          .firstWhere((l) => true, orElse: () => '');
      expect(precedingNonBlank.contains('@Deprecated('), isTrue,
          reason: '@Deprecated must immediately precede present()');
    });

    test('markCheckoutSucceeded is annotated @Deprecated', () {
      final markIdx = source.indexOf('Future<void> markCheckoutSucceeded(');
      expect(markIdx, isPositive, reason: 'markCheckoutSucceeded() declaration not found');
      final lines = source.substring(0, markIdx).split('\n');
      final precedingNonBlank = lines.reversed
          .skipWhile((l) => l.trim().isEmpty)
          .firstWhere((l) => true, orElse: () => '');
      expect(precedingNonBlank.contains('@Deprecated('), isTrue,
          reason: '@Deprecated must immediately precede markCheckoutSucceeded()');
    });

    test('startCheckout is NOT annotated @Deprecated', () {
      final startIdx = source.indexOf('Future<Uri?> startCheckout(');
      expect(startIdx, isPositive, reason: 'startCheckout() declaration not found');
      final lines = source.substring(0, startIdx).split('\n');
      final precedingNonBlank = lines.reversed
          .skipWhile((l) => l.trim().isEmpty)
          .firstWhere((l) => true, orElse: () => '');
      expect(precedingNonBlank.contains('@Deprecated('), isFalse,
          reason: 'startCheckout must remain undeprecated — escape hatch.');
    });

    test('startCheckout docstring describes it as an escape hatch / advanced', () {
      final startIdx = source.indexOf('Future<Uri?> startCheckout(');
      final preceding = source.substring(
        startIdx > 1500 ? startIdx - 1500 : 0,
        startIdx,
      );
      final lower = preceding.toLowerCase();
      expect(lower.contains('escape hatch') || lower.contains('advanced'),
          isTrue,
          reason: 'startCheckout docstring must mark it as advanced/escape hatch.');
    });
  });
}
