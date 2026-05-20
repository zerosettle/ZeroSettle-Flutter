import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerosettle/zerosettle.dart';
import 'package:zerosettle_example/widgets/dual_price_buttons.dart';

Product _product() => Product.fromMap({
      'id': 'com.app.pro', 'displayName': 'Premium',
      'productDescription': 'd', 'type': 'auto_renewable_subscription',
      'webPrice': {'amountCents': 499, 'currencyCode': 'USD'},
    });

void main() {
  testWidgets('UCB enabled → single Buy button', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DualPriceButtons(
          product: _product(),
          ucbEnabled: true,
          onPurchased: () {},
        ),
      ),
    ));
    expect(find.widgetWithText(FilledButton, 'Buy'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Google Play'), findsNothing);
  });

  testWidgets('UCB disabled with webPrice → web button + Google Play button',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DualPriceButtons(
          product: _product(),
          ucbEnabled: false,
          onPurchased: () {},
        ),
      ),
    ));
    expect(find.widgetWithText(FilledButton, 'Pay on web'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Google Play'), findsOneWidget);
  });
}
