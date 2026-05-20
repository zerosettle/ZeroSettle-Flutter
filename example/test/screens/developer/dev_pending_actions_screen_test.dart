import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerosettle_example/app/inherited_just_one.dart';
import 'package:zerosettle_example/data/database.dart';
import 'package:zerosettle_example/data/user_prefs.dart';
import 'package:zerosettle_example/notifications/notification_service.dart';
import 'package:zerosettle_example/screens/developer/dev_pending_actions_screen.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Wraps [child] in [InheritedJustOne] + a plain [MaterialApp] (no router
/// needed — developer sub-screens use Navigator.push, not go_router).
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

  testWidgets('DevPendingActionsScreen renders AppBar titled "Pending actions"',
      (tester) async {
    // DevPendingActionsScreen embeds ZeroSettlePendingActionBanner, which
    // renders a bare AndroidView on Android — under a widget test that
    // AndroidView has no intrinsic height and crashes layout inside the
    // Column. Override the platform to iOS so the banner collapses to
    // SizedBox.shrink (mirrors the SDK's own zs_pending_action_banner_test).
    // The override is reset before the test body returns so the framework's
    // end-of-body debug-var invariant check passes.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    await tester.pumpWidget(_wrap(const DevPendingActionsScreen(), scope));
    await tester.pump();

    expect(find.text('Pending actions'), findsOneWidget);

    // Unmount drain — clears any pending StreamBuilder timers.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
      'DevPendingActionsScreen shows empty-state when stream emits nothing',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    // Under test the pendingActionsUpdates EventChannel emits nothing;
    // getPendingActions() never completes → _seed stays null.
    // The StreamBuilder renders snap.data ?? _seed ?? [] which is [].
    await tester.pumpWidget(_wrap(const DevPendingActionsScreen(), scope));
    await tester.pump();

    expect(find.text('No pending actions'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    debugDefaultTargetPlatformOverride = null;
  });
}
