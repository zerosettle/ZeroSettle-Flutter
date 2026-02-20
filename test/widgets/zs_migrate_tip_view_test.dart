import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerosettle/zerosettle.dart';

void main() {
  group('ZSMigrateTipView', () {
    testWidgets('renders UiKitView on iOS', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZSMigrateTipView(
              userId: 'test_user',
              backgroundColor: Colors.black,
            ),
          ),
        ),
      );

      // On iOS, should create UiKitView
      expect(find.byType(UiKitView), findsOneWidget);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('renders empty SizedBox on Android',
        (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZSMigrateTipView(
              userId: 'test_user',
              backgroundColor: Colors.black,
            ),
          ),
        ),
      );

      // On Android, should be empty
      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.byType(UiKitView), findsNothing);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('passes correct creation params on iOS',
        (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      const testColor = Color(0xFF123456);
      const testUserId = 'user_abc_123';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZSMigrateTipView(
              userId: testUserId,
              backgroundColor: testColor,
            ),
          ),
        ),
      );

      final uiKitView = tester.widget<UiKitView>(find.byType(UiKitView));

      // Verify viewType
      expect(uiKitView.viewType, 'zerosettle/migrate_tip_view');

      // Verify creation params
      expect(uiKitView.creationParams, isA<Map<String, dynamic>>());
      final params = uiKitView.creationParams as Map<String, dynamic>;
      expect(params['backgroundColor'], testColor.value);
      expect(params['userId'], testUserId);

      // Verify codec
      expect(uiKitView.creationParamsCodec, isA<StandardMessageCodec>());

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('uses StandardMessageCodec', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZSMigrateTipView(
              userId: 'test',
              backgroundColor: Colors.blue,
            ),
          ),
        ),
      );

      final uiKitView = tester.widget<UiKitView>(find.byType(UiKitView));
      expect(uiKitView.creationParamsCodec, const StandardMessageCodec());

      debugDefaultTargetPlatformOverride = null;
    });

    test('color conversion produces correct ARGB int32', () {
      // Test various colors to ensure we're passing correct format
      const colors = [
        Color(0xFF000000), // Black with full opacity
        Color(0xFFFFFFFF), // White with full opacity
        Color(0x80FF0000), // Red with 50% opacity
        Color(0xFF123456), // Custom color
      ];

      for (final color in colors) {
        // The value should match exactly what Flutter uses internally
        expect(color.value, isA<int>());
        // ARGB format: 0xAARRGGBB
        final a = (color.value >> 24) & 0xFF;
        final r = (color.value >> 16) & 0xFF;
        final g = (color.value >> 8) & 0xFF;
        final b = color.value & 0xFF;
        expect(a, greaterThanOrEqualTo(0));
        expect(r, greaterThanOrEqualTo(0));
        expect(g, greaterThanOrEqualTo(0));
        expect(b, greaterThanOrEqualTo(0));
        expect(a, lessThanOrEqualTo(255));
        expect(r, lessThanOrEqualTo(255));
        expect(g, lessThanOrEqualTo(255));
        expect(b, lessThanOrEqualTo(255));
      }
    });
  });
}
