import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerosettle_example/app/inherited_just_one.dart';
import 'package:zerosettle_example/data/database.dart';
import 'package:zerosettle_example/data/user_prefs.dart';
import 'package:zerosettle_example/notifications/notification_service.dart';
import 'package:zerosettle_example/screens/developer/dev_debug_screen.dart';

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

  testWidgets('DevDebugScreen renders AppBar titled "Debug"', (tester) async {
    await tester.pumpWidget(_wrap(const DevDebugScreen(), scope));
    await tester.pump();

    expect(find.text('Debug'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('DevDebugScreen renders action buttons', (tester) async {
    await tester.pumpWidget(_wrap(const DevDebugScreen(), scope));
    await tester.pump();

    expect(find.text('Fetch transaction history'), findsOneWidget);
    expect(find.text('Restore entitlements'), findsOneWidget);
    expect(find.text('Fetch products'), findsOneWidget);
    expect(find.text('Get SDK version'), findsOneWidget);
    expect(find.text('UCB enabled?'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('DevDebugScreen renders "SDK events" section header', (tester) async {
    await tester.pumpWidget(_wrap(const DevDebugScreen(), scope));
    await tester.pump();

    expect(find.text('SDK events'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
