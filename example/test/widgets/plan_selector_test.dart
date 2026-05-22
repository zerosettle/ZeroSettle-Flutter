import 'package:flutter_test/flutter_test.dart';
import 'package:zerosettle/zerosettle.dart';
import 'package:zerosettle_example/widgets/plan_selector.dart';

Product _sub(String id, {String? interval, String name = 'Plan'}) => Product(
      id: id,
      displayName: name,
      productDescription: '',
      type: ZSProductType.autoRenewableSubscription,
      billingInterval: interval,
    );

void main() {
  group('subscriptionPlans', () {
    test('keeps only subscriptions, sorted weekly → monthly → yearly', () {
      final products = <Product>[
        _sub('y', interval: 'year'),
        const Product(
          id: 'c',
          displayName: 'Streak Saver',
          productDescription: '',
          type: ZSProductType.consumable,
        ),
        _sub('w', interval: 'week'),
        _sub('m', interval: 'month'),
      ];
      expect(
        subscriptionPlans(products).map((p) => p.id).toList(),
        ['w', 'm', 'y'],
      );
    });

    test('unknown intervals sort last', () {
      final plans = subscriptionPlans([
        _sub('u'),
        _sub('m', interval: 'month'),
      ]);
      expect(plans.map((p) => p.id).toList(), ['m', 'u']);
    });
  });

  group('planLabel', () {
    test('maps billingInterval to a friendly label (case-insensitive)', () {
      expect(planLabel(_sub('a', interval: 'week')), 'Weekly');
      expect(planLabel(_sub('a', interval: 'MONTH')), 'Monthly');
      expect(planLabel(_sub('a', interval: 'year')), 'Yearly');
    });

    test('falls back to displayName when interval is absent', () {
      expect(planLabel(_sub('a', name: 'Premium Plus')), 'Premium Plus');
    });
  });

  group('defaultPlanId', () {
    test('prefers the monthly plan', () {
      expect(
        defaultPlanId([
          _sub('w', interval: 'week'),
          _sub('m', interval: 'month'),
          _sub('y', interval: 'year'),
        ]),
        'm',
      );
    });

    test('falls back to the first plan when there is no monthly', () {
      expect(
        defaultPlanId([_sub('w', interval: 'week'), _sub('y', interval: 'year')]),
        'w',
      );
    });

    test('returns null for an empty list', () {
      expect(defaultPlanId(const []), isNull);
    });
  });
}
