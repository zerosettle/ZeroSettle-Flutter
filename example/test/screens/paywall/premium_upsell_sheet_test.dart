import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerosettle_example/app/inherited_just_one.dart';
import 'package:zerosettle_example/data/database.dart';
import 'package:zerosettle_example/data/identity_store.dart';
import 'package:zerosettle_example/data/user_prefs.dart';
import 'package:zerosettle_example/notifications/notification_service.dart';
import 'package:zerosettle_example/screens/paywall/premium_upsell_sheet.dart';

Widget _wrap(JustOneScope scope) {
  return InheritedJustOne(
    scope: scope,
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showPremiumUpsell(context),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  late AppDatabase db;
  late UserPrefs prefs;
  late IdentityStore identityStore;
  late JustOneScope scope;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await UserPrefs.create();
    identityStore = await IdentityStore.create();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    scope = JustOneScope(
      db: db,
      prefs: prefs,
      identityStore: identityStore,
      notifications: NotificationService(),
    );
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('sheet renders Go Premium header and Maybe later button',
      (tester) async {
    await tester.pumpWidget(_wrap(scope));

    // Tap the button to open the bottom sheet.
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump(); // schedule the modal route
    await tester.pump(const Duration(milliseconds: 400)); // let sheet slide in

    // Static content that is always visible regardless of product-load state.
    expect(find.text('Go Premium'), findsOneWidget);
    expect(
      find.widgetWithText(TextButton, 'Maybe later'),
      findsOneWidget,
    );

    // Unmount to drain pending futures / stream subscriptions.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
