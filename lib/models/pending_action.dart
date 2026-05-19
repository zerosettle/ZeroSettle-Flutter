/// A backend-driven prompt for the user, surfaced via
/// [ZeroSettle.pendingActionsUpdates]. Android-only data; the iOS bridge
/// always reports an empty list.
sealed class PendingAction {
  final String transactionId;
  final String userMessage;
  const PendingAction({required this.transactionId, required this.userMessage});

  factory PendingAction.fromMap(Map<String, dynamic> map) {
    final type = map['type'] as String?;
    return switch (type) {
      'migrationCompletedInfo' =>
        PendingActionMigrationCompletedInfo._fromMap(map),
      'manualPlayCancel' => PendingActionManualPlayCancel._fromMap(map),
      _ => throw ArgumentError('Unknown PendingAction type: $type'),
    };
  }

  /// Round-trips the action back to a channel map (used by widgets that
  /// pass an action to a native PlatformView).
  Map<String, dynamic> toMap();
}

/// One-time info banner shown after a successful Play→web migration.
class PendingActionMigrationCompletedInfo extends PendingAction {
  final String? playAccessEndsAt;
  final int? newSubscriptionPriceCents;
  final String? newSubscriptionCurrency;
  final String? newSubscriptionInterval;

  const PendingActionMigrationCompletedInfo({
    required super.transactionId,
    required super.userMessage,
    this.playAccessEndsAt,
    this.newSubscriptionPriceCents,
    this.newSubscriptionCurrency,
    this.newSubscriptionInterval,
  });

  factory PendingActionMigrationCompletedInfo._fromMap(Map<String, dynamic> m) =>
      PendingActionMigrationCompletedInfo(
        transactionId: m['transactionId'] as String,
        userMessage: m['userMessage'] as String,
        playAccessEndsAt: m['playAccessEndsAt'] as String?,
        newSubscriptionPriceCents: m['newSubscriptionPriceCents'] as int?,
        newSubscriptionCurrency: m['newSubscriptionCurrency'] as String?,
        newSubscriptionInterval: m['newSubscriptionInterval'] as String?,
      );

  @override
  Map<String, dynamic> toMap() => {
        'type': 'migrationCompletedInfo',
        'transactionId': transactionId,
        'userMessage': userMessage,
        if (playAccessEndsAt != null) 'playAccessEndsAt': playAccessEndsAt,
        if (newSubscriptionPriceCents != null)
          'newSubscriptionPriceCents': newSubscriptionPriceCents,
        if (newSubscriptionCurrency != null)
          'newSubscriptionCurrency': newSubscriptionCurrency,
        if (newSubscriptionInterval != null)
          'newSubscriptionInterval': newSubscriptionInterval,
      };
}

/// Actionable banner shown when the backend's programmatic Play cancel
/// failed and the user must cancel manually via [deepLink].
class PendingActionManualPlayCancel extends PendingAction {
  final String originalPlayPurchaseToken;
  final String? expiresAt;
  final String deepLink;

  const PendingActionManualPlayCancel({
    required super.transactionId,
    required super.userMessage,
    required this.originalPlayPurchaseToken,
    required this.deepLink,
    this.expiresAt,
  });

  factory PendingActionManualPlayCancel._fromMap(Map<String, dynamic> m) =>
      PendingActionManualPlayCancel(
        transactionId: m['transactionId'] as String,
        userMessage: m['userMessage'] as String,
        originalPlayPurchaseToken: m['originalPlayPurchaseToken'] as String,
        deepLink: m['deepLink'] as String,
        expiresAt: m['expiresAt'] as String?,
      );

  @override
  Map<String, dynamic> toMap() => {
        'type': 'manualPlayCancel',
        'transactionId': transactionId,
        'userMessage': userMessage,
        'originalPlayPurchaseToken': originalPlayPurchaseToken,
        'deepLink': deepLink,
        if (expiresAt != null) 'expiresAt': expiresAt,
      };
}
