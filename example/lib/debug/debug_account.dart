import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// A persisted synthetic test account, scoped to a single environment.
///
/// Used by the debug settings screen to maintain a roster of test users that
/// survive across app launches and environment switches. Each account has a
/// stable [id] that is passed to `Identity.user(id: ...)` when activated.
class DebugAccount {
  /// Synthetic user id (UUID-like) — used as the ZeroSettle user id.
  final String id;

  /// Human-readable label shown in the debug UI.
  final String label;

  final DateTime createdAt;

  /// The environment this account belongs to. Matches the `IAPEnvironment.name`
  /// of the env it was created in (e.g. `"sandbox"`, `"internalLive"`).
  /// Accounts created in env A are not visible when env B is selected.
  final String envKey;

  const DebugAccount({
    required this.id,
    required this.label,
    required this.createdAt,
    required this.envKey,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'createdAt': createdAt.toIso8601String(),
        'envKey': envKey,
      };

  factory DebugAccount.fromJson(Map<String, dynamic> json) {
    return DebugAccount(
      id: json['id'] as String,
      label: json['label'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      envKey: (json['envKey'] as String?) ?? 'sandbox',
    );
  }

  /// Generate a new UUID-like ID without taking a `uuid` dependency.
  /// The example app intentionally avoids adding pub deps for the debug view.
  static String generateId() {
    final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final rand = Random.secure();
    final suffix = List<int>.generate(6, (_) => rand.nextInt(0xff))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'dbg-$ts-$suffix';
  }
}

/// SharedPreferences-backed CRUD for [DebugAccount]s.
///
/// Two persisted blobs:
/// - `debug_accounts` — JSON list of all accounts across all envs
/// - `debug_last_active_by_env` — JSON map `{envKey: accountId}` recording
///   which account was last active per env, so env switches can auto-restore.
class DebugAccountStore {
  static const _accountsKey = 'debug_accounts';
  static const _lastActiveKey = 'debug_last_active_by_env';

  // -- All accounts --

  /// Load every persisted account. Returns an empty list on first run / decode
  /// failure (we never want a corrupt blob to crash debug tooling).
  static Future<List<DebugAccount>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_accountsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => DebugAccount.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Load only accounts that belong to [envKey].
  static Future<List<DebugAccount>> accountsFor(String envKey) async {
    final all = await loadAll();
    return all.where((a) => a.envKey == envKey).toList();
  }

  static Future<void> _saveAll(List<DebugAccount> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(accounts.map((a) => a.toJson()).toList());
    await prefs.setString(_accountsKey, encoded);
  }

  /// Append a new account to the persisted roster.
  static Future<void> add(DebugAccount account) async {
    final all = await loadAll();
    all.add(account);
    await _saveAll(all);
  }

  /// Remove an account by id. Also clears any last-active mapping that
  /// pointed at it so we don't try to auto-restore a dangling pointer.
  static Future<void> remove(String id) async {
    final all = await loadAll();
    final filtered = all.where((a) => a.id != id).toList();
    await _saveAll(filtered);

    final map = await _loadLastActiveMap();
    final cleaned = <String, String>{
      for (final entry in map.entries)
        if (entry.value != id) entry.key: entry.value,
    };
    await _saveLastActiveMap(cleaned);
  }

  // -- Last-active per env --

  static Future<Map<String, String>> _loadLastActiveMap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastActiveKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v as String));
    } catch (_) {
      return {};
    }
  }

  static Future<void> _saveLastActiveMap(Map<String, String> map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastActiveKey, jsonEncode(map));
  }

  /// Returns the last-active account id for [envKey], or `null` if none was
  /// recorded.
  static Future<String?> lastActiveAccountId(String envKey) async {
    final map = await _loadLastActiveMap();
    return map[envKey];
  }

  /// Record [accountId] as the last-active account for [envKey]. Persists
  /// across launches and env switches.
  static Future<void> setLastActive({
    required String accountId,
    required String envKey,
  }) async {
    final map = await _loadLastActiveMap();
    map[envKey] = accountId;
    await _saveLastActiveMap(map);
  }

  /// Clear the last-active mapping for [envKey] (used when the active user
  /// signs out without picking a successor).
  static Future<void> clearLastActive(String envKey) async {
    final map = await _loadLastActiveMap();
    map.remove(envKey);
    await _saveLastActiveMap(map);
  }
}
