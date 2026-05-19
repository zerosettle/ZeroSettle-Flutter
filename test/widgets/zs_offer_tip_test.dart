import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerosettle/zerosettle.dart';

void main() {
  testWidgets('renders SizedBox.shrink on unsupported platforms', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await tester.pumpWidget(const MaterialApp(
      home: ZeroSettleOfferTip(),
    ));
    expect(find.byType(SizedBox), findsWidgets);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('accepts optional stripeCustomerId', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await tester.pumpWidget(const MaterialApp(
      home: ZeroSettleOfferTip(stripeCustomerId: 'cus_test'),
    ));
    expect(find.byType(SizedBox), findsWidgets);
    debugDefaultTargetPlatformOverride = null;
  });
}
