import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerosettle_example/data/user_prefs.dart';

void main() {
  late UserPrefs prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await UserPrefs.create();
  });

  test('displayName round-trips', () async {
    expect(prefs.displayName, isNull);
    await prefs.setDisplayName('Alice');
    expect(prefs.displayName, 'Alice');
  });

  test('userId round-trips', () async {
    expect(prefs.userId, isNull);
    await prefs.setUserId('u_123');
    expect(prefs.userId, 'u_123');
  });

  test('streakSaverCount defaults to 0 and increments', () async {
    expect(prefs.streakSaverCount, 0);
    await prefs.setStreakSaverCount(prefs.streakSaverCount + 1);
    await prefs.setStreakSaverCount(prefs.streakSaverCount + 1);
    expect(prefs.streakSaverCount, 2);
  });

  test('paywallDismissedAt round-trips', () async {
    expect(prefs.paywallDismissedAt, isNull);
    final ts = DateTime(2026, 5, 19, 12);
    await prefs.setPaywallDismissedAt(ts);
    expect(prefs.paywallDismissedAt, ts);
  });

  test('clearAll wipes everything', () async {
    await prefs.setDisplayName('Alice');
    await prefs.setUserId('u');
    await prefs.setStreakSaverCount(5);
    await prefs.setPaywallDismissedAt(DateTime.now());
    await prefs.clearAll();
    expect(prefs.displayName, isNull);
    expect(prefs.userId, isNull);
    expect(prefs.streakSaverCount, 0);
    expect(prefs.paywallDismissedAt, isNull);
  });
}
