/// Identity hint for [ZeroSettle.identify]. Mirrors the native `Identity` enum.
///
/// Pick exactly one per session. Don't mix [IdentityUser] with [IdentityAnonymous]
/// for the same person — that creates two backend identities.
sealed class Identity {
  const Identity();

  /// An authenticated app user.
  const factory Identity.user({required String id, String? name, String? email}) = IdentityUser;

  /// No authenticated user. The SDK generates and persists a stable session UUID.
  const factory Identity.anonymous() = IdentityAnonymous;

  /// Authentication is coming on a later screen. Suppresses the
  /// "no user identified" warning until [Identity.user] or [Identity.anonymous]
  /// is provided.
  const factory Identity.deferred() = IdentityDeferred;

  Map<String, dynamic> toMap();
}

class IdentityUser extends Identity {
  final String id;
  final String? name;
  final String? email;

  const IdentityUser({required this.id, this.name, this.email});

  @override
  Map<String, dynamic> toMap() => {
        'type': 'user',
        'id': id,
        if (name != null) 'name': name,
        if (email != null) 'email': email,
      };
}

class IdentityAnonymous extends Identity {
  const IdentityAnonymous();

  @override
  Map<String, dynamic> toMap() => {'type': 'anonymous'};
}

class IdentityDeferred extends Identity {
  const IdentityDeferred();

  @override
  Map<String, dynamic> toMap() => {'type': 'deferred'};
}
