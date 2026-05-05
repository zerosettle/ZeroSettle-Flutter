import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerosettle/zerosettle.dart';

/// Persists the user's identity choice across launches.
///
/// 1.3.0 surfaces three identity modes via [Identity] — `user`, `anonymous`,
/// and `deferred`. The example app asks the user once on first launch and
/// replays the saved choice on subsequent launches.
class IdentityChoiceStore {
  static const _typeKey = 'com.zerosettle.flutter_example.identity_type';
  static const _idKey = 'com.zerosettle.flutter_example.identity_user_id';
  static const _nameKey = 'com.zerosettle.flutter_example.identity_user_name';
  static const _emailKey = 'com.zerosettle.flutter_example.identity_user_email';

  /// Load the persisted identity, or `null` if the user has not chosen yet.
  static Future<Identity?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final type = prefs.getString(_typeKey);
    if (type == null) return null;

    switch (type) {
      case 'user':
        final id = prefs.getString(_idKey);
        if (id == null || id.isEmpty) return null;
        return Identity.user(
          id: id,
          name: prefs.getString(_nameKey),
          email: prefs.getString(_emailKey),
        );
      case 'anonymous':
        return const Identity.anonymous();
      case 'deferred':
        return const Identity.deferred();
      default:
        return null;
    }
  }

  /// Save an identity choice. The next launch will replay it without prompting.
  static Future<void> save(Identity identity) async {
    final prefs = await SharedPreferences.getInstance();
    switch (identity) {
      case IdentityUser(:final id, :final name, :final email):
        await prefs.setString(_typeKey, 'user');
        await prefs.setString(_idKey, id);
        if (name != null) {
          await prefs.setString(_nameKey, name);
        } else {
          await prefs.remove(_nameKey);
        }
        if (email != null) {
          await prefs.setString(_emailKey, email);
        } else {
          await prefs.remove(_emailKey);
        }
      case IdentityAnonymous():
        await prefs.setString(_typeKey, 'anonymous');
        await prefs.remove(_idKey);
        await prefs.remove(_nameKey);
        await prefs.remove(_emailKey);
      case IdentityDeferred():
        await prefs.setString(_typeKey, 'deferred');
        await prefs.remove(_idKey);
        await prefs.remove(_nameKey);
        await prefs.remove(_emailKey);
    }
  }

  /// Clear any persisted identity. Used by `logout()` so the choice sheet
  /// re-appears on the next session.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_typeKey);
    await prefs.remove(_idKey);
    await prefs.remove(_nameKey);
    await prefs.remove(_emailKey);
  }
}

/// Helpers for displaying an [Identity] in the UI.
extension IdentityDisplay on Identity {
  /// Short label suitable for use in lists or labelled rows.
  String get displayLabel => switch (this) {
        IdentityUser(:final id) => id,
        IdentityAnonymous() => 'Anonymous',
        IdentityDeferred() => 'Deferred (will identify later)',
      };

  /// Mode label — "User", "Anonymous", or "Deferred".
  String get modeLabel => switch (this) {
        IdentityUser() => 'User',
        IdentityAnonymous() => 'Anonymous',
        IdentityDeferred() => 'Deferred',
      };

  /// The user id when this is an [IdentityUser]; `null` otherwise.
  String? get userIdOrNull => switch (this) {
        IdentityUser(:final id) => id,
        _ => null,
      };
}
