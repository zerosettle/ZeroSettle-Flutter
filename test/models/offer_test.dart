import 'package:flutter_test/flutter_test.dart';
import 'package:zerosettle/zerosettle.dart';

Map<String, dynamic> _displayMap({String prefix = ''}) => {
      'offerTitle': '${prefix}offerTitle',
      'offerMessage': '${prefix}offerMessage',
      'offerCta': '${prefix}offerCta',
      'acceptedTitle': '${prefix}acceptedTitle',
      'acceptedMessage': '${prefix}acceptedMessage',
      'acceptedCta': '${prefix}acceptedCta',
      'completedTitle': '${prefix}completedTitle',
      'completedMessage': '${prefix}completedMessage',
    };

void main() {
  group('OfferFlowType', () {
    test('rawValue round-trip', () {
      for (final t in OfferFlowType.values) {
        expect(OfferFlowType.fromRawValue(t.rawValue), t);
      }
    });

    test('rawValue strings match Swift', () {
      expect(OfferFlowType.migration.rawValue, 'migration');
      expect(OfferFlowType.upgrade.rawValue, 'upgrade');
    });

    test('unknown rawValue falls back to migration', () {
      expect(OfferFlowType.fromRawValue('garbage'), OfferFlowType.migration);
    });
  });

  group('OfferUpgradeType', () {
    test('rawValue round-trip', () {
      for (final t in OfferUpgradeType.values) {
        expect(OfferUpgradeType.fromRawValue(t.rawValue), t);
      }
    });

    test('rawValue strings match Swift', () {
      expect(OfferUpgradeType.storekitToWeb.rawValue, 'storekit_to_web');
      expect(OfferUpgradeType.webToWeb.rawValue, 'web_to_web');
    });
  });

  group('OfferCheckoutPresentation', () {
    test('rawValue round-trip for every variant', () {
      for (final p in OfferCheckoutPresentation.values) {
        expect(OfferCheckoutPresentation.fromRawValue(p.rawValue), p);
      }
    });

    test('rawValue strings match Swift', () {
      expect(OfferCheckoutPresentation.inline.rawValue, 'inline');
      expect(OfferCheckoutPresentation.sheet.rawValue, 'sheet');
      expect(OfferCheckoutPresentation.safariVC.rawValue, 'safari_vc');
      expect(OfferCheckoutPresentation.safari.rawValue, 'safari');
    });
  });

  group('OfferState', () {
    test('rawValue round-trip', () {
      for (final s in OfferState.values) {
        expect(OfferState.fromRawValue(s.rawValue), s);
      }
    });

    test('unknown rawValue falls back to loading', () {
      expect(OfferState.fromRawValue('???'), OfferState.loading);
    });
  });

  group('OfferDisplay', () {
    test('fromMap/toMap preserves all 8 fields', () {
      final map = _displayMap(prefix: 'x_');
      final d = OfferDisplay.fromMap(map);
      expect(d.offerTitle, 'x_offerTitle');
      expect(d.offerMessage, 'x_offerMessage');
      expect(d.offerCta, 'x_offerCta');
      expect(d.acceptedTitle, 'x_acceptedTitle');
      expect(d.acceptedMessage, 'x_acceptedMessage');
      expect(d.acceptedCta, 'x_acceptedCta');
      expect(d.completedTitle, 'x_completedTitle');
      expect(d.completedMessage, 'x_completedMessage');
      expect(d.toMap(), map);
    });

    test('fromMap fills missing strings with empty', () {
      final d = OfferDisplay.fromMap(<String, dynamic>{});
      expect(d.offerTitle, '');
      expect(d.completedMessage, '');
    });

    test('equality + hashCode', () {
      final a = OfferDisplay.fromMap(_displayMap(prefix: 'a_'));
      final b = OfferDisplay.fromMap(_displayMap(prefix: 'a_'));
      final c = OfferDisplay.fromMap(_displayMap(prefix: 'b_'));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });
  });

  group('OfferPerProductOffer', () {
    test('fromMap/toMap round-trip', () {
      final map = {
        'productId': 'pro_yearly',
        'savingsPercent': 25,
        'display': _displayMap(prefix: 'pp_'),
      };
      final p = OfferPerProductOffer.fromMap(map);
      expect(p.productId, 'pro_yearly');
      expect(p.savingsPercent, 25);
      expect(p.display.offerCta, 'pp_offerCta');
      expect(p.toMap(), map);
    });
  });

  group('OfferData', () {
    test('fromMap/toMap migration with all fields populated', () {
      final map = {
        'flowType': 'migration',
        'productId': 'pro_monthly',
        'eligibleProductIds': <String>['pro_monthly', 'pro_weekly'],
        'savingsPercent': 30,
        'display': _displayMap(prefix: 'm_'),
        'freeTrialDays': 7,
        'minSubscriptionDays': 14,
        'maxSubscriptionDays': 90,
        'rolloutPercent': 50,
        'variantId': 3,
        'checkoutPresentation': 'sheet',
      };
      final d = OfferData.fromMap(map);
      expect(d.flowType, OfferFlowType.migration);
      expect(d.productId, 'pro_monthly');
      expect(d.eligibleProductIds, ['pro_monthly', 'pro_weekly']);
      expect(d.savingsPercent, 30);
      expect(d.freeTrialDays, 7);
      expect(d.minSubscriptionDays, 14);
      expect(d.maxSubscriptionDays, 90);
      expect(d.rolloutPercent, 50);
      expect(d.upgradeType, isNull);
      expect(d.fromProductId, isNull);
      expect(d.toProductId, isNull);
      expect(d.variantId, 3);
      expect(d.perProductPrompts, isNull);
      expect(d.checkoutPresentation, OfferCheckoutPresentation.sheet);

      // Computed properties
      expect(d.needsAppleCancel, isTrue); // migration → always true
      expect(d.checkoutProductId, 'pro_monthly');

      // toMap round-trip
      final out = d.toMap();
      expect(out['flowType'], 'migration');
      expect(out['savingsPercent'], 30);
      expect(out['checkoutPresentation'], 'sheet');
      expect(out.containsKey('upgradeType'), isFalse);
      expect(out.containsKey('fromProductId'), isFalse);
      expect(out.containsKey('toProductId'), isFalse);
    });

    test('fromMap upgrade web_to_web with from/to product ids', () {
      final map = {
        'flowType': 'upgrade',
        'productId': 'pro_yearly',
        'eligibleProductIds': <String>['pro_monthly'],
        'savingsPercent': 40,
        'display': _displayMap(),
        'freeTrialDays': 0,
        'minSubscriptionDays': 0,
        'upgradeType': 'web_to_web',
        'fromProductId': 'pro_monthly',
        'toProductId': 'pro_yearly',
      };
      final d = OfferData.fromMap(map);
      expect(d.flowType, OfferFlowType.upgrade);
      expect(d.upgradeType, OfferUpgradeType.webToWeb);
      expect(d.fromProductId, 'pro_monthly');
      expect(d.toProductId, 'pro_yearly');
      // upgrade + webToWeb → no Apple cancel needed
      expect(d.needsAppleCancel, isFalse);
      // checkoutProductId prefers toProductId
      expect(d.checkoutProductId, 'pro_yearly');
    });

    test('fromMap upgrade storekit_to_web requires Apple cancel', () {
      final map = {
        'flowType': 'upgrade',
        'productId': 'pro_yearly',
        'eligibleProductIds': <String>['pro_monthly'],
        'savingsPercent': 50,
        'display': _displayMap(),
        'freeTrialDays': 0,
        'minSubscriptionDays': 0,
        'upgradeType': 'storekit_to_web',
        'fromProductId': 'pro_monthly_sk',
        'toProductId': 'pro_yearly',
      };
      final d = OfferData.fromMap(map);
      expect(d.upgradeType, OfferUpgradeType.storekitToWeb);
      expect(d.needsAppleCancel, isTrue);
    });

    test('fromMap with perProductPrompts decodes Map<String, …>', () {
      final map = {
        'flowType': 'migration',
        'productId': 'pro_monthly',
        'eligibleProductIds': <String>['pro_monthly'],
        'savingsPercent': 30,
        'display': _displayMap(),
        'freeTrialDays': 7,
        'minSubscriptionDays': 0,
        'perProductPrompts': {
          'pro_monthly': {
            'productId': 'pro_monthly_alt',
            'savingsPercent': 35,
            'display': _displayMap(prefix: 'ppm_'),
          },
        },
      };
      final d = OfferData.fromMap(map);
      expect(d.perProductPrompts, isNotNull);
      expect(d.perProductPrompts!.length, 1);
      final override = d.perProductPrompts!['pro_monthly']!;
      expect(override.productId, 'pro_monthly_alt');
      expect(override.savingsPercent, 35);
      expect(override.display.offerCta, 'ppm_offerCta');

      // toMap round-trips the map
      final out = d.toMap();
      final perProductOut = out['perProductPrompts'] as Map;
      expect(perProductOut['pro_monthly'], isA<Map>());
      expect(
        (perProductOut['pro_monthly'] as Map)['productId'],
        'pro_monthly_alt',
      );
    });

    test('fromMap tolerates missing optional integer fields', () {
      final map = {
        'flowType': 'migration',
        'productId': 'p',
        'display': _displayMap(),
        // savingsPercent, freeTrialDays, minSubscriptionDays,
        // eligibleProductIds all omitted — Swift uses
        // decodeIfPresent ?? 0 / [].
      };
      final d = OfferData.fromMap(map);
      expect(d.savingsPercent, 0);
      expect(d.freeTrialDays, 0);
      expect(d.minSubscriptionDays, 0);
      expect(d.eligibleProductIds, isEmpty);
      expect(d.maxSubscriptionDays, isNull);
      expect(d.rolloutPercent, isNull);
    });

    test('equality treats two equal data values as equal', () {
      final base = {
        'flowType': 'migration',
        'productId': 'p',
        'eligibleProductIds': <String>['p', 'q'],
        'savingsPercent': 10,
        'display': _displayMap(),
        'freeTrialDays': 0,
        'minSubscriptionDays': 0,
      };
      final a = OfferData.fromMap(Map<String, dynamic>.from(base));
      final b = OfferData.fromMap(Map<String, dynamic>.from(base));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('OfferManagerState', () {
    test('fromMap eligible with offerData', () {
      final map = {
        'state': 'eligible',
        'offerData': {
          'flowType': 'upgrade',
          'productId': 'pro_yearly',
          'eligibleProductIds': <String>['pro_monthly'],
          'savingsPercent': 25,
          'display': _displayMap(),
          'freeTrialDays': 0,
          'minSubscriptionDays': 0,
          'upgradeType': 'web_to_web',
          'fromProductId': 'pro_monthly',
          'toProductId': 'pro_yearly',
        },
        'isLoading': false,
        'storekitCancelRequired': false,
      };
      final s = OfferManagerState.fromMap(map);
      expect(s.state, OfferState.eligible);
      expect(s.offerData, isNotNull);
      expect(s.offerData!.flowType, OfferFlowType.upgrade);
      expect(s.offerData!.checkoutProductId, 'pro_yearly');
      expect(s.isLoading, isFalse);
    });

    test('fromMap loading with no offerData', () {
      final map = {
        'state': 'loading',
        'isLoading': true,
        'storekitCancelRequired': false,
      };
      final s = OfferManagerState.fromMap(map);
      expect(s.state, OfferState.loading);
      expect(s.offerData, isNull);
      expect(s.isLoading, isTrue);
    });

    test('fromMap surfaces checkoutErrorMessage', () {
      final map = {
        'state': 'eligible',
        'isLoading': false,
        'storekitCancelRequired': false,
        'checkoutErrorMessage': 'Network unreachable',
      };
      final s = OfferManagerState.fromMap(map);
      expect(s.checkoutErrorMessage, 'Network unreachable');
    });
  });
}
