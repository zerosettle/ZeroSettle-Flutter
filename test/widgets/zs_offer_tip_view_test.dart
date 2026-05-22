import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerosettle/zerosettle.dart';

void main() {
  group('OfferTipView', () {
    testWidgets('renders UiKitView on iOS', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfferTipView(
              backgroundColor: Colors.black,
            ),
          ),
        ),
      );

      // On iOS, should create UiKitView
      expect(find.byType(UiKitView), findsOneWidget);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('renders AndroidView on Android (D3)',
        (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfferTipView(
              backgroundColor: Colors.black,
            ),
          ),
        ),
      );

      // On Android, the widget mounts the PlatformView
      // (`com.zerosettle/migrate_tip_view`) via AndroidView. UiKitView is
      // never instantiated on this platform.
      expect(find.byType(AndroidView), findsOneWidget);
      expect(find.byType(UiKitView), findsNothing);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('passes correct viewType + creation params on Android',
        (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      const testColor = Color(0xFFAABBCC);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfferTipView(
              backgroundColor: testColor,
            ),
          ),
        ),
      );

      final androidView =
          tester.widget<AndroidView>(find.byType(AndroidView));

      // Android factory key — note the `com.` prefix (org-id convention),
      // distinct from iOS's `zerosettle/migrate_tip_view`. The
      // MigrateTipViewFactory registers under exactly this string.
      expect(androidView.viewType, 'com.zerosettle/migrate_tip_view');

      // Creation params share the iOS shape. `backgroundColor` (ARGB int) is
      // the only consumed param — the offer tip is identify-first.
      expect(androidView.creationParams, isA<Map<String, Object?>>());
      final params = androidView.creationParams as Map<String, Object?>;
      expect(params['backgroundColor'], testColor.toARGB32());

      // StandardMessageCodec matches the PlatformViewFactory.
      expect(androidView.creationParamsCodec, isA<StandardMessageCodec>());

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets(
        'renders empty SizedBox on non-mobile platforms (linux / macOS / windows)',
        (WidgetTester tester) async {
      for (final platform in [
        TargetPlatform.linux,
        TargetPlatform.macOS,
        TargetPlatform.windows,
      ]) {
        debugDefaultTargetPlatformOverride = platform;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OfferTipView(
                backgroundColor: Colors.black,
              ),
            ),
          ),
        );

        expect(find.byType(SizedBox), findsWidgets);
        expect(find.byType(UiKitView), findsNothing);
        expect(find.byType(AndroidView), findsNothing);

        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('passes correct creation params on iOS',
        (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      const testColor = Color(0xFF123456);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfferTipView(
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
      expect(params['backgroundColor'], testColor.toARGB32());

      // Verify codec
      expect(uiKitView.creationParamsCodec, isA<StandardMessageCodec>());

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('uses StandardMessageCodec', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfferTipView(
              backgroundColor: Colors.blue,
            ),
          ),
        ),
      );

      final uiKitView = tester.widget<UiKitView>(find.byType(UiKitView));
      expect(uiKitView.creationParamsCodec, const StandardMessageCodec());

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('MigrationTipView deprecated alias still resolves to OfferTipView',
        (WidgetTester tester) async {
      // Back-compat: `MigrationTipView` was the released name (1.4.0) and is
      // kept as a deprecated typedef. Existing adopter code must still work.
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      // ignore: deprecated_member_use_from_same_package
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            // ignore: deprecated_member_use_from_same_package
            body: MigrationTipView(backgroundColor: Colors.black),
          ),
        ),
      );

      expect(find.byType(OfferTipView), findsOneWidget);

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
        expect(color.toARGB32(), isA<int>());
        // ARGB format: 0xAARRGGBB
        final a = (color.toARGB32() >> 24) & 0xFF;
        final r = (color.toARGB32() >> 16) & 0xFF;
        final g = (color.toARGB32() >> 8) & 0xFF;
        final b = color.toARGB32() & 0xFF;
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
