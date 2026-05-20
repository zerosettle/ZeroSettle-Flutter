import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerosettle_example/app/inherited_just_one.dart';
import 'package:zerosettle_example/data/database.dart';
import 'package:zerosettle_example/data/user_prefs.dart';
import 'package:zerosettle_example/notifications/notification_service.dart';
import 'package:zerosettle_example/screens/developer/dev_entitlements_screen.dart';

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

  testWidgets('DevEntitlementsScreen renders AppBar titled "Entitlements"',
      (tester) async {
    await tester.pumpWidget(_wrap(const DevEntitlementsScreen(), scope));
    await tester.pump();

    expect(find.text('Entitlements'), findsOneWidget);

    // Unmount drain — clears any pending StreamBuilder timers.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
      'DevEntitlementsScreen shows empty-state when stream emits nothing',
      (tester) async {
    // Under test the entitlementUpdates EventChannel emits nothing;
    // getEntitlements() never completes → _seed stays null.
    // The StreamBuilder renders snap.data ?? _seed ?? [] which is [].
    await tester.pumpWidget(_wrap(const DevEntitlementsScreen(), scope));
    await tester.pump();

    expect(find.text('No entitlements'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('DevEntitlementsScreen has a Restore action button',
      (tester) async {
    await tester.pumpWidget(_wrap(const DevEntitlementsScreen(), scope));
    await tester.pump();

    expect(find.text('Restore'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
