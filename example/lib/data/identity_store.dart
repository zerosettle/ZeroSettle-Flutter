import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'user_prefs.dart';

/// A reusable, labeled test user the example app can identify as.
///
/// Persisted (per environment) by [IdentityStore] so logging out or
/// re-onboarding never strands a prior user and their purchases.
class SavedIdentity {
  /// The stable ZeroSettle user id (the value passed to `Identity.user`).
  final String userId;

  /// A human-readable label shown in the identity picker.
  final String displayName;

  const SavedIdentity({required this.userId, required this.displayName});

  factory SavedIdentity.fromMap(Map<String, dynamic> map) => SavedIdentity(
        userId: map['userId'] as String,
        displayName: map['displayName'] as String,
      );

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'displayName': displayName,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedIdentity &&
          other.userId == userId &&
          other.displayName == displayName;

  @override
  int get hashCode => Object.hash(userId, displayName);

  @override
  String toString() => 'SavedIdentity(userId: $userId, displayName: $displayName)';
}

/// Per-environment list of saved identities + the active user id.
///
/// Internal value type for one environment's slice of the [IdentityStore].
class _EnvIdentities {
  final List<SavedIdentity> identities;
  final String? activeUserId;

  const _EnvIdentities({this.identities = const [], this.activeUserId});

  factory _EnvIdentities.fromMap(Map<String, dynamic> map) => _EnvIdentities(
        identities: (map['identities'] as List<dynamic>? ?? const [])
            .map((e) => SavedIdentity.fromMap(
                  Map<String, dynamic>.from(e as Map),
                ))
            .toList(),
        activeUserId: map['activeUserId'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'identities': identities.map((e) => e.toMap()).toList(),
        if (activeUserId != null) 'activeUserId': activeUserId,
      };

  _EnvIdentities copyWith({
    List<SavedIdentity>? identities,
    String? activeUserId,
    bool clearActive = false,
  }) =>
      _EnvIdentities(
        identities: identities ?? this.identities,
        activeUserId: clearActive ? null : (activeUserId ?? this.activeUserId),
      );
}

/// Persists a set of reusable test identities, partitioned by backend
/// environment, in [SharedPreferences].
///
/// The example app can run against `local` / `staging` / `prod` backends,
/// each of which is a distinct user namespace. [IdentityStore] keeps a
/// separate identity list (and active selection) for each, keyed by the
/// `AppEnvironment.name` string, so switching environments swaps the visible
/// set of users without losing any.
///
/// Everything is stored under a single JSON string key ([_storeKey]) so the
/// whole store reads/writes atomically.
class IdentityStore {
  static const _storeKey = 'identityStoreV1';

  final SharedPreferences _store;

  /// envId → that environment's identities + active selection.
  final Map<String, _EnvIdentities> _envs;

  IdentityStore._(this._store, this._envs);

  /// Asynchronous factory — call once at app start and inject the result.
  ///
  /// Migration: if the store has never been written AND a legacy [UserPrefs]
  /// carries a `userId`, that user is seeded as an identity under
  /// [legacyEnvId] and marked active — so an existing install's user (and
  /// their purchases) survive the upgrade to the per-environment store.
  ///
  /// [legacyPrefs] / [legacyEnvId] are injected (rather than read internally)
  /// so the migration path is testable.
  static Future<IdentityStore> create({
    UserPrefs? legacyPrefs,
    String? legacyEnvId,
  }) async {
    final store = await SharedPreferences.getInstance();
    final raw = store.getString(_storeKey);

    if (raw != null) {
      return IdentityStore._(store, _decode(raw));
    }

    // Fresh store — attempt the one-time legacy migration.
    final envs = <String, _EnvIdentities>{};
    final legacyId = legacyPrefs?.userId;
    if (legacyId != null && legacyId.isNotEmpty && legacyEnvId != null) {
      envs[legacyEnvId] = _EnvIdentities(
        identities: [
          SavedIdentity(
            userId: legacyId,
            displayName: legacyPrefs?.displayName ?? legacyId,
          ),
        ],
        activeUserId: legacyId,
      );
    }
    final migrated = IdentityStore._(store, envs);
    if (envs.isNotEmpty) await migrated._persist();
    return migrated;
  }

  static Map<String, _EnvIdentities> _decode(String raw) {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
      (envId, value) => MapEntry(
        envId,
        _EnvIdentities.fromMap(Map<String, dynamic>.from(value as Map)),
      ),
    );
  }

  Future<void> _persist() async {
    final encoded = jsonEncode(
      _envs.map((envId, env) => MapEntry(envId, env.toMap())),
    );
    await _store.setString(_storeKey, encoded);
  }

  /// The saved identities for [envId] (empty if none).
  List<SavedIdentity> identitiesFor(String envId) =>
      List.unmodifiable(_envs[envId]?.identities ?? const []);

  /// The active identity for [envId], or `null` if none is selected.
  SavedIdentity? activeIdentityFor(String envId) {
    final env = _envs[envId];
    final activeId = env?.activeUserId;
    if (env == null || activeId == null) return null;
    for (final identity in env.identities) {
      if (identity.userId == activeId) return identity;
    }
    return null;
  }

  /// Marks [userId] active for [envId]. No-op if [userId] is not a saved
  /// identity in that environment.
  Future<void> setActive(String envId, String userId) async {
    final env = _envs[envId] ?? const _EnvIdentities();
    if (!env.identities.any((i) => i.userId == userId)) return;
    _envs[envId] = env.copyWith(activeUserId: userId);
    await _persist();
  }

  /// Clears the active selection for [envId] without removing any identities.
  ///
  /// Used by the sign-out flow: the user is sent back to onboarding, but the
  /// identity remains in the picker so it can be re-selected later.
  Future<void> clearActive(String envId) async {
    final env = _envs[envId];
    if (env == null || env.activeUserId == null) return;
    _envs[envId] = env.copyWith(clearActive: true);
    await _persist();
  }

  /// Adds [identity] to [envId], or updates the existing one with the same
  /// `userId` (its display name is replaced).
  Future<void> upsertIdentity(String envId, SavedIdentity identity) async {
    final env = _envs[envId] ?? const _EnvIdentities();
    final updated = List<SavedIdentity>.from(env.identities);
    final index = updated.indexWhere((i) => i.userId == identity.userId);
    if (index >= 0) {
      updated[index] = identity;
    } else {
      updated.add(identity);
    }
    _envs[envId] = env.copyWith(identities: updated);
    await _persist();
  }

  /// Removes the identity with [userId] from [envId]. If it was the active
  /// identity, the active selection is also cleared.
  Future<void> removeIdentity(String envId, String userId) async {
    final env = _envs[envId];
    if (env == null) return;
    final updated =
        env.identities.where((i) => i.userId != userId).toList();
    final clearActive = env.activeUserId == userId;
    _envs[envId] = env.copyWith(
      identities: updated,
      clearActive: clearActive,
    );
    await _persist();
  }
}
