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
import 'package:zerosettle_example/screens/shop/consumable_shop_screen.dart';

// ---------------------------------------------------------------------------
// Platform stubs — extend MethodChannelZeroSettle (which satisfies
// PlatformInterface.verifyToken) and override getProducts() so the screen
// reaches its loaded state synchronously in tests.
// ---------------------------------------------------------------------------

class _EmptyProductsPlatform extends MethodChannelZeroSettle {
  @override
  Future<List<Map<String, dynamic>>> getProducts() async => const [];

  @override
  Future<List<Map<String, dynamic>>> getEntitlements() async => const [];
}

class _OneConsumablePlatform extends MethodChannelZeroSettle {
  @override
  Future<List<Map<String, dynamic>>> getProducts() async => [
        const Product(
          id: 'com.app.streaksaver5',
          displayName: 'Streak Saver 5-Pack',
          productDescription: 'Five streak savers',
          type: ZSProductType.consumable,
        ).toMap(),
      ];

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
  });

  tearDown(() async {
    ZeroSettlePlatform.instance = _savedPlatform;
    await db.close();
  });

  testWidgets('shows owned count and empty-state copy when no consumables', (tester) async {
    ZeroSettlePlatform.instance = _EmptyProductsPlatform();

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

  testWidgets('renders product card when a consumable is available', (tester) async {
    ZeroSettlePlatform.instance = _OneConsumablePlatform();

    await tester.pumpWidget(_wrap(const ConsumableShopScreen(), scope));
    // Allow initState future (getProducts) to complete.
    await tester.pump();
    await tester.pump();

    // Owned count header still renders.
    expect(find.text('You own 4 streak saver(s)'), findsOneWidget);

    // Product card path — CheckoutSheetHeader shows the product name.
    expect(find.text('Streak Saver 5-Pack'), findsOneWidget);

    // Empty-state copy must NOT show when a consumable is present.
    expect(find.text('No streak savers available right now.'), findsNothing);

    // Unmount and drain pending timers / stream subscriptions.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  group('streakSaverGrant', () {
    Product makeProduct(String id) => Product(
          id: id,
          displayName: 'Streak Saver',
          productDescription: 'A streak saver',
          type: ZSProductType.consumable,
        );

    test('parses trailing integer from product id', () {
      expect(streakSaverGrant(makeProduct('com.app.streaksaver5')), 5);
    });

    test('falls back to 1 when id has no trailing digits', () {
      expect(streakSaverGrant(makeProduct('com.app.streaksaver')), 1);
    });
  });
}
