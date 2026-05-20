import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerosettle/zerosettle.dart';
import 'package:zerosettle/zerosettle_method_channel.dart';
import 'package:zerosettle/zerosettle_platform_interface.dart';
import 'package:zerosettle_example/app/inherited_just_one.dart';
import 'package:zerosettle_example/data/database.dart';
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

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap(Widget child, JustOneScope scope) {
  return InheritedJustOne(
    scope: scope,
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late AppDatabase db;
  late UserPrefs prefs;
  late JustOneScope scope;
  late ZeroSettlePlatform savedPlatform;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await UserPrefs.create();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    scope = JustOneScope(db: db, prefs: prefs, notifications: NotificationService());
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
}
