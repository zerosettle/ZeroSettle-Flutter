import 'package:shared_preferences/shared_preferences.dart';

/// Typed wrapper over [SharedPreferences] for the JustOne sample's
/// app-local state. Mirrors the JustOne Android `UserPrefs` DataStore.
class UserPrefs {
  static const _kDisplayName = 'displayName';
  static const _kUserId = 'userId';
  static const _kStreakSaverCount = 'streakSaverCount';
  static const _kPaywallDismissedAtMs = 'paywallDismissedAtMs';
  static const _kReminderEnabled = 'reminderEnabled';
  static const _kEclOverride = 'eclOverride';
  static const _kSwitchAndSaveTestMode = 'switchAndSaveTestMode';

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

  bool get reminderEnabled => _store.getBool(_kReminderEnabled) ?? false;
  Future<void> setReminderEnabled(bool value) =>
      _store.setBool(_kReminderEnabled, value);

  /// "Force ECL available" testing override for the Switch & Save offer tip.
  /// Persisted so it survives launches; re-applied to the SDK in `main()` on
  /// startup, before any offer tip evaluates.
  bool get eclOverride => _store.getBool(_kEclOverride) ?? false;
  Future<void> setEclOverride(bool value) =>
      _store.setBool(_kEclOverride, value);

  /// "Switch & Save full test mode" override — runs the entire Switch & Save
  /// flow on a non-ECL device. Persisted; re-applied to the SDK in `main()`
  /// on startup.
  bool get switchAndSaveTestMode =>
      _store.getBool(_kSwitchAndSaveTestMode) ?? false;
  Future<void> setSwitchAndSaveTestMode(bool value) =>
      _store.setBool(_kSwitchAndSaveTestMode, value);

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
    await _store.remove(_kReminderEnabled);
    await _store.remove(_kEclOverride);
    await _store.remove(_kSwitchAndSaveTestMode);
  }
}
