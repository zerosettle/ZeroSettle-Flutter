import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerosettle_example/app/inherited_just_one.dart';
import 'package:zerosettle_example/data/database.dart';
import 'package:zerosettle_example/data/user_prefs.dart';
import 'package:zerosettle_example/iap_environment.dart';
import 'package:zerosettle_example/notifications/notification_service.dart';
import 'package:zerosettle_example/screens/developer/env_switcher_screen.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Wraps [child] in [InheritedJustOne] + a plain [MaterialApp].
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

  testWidgets('EnvSwitcherScreen renders AppBar titled "Environment"',
      (tester) async {
    await tester.pumpWidget(_wrap(const EnvSwitcherScreen(), scope));
    // pumpAndSettle so IAPEnvironment.load() resolves.
    await tester.pumpAndSettle();

    expect(find.text('Environment'), findsOneWidget);
  });

  testWidgets('EnvSwitcherScreen renders the enabled environment list',
      (tester) async {
    await tester.pumpWidget(_wrap(const EnvSwitcherScreen(), scope));
    await tester.pumpAndSettle();

    // Every enabled IAPEnvironment should appear as a tile (by display name).
    final enabled = IAPEnvironment.values.where((e) => e.isEnabled);
    expect(enabled, isNotEmpty);
    for (final env in enabled) {
      expect(find.text(env.displayName), findsOneWidget);
    }
  });

  testWidgets('EnvSwitcherScreen renders the identify form',
      (tester) async {
    await tester.pumpWidget(_wrap(const EnvSwitcherScreen(), scope));
    await tester.pumpAndSettle();

    // Two text fields: user id + name.
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('User ID'), findsOneWidget);
    expect(find.text('Name (optional)'), findsOneWidget);

    // Identify + logout controls.
    expect(find.widgetWithText(FilledButton, 'Identify as User'),
        findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Logout (clear identity)'),
        findsOneWidget);
  });
}
