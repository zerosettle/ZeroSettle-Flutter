import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerosettle/zerosettle_method_channel.dart';
import 'package:zerosettle/zerosettle_platform_interface.dart';
import 'package:zerosettle_example/app/inherited_just_one.dart';
import 'package:zerosettle_example/data/database.dart';
import 'package:zerosettle_example/data/identity_store.dart';
import 'package:zerosettle_example/data/user_prefs.dart';
import 'package:zerosettle_example/notifications/notification_service.dart';
import 'package:zerosettle_example/screens/cancel/cancel_flow_screen.dart';

// ---------------------------------------------------------------------------
// Platform stub — extends MethodChannelZeroSettle (which satisfies
// PlatformInterface.verifyToken) and overrides fetchCancelFlowConfig so it
// throws. ZeroSettle.instance.fetchCancelFlowConfig() wraps the thrown
// PlatformException in a ZeroSettleException, so the screen's FutureBuilder
// lands in its `hasError` branch → the error-fallback Card.
// ---------------------------------------------------------------------------

class _ConfigFailsPlatform extends MethodChannelZeroSettle {
  @override
  Future<Map<String, dynamic>> fetchCancelFlowConfig({String? userId}) async {
    throw PlatformException(
      code: 'config_load_failed',
      message: 'simulated cancel-flow config failure',
    );
  }
}

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
  late IdentityStore identityStore;
  late JustOneScope scope;
  late ZeroSettlePlatform savedPlatform;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await UserPrefs.create();
    identityStore = await IdentityStore.create();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    scope = JustOneScope(db: db, prefs: prefs, identityStore: identityStore, notifications: NotificationService());
    savedPlatform = ZeroSettlePlatform.instance;
  });

  tearDown(() async {
    ZeroSettlePlatform.instance = savedPlatform;
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

  testWidgets(
    'renders error-fallback Card when fetchCancelFlowConfig throws',
    (tester) async {
      ZeroSettlePlatform.instance = _ConfigFailsPlatform();

      await tester.pumpWidget(_wrap(
        const CancelFlowScreen(productId: 'com.app.pro'),
        scope,
      ));
      // pumpAndSettle lets the (rejected) future resolve so the FutureBuilder
      // rebuilds into its hasError branch.
      await tester.pumpAndSettle();

      // Error fallback: the Card copy + the "Cancel anyway" control render.
      expect(find.text("Couldn't load retention options."), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Cancel anyway'), findsOneWidget);
      // Loading indicator must be gone.
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
