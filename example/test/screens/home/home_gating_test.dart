import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerosettle/zerosettle_method_channel.dart';
import 'package:zerosettle/zerosettle_platform_interface.dart';
import 'package:zerosettle_example/app/inherited_just_one.dart';
import 'package:zerosettle_example/app/routes.dart';
import 'package:zerosettle_example/data/database.dart';
import 'package:zerosettle_example/data/user_prefs.dart';
import 'package:zerosettle_example/notifications/notification_service.dart';
import 'package:zerosettle_example/screens/home/home_screen.dart';

// ---------------------------------------------------------------------------
// Minimal platform stub — extends MethodChannelZeroSettle (which satisfies
// PlatformInterface.verifyToken) and overrides only getEntitlements() so the
// FAB handler resolves immediately with an empty list (not premium).
// ---------------------------------------------------------------------------

class _EmptyEntitlementPlatform extends MethodChannelZeroSettle {
  @override
  Future<List<Map<String, dynamic>>> getEntitlements() async => const [];

  @override
  Future<List<Map<String, dynamic>>> getProducts() async => const [];
}

Widget _wrap(Widget child, JustOneScope scope) {
  final router = GoRouter(initialLocation: '/', routes: [
    GoRoute(path: '/', builder: (_, _) => child),
    GoRoute(
        path: Routes.addHabit,
        builder: (_, _) => const Scaffold(body: Text('add'))),
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
  late ZeroSettlePlatform _savedPlatform;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await UserPrefs.create();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    scope =
        JustOneScope(db: db, prefs: prefs, notifications: NotificationService());

    // Replace the platform with a stub so getEntitlements() resolves
    // immediately with an empty list (not premium).
    _savedPlatform = ZeroSettlePlatform.instance;
    ZeroSettlePlatform.instance = _EmptyEntitlementPlatform();
  });

  tearDown(() async {
    ZeroSettlePlatform.instance = _savedPlatform;
    await db.close();
  });

  testWidgets('FAB shows upsell sheet when at 3-habit cap and not premium',
      (tester) async {
    // Seed 3 habits — at the cap.
    for (var i = 0; i < 3; i++) {
      await db.habitDao.insertHabit(HabitsCompanion.insert(
          name: 'Habit $i', emoji: '⭐', colorValue: 0xFF6CA358));
    }

    await tester.pumpWidget(_wrap(const HomeScreen(), scope));
    await tester.pumpAndSettle();

    // Tap the FAB.
    await tester.tap(find.byType(FloatingActionButton));
    // Advance past the sheet slide-in animation (300 ms default). Cannot use
    // pumpAndSettle here because the sheet's CircularProgressIndicator
    // (waiting on getProducts()) keeps animating indefinitely.
    await tester.pump(); // flush microtasks + start animation
    await tester.pump(const Duration(milliseconds: 400)); // complete slide-in

    // The sheet header 'Go Premium' is rendered outside the FutureBuilder, so
    // it appears as soon as the sheet entry animation completes.
    expect(find.text('Go Premium'), findsOneWidget);

    // Unmount and drain.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('FAB navigates to add-habit when below cap', (tester) async {
    // Seed only 2 habits — below the 3-habit cap.
    for (var i = 0; i < 2; i++) {
      await db.habitDao.insertHabit(HabitsCompanion.insert(
          name: 'Habit $i', emoji: '⭐', colorValue: 0xFF6CA358));
    }

    await tester.pumpWidget(_wrap(const HomeScreen(), scope));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Should have navigated to the /add-habit stub.
    expect(find.text('add'), findsOneWidget);

    // Unmount and drain.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
