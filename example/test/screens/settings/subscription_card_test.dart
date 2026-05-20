import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerosettle_example/app/inherited_just_one.dart';
import 'package:zerosettle_example/data/database.dart';
import 'package:zerosettle_example/data/user_prefs.dart';
import 'package:zerosettle_example/notifications/notification_service.dart';
import 'package:zerosettle_example/screens/settings/subscription_card.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap(Widget child, JustOneScope scope) {
  return InheritedJustOne(
    scope: scope,
    child: MaterialApp(home: Scaffold(body: child)),
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

  testWidgets('shows Upgrade to Premium when no active entitlements', (tester) async {
    // Under test: entitlementUpdates stream emits nothing (unregistered
    // EventChannel) and getEntitlements() never completes (unregistered
    // MethodChannel). The StreamBuilder stays in its no-data branch, which
    // is the "no active subscription" branch.
    await tester.pumpWidget(_wrap(const SubscriptionCard(), scope));
    await tester.pump();

    expect(find.text('Upgrade to Premium'), findsOneWidget);

    // Unmount and drain the StreamBuilder subscription.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
