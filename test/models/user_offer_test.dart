import 'package:flutter_test/flutter_test.dart';
import 'package:zerosettle/zerosettle.dart';

void main() {
  test('decodes a full UserOfferResponse', () {
    final r = UserOfferResponse.fromMap({
      'userId': 'u1', 'appId': 'a1', 'isSandbox': true, 'serverTime': '2026-05-19T00:00:00Z',
      'subscription': {'type': 'activeWeb', 'productId': 'p.month'},
      'offer': {
        'actionType': 'migrateStorekitToWeb', 'isEligible': true,
        'checkoutProductId': 'p.month', 'savingsPercent': 20,
        'freeTrialDays': 7, 'minSubscriptionDays': 0, 'rolloutPercent': 100,
      },
    });
    expect(r.userId, 'u1');
    expect(r.isEligible, true);
    expect(r.offer.actionType, UserOfferActionType.migrateStorekitToWeb);
    expect(r.subscription.productId, 'p.month');
  });

  test('isEligible is false when offer.isEligible is false', () {
    final r = UserOfferResponse.fromMap({
      'userId': 'u', 'appId': 'a', 'isSandbox': false, 'serverTime': 't',
      'subscription': {'type': 'none'},
      'offer': {'actionType': 'noAction', 'isEligible': false, 'savingsPercent': 0,
                'freeTrialDays': 0, 'minSubscriptionDays': 0, 'rolloutPercent': 0},
    });
    expect(r.isEligible, false);
  });

  test('decodes optional nested objects: display, proration, appleSubscription', () {
    final r = UserOfferResponse.fromMap({
      'userId': 'u2', 'appId': 'a2', 'isSandbox': false, 'serverTime': 't2',
      'subscription': {'type': 'activeStoreKit', 'productId': 'p.year'},
      'offer': {
        'actionType': 'upgradeStorekitToWeb', 'isEligible': true,
        'savingsPercent': 30, 'freeTrialDays': 0,
        'minSubscriptionDays': 0, 'rolloutPercent': 50,
        'requiresAppleCancel': true,
        'source': 'storeKit',
        'display': {
          'title': 'Upgrade Now', 'body': 'Save more', 'ctaText': 'Go',
          'dismissText': 'No thanks', 'acceptedTitle': 'Done',
          'acceptedBody': 'Enjoy!', 'completedTitle': 'Complete',
          'completedBody': 'All set', 'appleCancelInstructions': 'Cancel in Settings',
        },
        'proration': {'amountCents': 499, 'currency': 'usd', 'nextBillingDate': '2026-06-01'},
        'appleSubscription': {
          'isActive': true, 'expiresAt': '2026-06-01T00:00:00Z',
          'statusCode': 1, 'autoRenewEnabled': true,
        },
      },
    });
    expect(r.offer.actionType, UserOfferActionType.upgradeStorekitToWeb);
    expect(r.offer.requiresAppleCancel, true);
    expect(r.offer.source, UserOfferSourceStorefront.storeKit);
    expect(r.offer.display?.title, 'Upgrade Now');
    expect(r.offer.proration?.amountCents, 499);
    expect(r.offer.proration?.currency, 'usd');
    expect(r.offer.proration?.nextBillingDate, '2026-06-01');
    expect(r.offer.appleSubscription?.isActive, true);
    expect(r.offer.appleSubscription?.statusCode, 1);
  });

  test('enum fromWire falls back to noAction on unknown value', () {
    final actionType = UserOfferActionType.fromWire('unknownFutureAction');
    expect(actionType, UserOfferActionType.noAction);

    final storefront = UserOfferSourceStorefront.fromWire('unknownStorefront');
    expect(storefront, null);
  });
}
