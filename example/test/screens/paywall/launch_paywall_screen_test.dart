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
import 'package:zerosettle_example/screens/paywall/launch_paywall_screen.dart';

Widget _wrap(Widget child, JustOneScope scope) {
  final router = GoRouter(initialLocation: Routes.launchPaywall, routes: [
    GoRoute(
      path: Routes.launchPaywall,
      builder: (_, _) => child,
    ),
    GoRoute(
      path: Routes.home,
      builder: (_, _) => const Scaffold(body: Text('home')),
    ),
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

  testWidgets('renders without crashing and shows continue button', (tester) async {
    await tester.pumpWidget(_wrap(const LaunchPaywallScreen(), scope));
    await tester.pump(); // allow initState future to start

    // The "Continue with free version" escape hatch is always visible.
    expect(
      find.widgetWithText(TextButton, 'Continue with free version'),
      findsOneWidget,
    );

    // Unmount to drain any pending timers / stream subscriptions.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
