import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:zerosettle/zerosettle_platform_interface.dart';
import 'package:zerosettle/widgets/offer_impression.dart';

class _MockPlatform extends ZeroSettlePlatform with MockPlatformInterfaceMixin {
  int reportCount = 0;
  @override
  Future<void> reportOfferViewed({String? productId, int? variantId, String? flowType}) async { reportCount++; }
}

void main() {
  late _MockPlatform mock;
  setUp(() {
    mock = _MockPlatform();
    ZeroSettlePlatform.instance = mock;
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });
  testWidgets('fires once when >=50% visible', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      OfferImpression(child: const SizedBox(width: 300, height: 100, child: Text('banner'))))));
    await tester.pumpAndSettle();
    expect(mock.reportCount, 1);
  });
}
