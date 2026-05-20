import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerosettle_example/app/inherited_just_one.dart';
import 'package:zerosettle_example/data/database.dart';
import 'package:zerosettle_example/data/user_prefs.dart';
import 'package:zerosettle_example/notifications/notification_service.dart';
import 'package:zerosettle_example/screens/settings/reminder_card.dart';

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

  Future<JustOneScope> buildScope({required bool reminderEnabled}) async {
    SharedPreferences.setMockInitialValues(
      reminderEnabled ? {'reminderEnabled': true} : {},
    );
    final prefs = await UserPrefs.create();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    return JustOneScope(
      db: db,
      prefs: prefs,
      notifications: NotificationService(),
    );
  }

  tearDown(() async {
    await db.close();
  });

  testWidgets('switch is ON when reminderEnabled pref is true', (tester) async {
    final scope = await buildScope(reminderEnabled: true);

    await tester.pumpWidget(_wrap(const ReminderCard(), scope));
    await tester.pump();

    final switchWidget = tester.widget<Switch>(find.byType(Switch));
    expect(switchWidget.value, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('switch is OFF when reminderEnabled pref is false/absent',
      (tester) async {
    final scope = await buildScope(reminderEnabled: false);

    await tester.pumpWidget(_wrap(const ReminderCard(), scope));
    await tester.pump();

    final switchWidget = tester.widget<Switch>(find.byType(Switch));
    expect(switchWidget.value, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('tapping the switch flips it and persists the pref',
      (tester) async {
    final scope = await buildScope(reminderEnabled: false);

    await tester.pumpWidget(_wrap(const ReminderCard(), scope));
    await tester.pump();

    // Sanity: starts OFF.
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(scope.prefs.reminderEnabled, isFalse);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();

    // Switch flipped ON in the UI.
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    // Pref persisted to the new value.
    expect(scope.prefs.reminderEnabled, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
