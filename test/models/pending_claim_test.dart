import 'package:flutter_test/flutter_test.dart';
import 'package:zerosettle/zerosettle.dart';

void main() {
  group('PendingClaim', () {
    test('fromMap/toMap round-trip with purchaseToken', () {
      final map = <String, dynamic>{
        'productId': 'pro_weekly',
        'originalTransactionId': '2000000000000000',
        'existingOwnerHint': 'a3f1c0de',
        'purchaseToken': 'GPA.1234-5678-9012-34567',
      };

      final claim = PendingClaim.fromMap(map);
      expect(claim.productId, 'pro_weekly');
      expect(claim.originalTransactionId, '2000000000000000');
      expect(claim.existingOwnerHint, 'a3f1c0de');
      expect(claim.purchaseToken, 'GPA.1234-5678-9012-34567');

      expect(claim.toMap(), map);
    });

    test('purchaseToken is null when absent from the map (StoreKit conflict)',
        () {
      final claim = PendingClaim.fromMap(<String, dynamic>{
        'productId': 'pro_weekly',
        'originalTransactionId': '2000000000000000',
        'existingOwnerHint': 'a3f1c0de',
      });

      expect(claim.purchaseToken, isNull);
      // toMap omits the key entirely when null — keeps the wire shape lean
      // and matches the StoreKit case where no Play token exists.
      expect(claim.toMap().containsKey('purchaseToken'), isFalse);
    });

    test('== / hashCode incorporate purchaseToken', () {
      const base = PendingClaim(
        productId: 'pro_weekly',
        originalTransactionId: '2000000000000000',
        existingOwnerHint: 'a3f1c0de',
        purchaseToken: 'GPA.token-a',
      );
      const sameToken = PendingClaim(
        productId: 'pro_weekly',
        originalTransactionId: '2000000000000000',
        existingOwnerHint: 'a3f1c0de',
        purchaseToken: 'GPA.token-a',
      );
      const differentToken = PendingClaim(
        productId: 'pro_weekly',
        originalTransactionId: '2000000000000000',
        existingOwnerHint: 'a3f1c0de',
        purchaseToken: 'GPA.token-b',
      );

      expect(base, sameToken);
      expect(base.hashCode, sameToken.hashCode);
      expect(base, isNot(differentToken));
    });
  });
}
