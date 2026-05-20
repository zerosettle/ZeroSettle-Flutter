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
import 'package:zerosettle_example/screens/settings/subscription_card.dart';

// ---------------------------------------------------------------------------
// Platform stub — extends MethodChannelZeroSettle (which satisfies
// PlatformInterface.verifyToken) and overrides getEntitlements() so the
// card's initState seed resolves with one active subscription entitlement.
// fetchUpgradeOfferConfigForCurrentUser returns `available: false` so the
// "Upgrade available" row stays hidden (the active-branch assertions don't
// depend on it).
// ---------------------------------------------------------------------------

class _OneActiveSubPlatform extends MethodChannelZeroSettle {
  @override
  Future<List<Map<String, dynamic>>> getEntitlements() async => [
        Entitlement(
          id: 'ent_1',
          productId: 'com.justone.pro.monthly',
          source: EntitlementSource.webCheckout,
          isActive: true,
          purchasedAt: DateTime.utc(2026, 1, 1),
          expiresAt: DateTime.utc(2026, 6, 1),
          status: 'active',
        ).toMap(),
      ];

  @override
  Future<Map<String, dynamic>> fetchUpgradeOfferConfigForCurrentUser({
    String? productId,
  }) async =>
      UpgradeOfferConfig(available: false).toMap();
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

  testWidgets('shows Upgrade to Premium when no active entitlements', (tester) async {
    // Under test: entitlementUpdates stream emits nothing (unregistered
    // EventChannel) and getEntitlements() never completes (unregistered
    // MethodChannel). The StreamBuilder stays in its no-data branch, which
    // is the "no active subscription" branch.
    await tester.pumpWidget(_wrap(const SubscriptionCard(), scope));
    await tester.pump();

    expect(find.text('Upgrade to Premium'), findsOneWidget);

    // Unmount and drain the StreamBuilder subscription.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('shows active subscription details when an entitlement is active',
      (tester) async {
    ZeroSettlePlatform.instance = _OneActiveSubPlatform();

    await tester.pumpWidget(_wrap(const SubscriptionCard(), scope));
    // First pump renders the no-data branch; pumpAndSettle lets the
    // getEntitlements() seed future resolve + setState rebuild into the
    // active branch.
    await tester.pumpAndSettle();

    // Active branch: plan name + cancel button render.
    expect(find.text('com.justone.pro.monthly'), findsOneWidget);
    expect(find.text('Cancel subscription'), findsOneWidget);
    // No-sub CTA must be absent.
    expect(find.text('Upgrade to Premium'), findsNothing);

    // Unmount and drain the StreamBuilder subscription.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
