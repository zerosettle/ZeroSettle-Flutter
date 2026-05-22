import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerosettle_example/app/inherited_just_one.dart';
import 'package:zerosettle_example/app/routes.dart';
import 'package:zerosettle_example/data/database.dart';
import 'package:zerosettle_example/data/identity_store.dart';
import 'package:zerosettle_example/data/user_prefs.dart';
import 'package:zerosettle_example/notifications/notification_service.dart';
import 'package:zerosettle_example/screens/auth/create_user_screen.dart';

const _envPrefsKey = 'com.zerosettle.flutter_example.environment';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late JustOneScope scope;
  late IdentityStore identityStore;

  /// Builds a scope after [SharedPreferences] mock values have been set.
  Future<void> buildScope() async {
    final prefs = await UserPrefs.create();
    identityStore = await IdentityStore.create();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    scope = JustOneScope(
      db: db,
      prefs: prefs,
      identityStore: identityStore,
      notifications: NotificationService(),
    );
  }

  tearDown(() async {
    await db.close();
  });

  /// Wraps [CreateUserScreen] in a GoRouter (its `_submit` calls `context.go`)
  /// and the [InheritedJustOne] scope.
  Widget wrap() {
    final router = GoRouter(initialLocation: Routes.createUser, routes: [
      GoRoute(
        path: Routes.createUser,
        builder: (_, _) => const CreateUserScreen(),
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

  testWidgets('renders name field, env picker, and a disabled Continue button',
      (tester) async {
    SharedPreferences.setMockInitialValues({_envPrefsKey: 'local'});
    await buildScope();
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    // The three environment segments.
    expect(find.text('Local'), findsOneWidget);
    expect(find.text('Staging'), findsOneWidget);
    expect(find.text('Prod'), findsOneWidget);

    final btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Continue'));
    expect(btn.onPressed, isNull, reason: 'disabled until a name is typed');
  });

  testWidgets('Continue enables after typing a name when the env has a key',
      (tester) async {
    SharedPreferences.setMockInitialValues({_envPrefsKey: 'local'});
    await buildScope();
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Alice');
    await tester.pump();

    final btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Continue'));
    expect(btn.onPressed, isNotNull);
  });

  testWidgets('picking a keyless env disables Continue and shows a hint',
      (tester) async {
    // Picking an env runs applyEnvironment(), which calls platform methods
    // (logout / setBaseUrlOverride). Stub the channel so the switch completes
    // in-test instead of hanging the busy spinner forever.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('zerosettle'),
      (call) async => null,
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('zerosettle'), null));

    SharedPreferences.setMockInitialValues({});
    await buildScope();
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Alice');
    await tester.pump();

    // Pick prod via the segmented control — it has no publishable key on
    // either platform. (load() never *starts* on a keyless env, so this is
    // the only way to reach the no-key state.)
    await tester.tap(find.text('Prod'));
    await tester.pumpAndSettle();

    final btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Continue'));
    expect(btn.onPressed, isNull, reason: 'prod has no publishable key');
    expect(find.textContaining('No publishable key'), findsOneWidget);
  });

  testWidgets('submitting saves the created user as an active identity',
      (tester) async {
    // Stub the method channel so identify() resolves in-test.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('zerosettle'),
      (call) async => null,
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('zerosettle'), null));

    SharedPreferences.setMockInitialValues({_envPrefsKey: 'local'});
    await buildScope();
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Alice');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    // Drain the identify() + store writes + the route change. A bounded
    // pump loop avoids pumpAndSettle hanging on the button's progress spinner.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // The created user landed in the store as the active identity for `local`.
    final active = identityStore.activeIdentityFor('local');
    expect(active, isNotNull);
    expect(active!.displayName, 'Alice');
    expect(active.userId, startsWith('u_'));
    // ...and the app routed to home.
    expect(find.text('home'), findsOneWidget);
  });
}
