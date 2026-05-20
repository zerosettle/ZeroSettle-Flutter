import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerosettle_example/app/inherited_just_one.dart';
import 'package:zerosettle_example/data/database.dart';
import 'package:zerosettle_example/data/user_prefs.dart';
import 'package:zerosettle_example/notifications/notification_service.dart';
import 'package:zerosettle_example/screens/developer/dev_offers_screen.dart';
import 'package:zerosettle_example/screens/developer/dev_cancel_debug_screen.dart';
import 'package:zerosettle_example/screens/developer/dev_upgrade_offer_screen.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Wraps [child] in [InheritedJustOne] + a plain [MaterialApp] (no router
/// needed — developer sub-screens use Navigator.push, not go_router).
Widget _wrap(Widget child, JustOneScope scope) {
  return InheritedJustOne(
    scope: scope,
    child: MaterialApp(home: child),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late AppDatabase db;
  late UserPrefs prefs;
  late JustOneScope scope;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await UserPrefs.create();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    scope = JustOneScope(db: db, prefs: prefs, notifications: NotificationService());
  });

  tearDown(() async {
    await db.close();
  });

  // -- DevOffersScreen --

  testWidgets('DevOffersScreen renders AppBar titled "Offers"', (tester) async {
    // DevOffersScreen embeds ZeroSettleOfferTip which renders AndroidView on
    // Android. Override platform to iOS so it collapses to SizedBox.shrink.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    await tester.pumpWidget(_wrap(const DevOffersScreen(), scope));
    await tester.pump();

    expect(find.text('Offers'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('DevOffersScreen renders a "Fetch user offer" action button',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    await tester.pumpWidget(_wrap(const DevOffersScreen(), scope));
    await tester.pump();

    expect(find.text('Fetch user offer'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    debugDefaultTargetPlatformOverride = null;
  });

  // -- DevCancelDebugScreen --

  testWidgets('DevCancelDebugScreen renders AppBar titled "Cancel flow (debug)"',
      (tester) async {
    await tester.pumpWidget(_wrap(const DevCancelDebugScreen(), scope));
    await tester.pump();

    expect(find.text('Cancel flow (debug)'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('DevCancelDebugScreen renders a "Fetch config" action button',
      (tester) async {
    await tester.pumpWidget(_wrap(const DevCancelDebugScreen(), scope));
    await tester.pump();

    expect(find.text('Fetch config'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  // -- DevUpgradeOfferScreen --

  testWidgets(
      'DevUpgradeOfferScreen renders AppBar titled "Upgrade offer"',
      (tester) async {
    await tester.pumpWidget(_wrap(const DevUpgradeOfferScreen(), scope));
    await tester.pump();

    expect(find.text('Upgrade offer'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('DevUpgradeOfferScreen renders a "Fetch config" action button',
      (tester) async {
    await tester.pumpWidget(_wrap(const DevUpgradeOfferScreen(), scope));
    await tester.pump();

    expect(find.text('Fetch config'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
