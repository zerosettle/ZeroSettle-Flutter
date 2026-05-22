import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerosettle_example/app/inherited_just_one.dart';
import 'package:zerosettle_example/data/database.dart';
import 'package:zerosettle_example/data/identity_store.dart';
import 'package:zerosettle_example/data/user_prefs.dart';
import 'package:zerosettle_example/notifications/notification_service.dart';
import 'package:zerosettle_example/screens/settings/streak_saver_card.dart';

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
  late IdentityStore identityStore;
  late JustOneScope scope;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'streakSaverCount': 7});
    prefs = await UserPrefs.create();
    identityStore = await IdentityStore.create();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    scope = JustOneScope(db: db, prefs: prefs, identityStore: identityStore, notifications: NotificationService());
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('renders streak saver count and Buy more button', (tester) async {
    await tester.pumpWidget(_wrap(const StreakSaverCard(), scope));
    await tester.pump();

    // Count must render somewhere in the card.
    expect(find.text('7'), findsOneWidget);

    // "Buy more" button must be present.
    expect(find.text('Buy more'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('renders Streak Savers title', (tester) async {
    await tester.pumpWidget(_wrap(const StreakSaverCard(), scope));
    await tester.pump();

    expect(find.text('Streak Savers'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
