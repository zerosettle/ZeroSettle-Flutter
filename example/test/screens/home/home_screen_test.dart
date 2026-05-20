import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerosettle_example/app/inherited_just_one.dart';
import 'package:zerosettle_example/app/routes.dart';
import 'package:zerosettle_example/data/database.dart';
import 'package:zerosettle_example/data/user_prefs.dart';
import 'package:zerosettle_example/notifications/notification_service.dart';
import 'package:zerosettle_example/screens/home/home_screen.dart';
import 'package:zerosettle_example/screens/home/habit_list_item.dart';

Widget _wrap(Widget child, JustOneScope scope) {
  final router = GoRouter(initialLocation: '/', routes: [
    GoRoute(path: '/', builder: (_, __) => child),
    GoRoute(path: Routes.addHabit, builder: (_, __) =>
        const Scaffold(body: Text('add'))),
  ]);
  return InheritedJustOne(
    scope: scope,
    child: MaterialApp.router(routerConfig: router),
  );
}

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

  testWidgets('renders empty state when no habits', (tester) async {
    await tester.pumpWidget(_wrap(const HomeScreen(), scope));
    await tester.pumpAndSettle();
    expect(find.textContaining('No habits'), findsOneWidget);

    // Unmount so the Drift StreamBuilder cancels its subscription and its
    // teardown timer drains within the test (avoids the post-disposal
    // "Timer still pending" invariant failure).
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('renders one HabitListItem per habit', (tester) async {
    await db.habitDao.insertHabit(HabitsCompanion.insert(
        name: 'Read', emoji: '📖', colorValue: 0xFF6CA358));
    await db.habitDao.insertHabit(HabitsCompanion.insert(
        name: 'Walk', emoji: '🚶', colorValue: 0xFF3B82F6));
    await tester.pumpWidget(_wrap(const HomeScreen(), scope));
    await tester.pumpAndSettle();
    expect(find.byType(HabitListItem), findsNWidgets(2));

    // Unmount so the Drift StreamBuilder cancels its subscription and its
    // teardown timer drains within the test (avoids the post-disposal
    // "Timer still pending" invariant failure).
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
