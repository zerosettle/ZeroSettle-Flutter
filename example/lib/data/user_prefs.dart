import 'package:shared_preferences/shared_preferences.dart';

/// Typed wrapper over [SharedPreferences] for the JustOne sample's
/// app-local state. Mirrors the JustOne Android `UserPrefs` DataStore.
class UserPrefs {
  static const _kDisplayName = 'displayName';
  static const _kUserId = 'userId';
  static const _kStreakSaverCount = 'streakSaverCount';
  static const _kPaywallDismissedAtMs = 'paywallDismissedAtMs';

  final SharedPreferences _store;

  UserPrefs._(this._store);

  /// Asynchronous factory — call once at app start and inject the result.
  static Future<UserPrefs> create() async {
    final store = await SharedPreferences.getInstance();
    return UserPrefs._(store);
  }

  String? get displayName => _store.getString(_kDisplayName);
  Future<void> setDisplayName(String name) =>
      _store.setString(_kDisplayName, name);

  String? get userId => _store.getString(_kUserId);
  Future<void> setUserId(String id) => _store.setString(_kUserId, id);

  int get streakSaverCount => _store.getInt(_kStreakSaverCount) ?? 0;
  Future<void> setStreakSaverCount(int n) =>
      _store.setInt(_kStreakSaverCount, n);

  DateTime? get paywallDismissedAt {
    final ms = _store.getInt(_kPaywallDismissedAtMs);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setPaywallDismissedAt(DateTime t) =>
      _store.setInt(_kPaywallDismissedAtMs, t.millisecondsSinceEpoch);

  Future<void> clearAll() async {
    await _store.remove(_kDisplayName);
    await _store.remove(_kUserId);
    await _store.remove(_kStreakSaverCount);
    await _store.remove(_kPaywallDismissedAtMs);
  }
}
