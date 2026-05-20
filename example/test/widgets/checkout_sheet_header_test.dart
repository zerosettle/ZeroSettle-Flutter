import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerosettle/zerosettle.dart';
import 'package:zerosettle_example/widgets/checkout_sheet_header.dart';

/// Builds a minimal [Product] for widget tests.
///
/// Key adjustments from the task template:
/// - `type` uses `'auto_renewable_subscription'` — the actual [ZSProductType]
///   raw value; `'auto_renewable'` throws [ArgumentError].
/// - `webPrice` shape matches [Price.fromMap]: `amountCents` + `currencyCode`.
Product _product() => Product.fromMap({
      'id': 'com.app.pro',
      'displayName': 'JustOne Premium',
      'productDescription': 'Unlimited habits',
      'type': 'auto_renewable_subscription',
      'webPrice': {'amountCents': 499, 'currencyCode': 'USD'},
    });

void main() {
  testWidgets('renders name, description, and formatted price', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: CheckoutSheetHeader(product: _product())),
    ));
    expect(find.text('JustOne Premium'), findsOneWidget);
    expect(find.text('Unlimited habits'), findsOneWidget);
    // Price.formatted for 499 USD → '$4.99'
    expect(find.textContaining(r'$4.99'), findsOneWidget);
  });
}
