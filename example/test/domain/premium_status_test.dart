import 'package:flutter_test/flutter_test.dart';
import 'package:zerosettle/zerosettle.dart';
import 'package:zerosettle_example/domain/premium_status.dart';

Entitlement _ent({required bool isActive}) =>
    Entitlement.fromMap({
      'id': 'e', 'productId': 'p', 'source': 'web_checkout',
      'isActive': isActive, 'purchasedAt': '2026-05-19T00:00:00Z',
      'willRenew': true, 'isTrial': false,
    });

void main() {
  test('no entitlements → not premium', () {
    expect(isPremium(const []), false);
  });
  test('an active entitlement → premium', () {
    expect(isPremium([_ent(isActive: true)]), true);
  });
  test('only inactive entitlements → not premium', () {
    expect(isPremium([_ent(isActive: false)]), false);
  });
}
