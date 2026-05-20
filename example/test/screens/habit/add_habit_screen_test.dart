import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerosettle_example/app/inherited_just_one.dart';
import 'package:zerosettle_example/data/database.dart';
import 'package:zerosettle_example/data/user_prefs.dart';
import 'package:zerosettle_example/notifications/notification_service.dart';
import 'package:zerosettle_example/screens/habit/add_habit_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;
  late JustOneScope scope;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await UserPrefs.create();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    scope = JustOneScope(db: db, prefs: prefs, notifications: NotificationService());
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('Save button disabled until a name is entered', (tester) async {
    await tester.pumpWidget(InheritedJustOne(
      scope: scope,
      child: const MaterialApp(home: AddHabitScreen()),
    ));
    final save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save'));
    expect(save.onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'Read');
    await tester.pump();
    final save2 = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save'));
    expect(save2.onPressed, isNotNull);
  });
}
