import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerosettle_example/app/inherited_just_one.dart';
import 'package:zerosettle_example/data/database.dart';
import 'package:zerosettle_example/data/identity_store.dart';
import 'package:zerosettle_example/data/user_prefs.dart';
import 'package:zerosettle_example/app_environment.dart';
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
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late UserPrefs prefs;
  late IdentityStore identityStore;
  late JustOneScope scope;

  /// Builds a scope. Pass [seed] to pre-populate SharedPreferences before the
  /// stores are created (e.g. an existing identity-store JSON blob).
  Future<void> buildScope({Map<String, Object> seed = const {}}) async {
    SharedPreferences.setMockInitialValues({
      'com.zerosettle.flutter_example.environment': 'local',
      ...seed,
    });
    prefs = await UserPrefs.create();
    identityStore = await IdentityStore.create();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    scope = JustOneScope(
      db: db,
      prefs: prefs,
      identityStore: identityStore,
      notifications: NotificationService(),
    );
  }

  setUp(() async {
    await buildScope();
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('renders AppBar titled "Environment"', (tester) async {
    await tester.pumpWidget(_wrap(const EnvSwitcherScreen(), scope));
    await tester.pumpAndSettle();

    expect(find.text('Environment'), findsOneWidget);
  });

  testWidgets('renders the environment picker', (tester) async {
    await tester.pumpWidget(_wrap(const EnvSwitcherScreen(), scope));
    await tester.pumpAndSettle();

    for (final env in AppEnvironment.values) {
      expect(find.text(env.displayName), findsOneWidget);
    }
  });

  testWidgets('renders the add-identity form', (tester) async {
    await tester.pumpWidget(_wrap(const EnvSwitcherScreen(), scope));
    await tester.pumpAndSettle();

    // Two text fields: user id + display name.
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('User ID'), findsOneWidget);
    expect(find.text('Display name (optional)'), findsOneWidget);

    // Add + logout controls.
    expect(find.widgetWithText(FilledButton, 'Add & Identify'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Logout (keep saved identities)'),
      findsOneWidget,
    );
  });

  testWidgets('shows empty-state copy when the env has no saved identities',
      (tester) async {
    await tester.pumpWidget(_wrap(const EnvSwitcherScreen(), scope));
    await tester.pumpAndSettle();

    expect(find.textContaining('No saved identities'), findsOneWidget);
  });

  testWidgets('lists the current env saved identities', (tester) async {
    await identityStore.upsertIdentity(
      'local',
      const SavedIdentity(userId: 'u_alice', displayName: 'Alice'),
    );
    await identityStore.setActive('local', 'u_alice');

    await tester.pumpWidget(_wrap(const EnvSwitcherScreen(), scope));
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('u_alice'), findsOneWidget);
    // Active user_id is surfaced plainly.
    expect(find.textContaining('Current user_id: u_alice'), findsOneWidget);
  });

  testWidgets('adding an identity persists it to the store', (tester) async {
    // Stub the method channel so identify() resolves in-test.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('zerosettle'),
      (call) async => null,
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('zerosettle'), null));

    await tester.pumpWidget(_wrap(const EnvSwitcherScreen(), scope));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'User ID'), 'u_new');
    await tester.enterText(
        find.widgetWithText(TextField, 'Display name (optional)'), 'New User');
    await tester.tap(find.widgetWithText(FilledButton, 'Add & Identify'));
    await tester.pumpAndSettle();

    expect(identityStore.identitiesFor('local'),
        [const SavedIdentity(userId: 'u_new', displayName: 'New User')]);
    expect(identityStore.activeIdentityFor('local')?.userId, 'u_new');
  });
}
