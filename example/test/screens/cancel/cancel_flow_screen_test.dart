import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerosettle_example/app/inherited_just_one.dart';
import 'package:zerosettle_example/data/database.dart';
import 'package:zerosettle_example/data/user_prefs.dart';
import 'package:zerosettle_example/notifications/notification_service.dart';
import 'package:zerosettle_example/screens/cancel/cancel_flow_screen.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Wraps [child] in InheritedJustOne + a minimal GoRouter so that
/// [context.go] / [context.pop] work without crashing.
Widget _wrap(Widget child, JustOneScope scope) {
  final router = GoRouter(
    initialLocation: '/cancel/com.app.pro',
    routes: [
      GoRoute(
        path: '/cancel/:productId',
        builder: (_, state) =>
            CancelFlowScreen(productId: state.pathParameters['productId']!),
      ),
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('home')),
      ),
    ],
  );
  return InheritedJustOne(
    scope: scope,
    child: MaterialApp.router(routerConfig: router),
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

  testWidgets(
    'shows loading indicator while fetchCancelFlowConfig is in-flight',
    (tester) async {
      // fetchCancelFlowConfig() is unregistered in the test environment —
      // the underlying MethodChannel call never completes. The FutureBuilder
      // therefore stays in its loading branch indefinitely.
      await tester.pumpWidget(_wrap(
        const CancelFlowScreen(productId: 'com.app.pro'),
        scope,
      ));
      // Single pump — enough for the first build cycle.
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Unmount and drain the router.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    '"Keep my subscription" escape control is reachable from the AppBar',
    (tester) async {
      await tester.pumpWidget(_wrap(
        const CancelFlowScreen(productId: 'com.app.pro'),
        scope,
      ));
      await tester.pump();

      // The close icon in the AppBar is the escape control (navigates back /
      // dismisses the screen). It should be present even while loading.
      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
