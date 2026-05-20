import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerosettle_example/app/inherited_just_one.dart';
import 'package:zerosettle_example/data/database.dart';
import 'package:zerosettle_example/data/user_prefs.dart';
import 'package:zerosettle_example/notifications/notification_service.dart';
import 'package:zerosettle_example/screens/developer/developer_screen.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Wraps [child] in [InheritedJustOne] + a plain [MaterialApp] (no router
/// needed — DeveloperScreen uses Navigator.push, not go_router).
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

  testWidgets('DeveloperScreen shows AppBar with "Developer" title',
      (tester) async {
    await tester.pumpWidget(_wrap(const DeveloperScreen(), scope));
    await tester.pump();

    expect(find.text('Developer'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('DeveloperScreen renders all 7 sub-screen entry tiles',
      (tester) async {
    await tester.pumpWidget(_wrap(const DeveloperScreen(), scope));
    await tester.pump();

    expect(find.text('Environment'), findsOneWidget);
    expect(find.text('Entitlements'), findsOneWidget);
    expect(find.text('Offers'), findsOneWidget);
    expect(find.text('Pending actions'), findsOneWidget);
    expect(find.text('Cancel flow'), findsOneWidget);
    expect(find.text('Upgrade offer'), findsOneWidget);
    expect(find.text('Debug'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('DeveloperScreen has 7 ListTiles', (tester) async {
    await tester.pumpWidget(_wrap(const DeveloperScreen(), scope));
    await tester.pump();

    expect(find.byType(ListTile), findsNWidgets(7));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
