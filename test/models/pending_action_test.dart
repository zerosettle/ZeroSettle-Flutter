import 'package:flutter_test/flutter_test.dart';
import 'package:zerosettle/zerosettle.dart';

void main() {
  test('decodes migrationCompletedInfo', () {
    final a = PendingAction.fromMap({
      'type': 'migrationCompletedInfo',
      'transactionId': 'txn_1',
      'userMessage': 'You migrated.',
      'playAccessEndsAt': '2026-06-01T00:00:00Z',
      'newSubscriptionPriceCents': 499,
      'newSubscriptionCurrency': 'USD',
      'newSubscriptionInterval': 'month',
    });
    expect(a, isA<PendingActionMigrationCompletedInfo>());
    expect(a.transactionId, 'txn_1');
    expect((a as PendingActionMigrationCompletedInfo).newSubscriptionPriceCents, 499);
  });

  test('decodes manualPlayCancel', () {
    final a = PendingAction.fromMap({
      'type': 'manualPlayCancel',
      'transactionId': 'txn_2',
      'userMessage': 'Cancel on Google Play.',
      'originalPlayPurchaseToken': 'tok_abc',
      'deepLink': 'https://play.google.com/store/account/subscriptions',
    });
    expect(a, isA<PendingActionManualPlayCancel>());
    expect((a as PendingActionManualPlayCancel).deepLink, contains('play.google.com'));
  });

  test('throws on unknown type', () {
    expect(() => PendingAction.fromMap({'type': 'nope'}), throwsArgumentError);
  });
}
