import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerosettle/zerosettle.dart';

void main() {
  testWidgets('renders SizedBox.shrink on unsupported platforms', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await tester.pumpWidget(MaterialApp(
      home: ZeroSettlePendingActionBanner(
        action: const PendingActionManualPlayCancel(
          transactionId: 't', userMessage: 'm',
          originalPlayPurchaseToken: 'tok', deepLink: 'https://x'),
      ),
    ));
    expect(find.byType(SizedBox), findsWidgets);
    debugDefaultTargetPlatformOverride = null;
  });
}
