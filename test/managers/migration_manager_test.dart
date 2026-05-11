import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerosettle/zerosettle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MigrationManager manager;
  const handleId = 'test_handle_42';
  final methodChannel =
      MethodChannel('zerosettle/migration_manager_$handleId');

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
          return 'https://checkout.zerosettle.io/cs_test_abc';
        default:
          return null;
      }
    });
    manager = MigrationManager.fromHandleId(handleId);
  });

  tearDown(() async {
    await manager.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  test('getState parses state map', () async {
    final s = await manager.getState();
    expect(s.state, MigrationOfferState.eligible);
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
  });

  test('startCheckout forwards stripeCustomerId arg', () async {
    await manager.startCheckout(stripeCustomerId: 'cus_test_xyz');
    final call = methodCalls.firstWhere((c) => c.method == 'startCheckout');
    expect((call.arguments as Map)['stripeCustomerId'], 'cus_test_xyz');
  });

  test('markCheckoutSucceeded forwards transactionId', () async {
    await manager.markCheckoutSucceeded(transactionId: 'txn_42');
    final call =
        methodCalls.firstWhere((c) => c.method == 'markCheckoutSucceeded');
    expect((call.arguments as Map)['transactionId'], 'txn_42');
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

  group('MigrationManager class-level deprecation', () {
    test('class is annotated with @Deprecated', () {
      final source = File('lib/managers/migration_manager.dart').readAsStringSync();
      // Find the class declaration
      final classIdx = source.indexOf('class MigrationManager');
      expect(classIdx, isPositive, reason: 'class MigrationManager declaration not found');

      // Verify @Deprecated appears immediately before the class
      final lastDeprecatedIdx = source.lastIndexOf('@Deprecated(', classIdx);
      expect(lastDeprecatedIdx, isPositive,
          reason: '@Deprecated must appear before class MigrationManager');

      // Verify the deprecation message points adopters at OfferManager
      final annotationBlock = source.substring(lastDeprecatedIdx, classIdx);
      expect(annotationBlock.toLowerCase(), contains('offermanager'),
          reason: 'deprecation message should mention OfferManager');
    });
  });
}
