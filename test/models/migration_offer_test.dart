import 'package:flutter_test/flutter_test.dart';
import 'package:zerosettle/zerosettle.dart';

void main() {
  group('MigrationOfferState', () {
    test('rawValue round-trip', () {
      for (final s in MigrationOfferState.values) {
        expect(MigrationOfferState.fromRawValue(s.rawValue), s);
      }
    });

    test('unknown rawValue falls back to loading', () {
      expect(
        MigrationOfferState.fromRawValue('garbage'),
        MigrationOfferState.loading,
      );
    });
  });

  group('MigrationOfferData', () {
    test('fromMap/toMap round-trip with all fields', () {
      final map = <String, dynamic>{
        'prompt': <String, dynamic>{
          'productId': 'pro_monthly',
          'discountPercent': 30,
          'title': 'Switch and Save',
          'message': 'Save 30% by switching to direct billing',
          'ctaText': 'Save 30% Forever',
        },
        'freeTrialDays': 14,
        'activeStoreKitProductId': 'pro_monthly_sk',
        'storekitSubscriptionEnd': '2026-06-01T00:00:00.000Z',
        'activeStoreKitOriginalTransactionId': '2000001234567890',
      };
      final data = MigrationOfferData.fromMap(map);
      expect(data.freeTrialDays, 14);
      expect(data.activeStoreKitProductId, 'pro_monthly_sk');
      expect(
        data.storekitSubscriptionEnd,
        DateTime.parse('2026-06-01T00:00:00.000Z'),
      );
      expect(data.activeStoreKitOriginalTransactionId, '2000001234567890');
      // Round-trip
      final out = data.toMap();
      expect(out['freeTrialDays'], 14);
      expect(out['activeStoreKitProductId'], 'pro_monthly_sk');
    });

    test('fromMap with null storekitSubscriptionEnd', () {
      final map = <String, dynamic>{
        'prompt': <String, dynamic>{
          'productId': 'pro_monthly',
          'discountPercent': 30,
          'title': 't',
          'message': 'm',
          'ctaText': 'c',
        },
        'freeTrialDays': 0,
        'activeStoreKitProductId': 'p',
      };
      final data = MigrationOfferData.fromMap(map);
      expect(data.storekitSubscriptionEnd, isNull);
      expect(data.activeStoreKitOriginalTransactionId, isNull);
    });
  });

  group('MigrationManagerState', () {
    test('fromMap with eligible state + offerData', () {
      final map = <String, dynamic>{
        'state': 'eligible',
        'offerData': <String, dynamic>{
          'prompt': <String, dynamic>{
            'productId': 'pro_monthly',
            'discountPercent': 30,
            'title': 't',
            'message': 'm',
            'ctaText': 'c',
          },
          'freeTrialDays': 7,
          'activeStoreKitProductId': 'pro_monthly_sk',
        },
        'checkoutErrorMessage': null,
        'isLoading': false,
        'storekitCancelRequired': false,
      };
      final s = MigrationManagerState.fromMap(map);
      expect(s.state, MigrationOfferState.eligible);
      expect(s.offerData, isNotNull);
      expect(s.offerData!.freeTrialDays, 7);
      expect(s.isLoading, isFalse);
    });

    test('fromMap with loading state and no offerData', () {
      final map = <String, dynamic>{
        'state': 'loading',
        'isLoading': true,
        'storekitCancelRequired': false,
      };
      final s = MigrationManagerState.fromMap(map);
      expect(s.state, MigrationOfferState.loading);
      expect(s.offerData, isNull);
      expect(s.isLoading, isTrue);
    });
  });
}
