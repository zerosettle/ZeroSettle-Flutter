import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerosettle/zerosettle.dart';
import 'package:zerosettle/zerosettle_method_channel.dart';
import 'package:zerosettle/zerosettle_platform_interface.dart';
import 'package:zerosettle_example/app/inherited_just_one.dart';
import 'package:zerosettle_example/app/routes.dart';
import 'package:zerosettle_example/data/database.dart';
import 'package:zerosettle_example/data/identity_store.dart';
import 'package:zerosettle_example/data/user_prefs.dart';
import 'package:zerosettle_example/notifications/notification_service.dart';
import 'package:zerosettle_example/screens/settings/account_card.dart';

// ---------------------------------------------------------------------------
// Platform stub — extends MethodChannelZeroSettle (which satisfies
// PlatformInterface.verifyToken) and overrides restoreEntitlementsForCurrentUser
// so the "Restore purchases" handler resolves immediately with an empty list.
// (ZeroSettle.instance.restoreEntitlements() with no userId routes to
// restoreEntitlementsForCurrentUser on the platform.)
// ---------------------------------------------------------------------------

class _EmptyRestorePlatform extends MethodChannelZeroSettle {
  @override
  Future<List<Map<String, dynamic>>> restoreEntitlementsForCurrentUser() async =>
      const [];
}

class _ThrowingRestorePlatform extends MethodChannelZeroSettle {
  @override
  Future<List<Map<String, dynamic>>> restoreEntitlementsForCurrentUser() async =>
      throw const ZSApiException('Network error');
}

class _ThrowingLogoutPlatform extends MethodChannelZeroSettle {
  @override
  Future<void> logout() async => throw const ZSApiException('Logout failed');
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap(Widget child, JustOneScope scope) {
  return InheritedJustOne(
    scope: scope,
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

/// Router-aware wrapper for tests that exercise navigation (`_signOut` calls
/// `context.go(Routes.createUser)`). The `_wrap` helper above has no GoRouter,
/// so `context.go` would assert.
Widget _wrapWithRouter(Widget child, JustOneScope scope) {
  final router = GoRouter(initialLocation: '/', routes: [
    GoRoute(path: '/', builder: (_, _) => Scaffold(body: child)),
    GoRoute(
      path: Routes.createUser,
      builder: (_, _) => const Scaffold(body: Text('create-user')),
    ),
  ]);
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

  testWidgets('renders Restore purchases and Sign out buttons', (tester) async {
    await tester.pumpWidget(_wrap(const AccountCard(), scope));
    // Allow any synchronous microtasks to settle.
    await tester.pump();

    // Static buttons must always render — they don't depend on method-channel
    // calls (getUserId / getSdkVersion), which never complete under test.
    expect(find.text('Restore purchases'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);

    // Unmount and drain.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('shows Account card title', (tester) async {
    await tester.pumpWidget(_wrap(const AccountCard(), scope));
    await tester.pump();

    expect(find.text('Account'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('tapping Restore purchases shows a result SnackBar', (tester) async {
    ZeroSettlePlatform.instance = _EmptyRestorePlatform();

    await tester.pumpWidget(_wrap(const AccountCard(), scope));
    await tester.pump();

    await tester.tap(find.text('Restore purchases'));
    await tester.pumpAndSettle();

    // Empty restore result → "no purchases" copy in the SnackBar.
    expect(find.text('No purchases to restore.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('Restore purchases shows error SnackBar on ZeroSettleException', (tester) async {
    ZeroSettlePlatform.instance = _ThrowingRestorePlatform();

    await tester.pumpWidget(_wrap(const AccountCard(), scope));
    await tester.pump();

    await tester.tap(find.text('Restore purchases'));
    await tester.pumpAndSettle();

    // The ZeroSettleException message must surface in the SnackBar.
    expect(find.text('Network error'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('Sign out still clears prefs when logout() throws', (tester) async {
    ZeroSettlePlatform.instance = _ThrowingLogoutPlatform();

    // Seed a pref so we can prove clearAll() ran despite the logout failure.
    await prefs.setDisplayName('Test User');
    expect(prefs.displayName, 'Test User');

    await tester.pumpWidget(_wrapWithRouter(const AccountCard(), scope));
    await tester.pump();

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    // ...cleanup must still run — a thrown logout() must not trap the user...
    expect(prefs.displayName, isNull);
    // ...and navigation to the create-user route must complete.
    expect(find.text('create-user'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
