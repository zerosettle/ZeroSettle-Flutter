import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerosettle_example/app/inherited_just_one.dart';
import 'package:zerosettle_example/data/database.dart';
import 'package:zerosettle_example/data/user_prefs.dart';
import 'package:zerosettle_example/notifications/notification_service.dart';
import 'package:zerosettle_example/screens/habit/habit_detail_screen.dart';

void main() {
  late AppDatabase db;
  late JustOneScope scope;
  late int habitId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await UserPrefs.create();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    scope = JustOneScope(db: db, prefs: prefs, notifications: NotificationService());
    habitId = await db.habitDao.insertHabit(HabitsCompanion.insert(
        name: 'Read', emoji: '📖', colorValue: 0xFF6CA358));
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('renders habit name and emoji', (tester) async {
    await tester.pumpWidget(InheritedJustOne(
      scope: scope,
      child: MaterialApp(home: HabitDetailScreen(habitId: habitId)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('📖'), findsAtLeastNWidgets(1));
    expect(find.text('Read'), findsAtLeastNWidgets(1));

    // Unmount so the Drift StreamBuilder cancels its subscription and its
    // teardown timer drains within the test (avoids the post-disposal
    // "Timer still pending" invariant failure).
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
