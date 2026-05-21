import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerosettle/zerosettle.dart';
import 'package:zerosettle_example/widgets/dual_price_buttons.dart';

Product _product({bool withWebPrice = true}) => Product.fromMap({
      'id': 'com.app.pro',
      'displayName': 'Premium',
      'productDescription': 'd',
      'type': 'auto_renewable_subscription',
      if (withWebPrice) 'webPrice': {'amountCents': 499, 'currencyCode': 'USD'},
    });

Widget _host(Product product) => MaterialApp(
      home: Scaffold(
        body: DualPriceButtons(product: product, onPurchased: () {}),
      ),
    );

void main() {
  testWidgets('Android → a single "Buy" button (UCB routes the choice)',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(_host(_product()));

    expect(find.widgetWithText(FilledButton, 'Buy'), findsOneWidget);
    // No web-vs-store picker on Android.
    expect(find.widgetWithText(FilledButton, 'Pay on web'), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('iOS with a web price → "Pay on web" + "App Store" buttons',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.pumpWidget(_host(_product()));

    expect(find.widgetWithText(FilledButton, 'Pay on web'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'App Store'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Buy'), findsNothing);

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('iOS without a web price → only the "App Store" button',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.pumpWidget(_host(_product(withWebPrice: false)));

    expect(find.widgetWithText(OutlinedButton, 'App Store'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Pay on web'), findsNothing);

    debugDefaultTargetPlatformOverride = null;
  });
}
