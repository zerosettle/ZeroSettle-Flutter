import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerosettle/zerosettle_method_channel.dart';
import 'package:zerosettle/zerosettle_platform_interface.dart';
import 'package:zerosettle_example/app/inherited_just_one.dart';
import 'package:zerosettle_example/data/database.dart';
import 'package:zerosettle_example/data/user_prefs.dart';
import 'package:zerosettle_example/notifications/notification_service.dart';
import 'package:zerosettle_example/screens/shop/consumable_shop_screen.dart';

// ---------------------------------------------------------------------------
// Platform stub — extends MethodChannelZeroSettle (which satisfies
// PlatformInterface.verifyToken) and overrides getProducts() to return []
// synchronously so the screen reaches its loaded state in tests.
// ---------------------------------------------------------------------------

class _EmptyProductsPlatform extends MethodChannelZeroSettle {
  @override
  Future<List<Map<String, dynamic>>> getProducts() async => const [];

  @override
  Future<List<Map<String, dynamic>>> getEntitlements() async => const [];
}

Widget _wrap(Widget child, JustOneScope scope) {
  return InheritedJustOne(
    scope: scope,
    child: MaterialApp(home: child),
  );
}

void main() {
  late AppDatabase db;
  late UserPrefs prefs;
  late JustOneScope scope;
  late ZeroSettlePlatform _savedPlatform;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'streakSaverCount': 4});
    prefs = await UserPrefs.create();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    scope = JustOneScope(db: db, prefs: prefs, notifications: NotificationService());

    _savedPlatform = ZeroSettlePlatform.instance;
    ZeroSettlePlatform.instance = _EmptyProductsPlatform();
  });

  tearDown(() async {
    ZeroSettlePlatform.instance = _savedPlatform;
    await db.close();
  });

  testWidgets('shows owned count and empty-state copy when no consumables', (tester) async {
    await tester.pumpWidget(_wrap(const ConsumableShopScreen(), scope));
    // Allow initState future (getProducts) to complete.
    await tester.pump();
    await tester.pump();

    // Owned count header.
    expect(find.text('You own 4 streak saver(s)'), findsOneWidget);

    // Empty-state copy — products list is empty so no consumables found.
    expect(find.text('No streak savers available right now.'), findsOneWidget);

    // Unmount and drain pending timers / stream subscriptions.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
