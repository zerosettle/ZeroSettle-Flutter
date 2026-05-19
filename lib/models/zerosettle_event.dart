/// A discriminated event emitted by the ZeroSettle native SDK event stream.
///
/// Decode with [ZeroSettleEvent.fromMap]. Unknown event types decode to
/// [ZSEventUnknown] rather than throwing, so apps built against an older SDK
/// version don't crash when the server introduces new event variants.
sealed class ZeroSettleEvent {
  const ZeroSettleEvent();

  factory ZeroSettleEvent.fromMap(Map<String, dynamic> map) {
    final type = map['type'] as String?;
    return switch (type) {
      'offerShown' => ZSEventOfferShown._fromMap(map),
      'offerAccepted' => ZSEventOfferAccepted._fromMap(map),
      'offerDismissed' => ZSEventOfferDismissed._fromMap(map),
      'offerEvaluationFailed' => ZSEventOfferEvaluationFailed._fromMap(map),
      'purchaseSucceeded' => ZSEventPurchaseSucceeded._fromMap(map),
      'purchaseFailed' => ZSEventPurchaseFailed._fromMap(map),
      'migrationCompleted' => ZSEventMigrationCompleted._fromMap(map),
      'syncFailed' => ZSEventSyncFailed._fromMap(map),
      'entitlementsRefreshed' => ZSEventEntitlementsRefreshed._fromMap(map),
      'pendingActionShown' => ZSEventPendingActionShown._fromMap(map),
      _ => ZSEventUnknown(type ?? ''),
    };
  }
}

/// Emitted when an offer tip (migration or upgrade) is presented to the user.
final class ZSEventOfferShown extends ZeroSettleEvent {
  /// The product ID for which the offer was shown.
  final String productId;

  const ZSEventOfferShown({required this.productId});

  factory ZSEventOfferShown._fromMap(Map<String, dynamic> m) =>
      ZSEventOfferShown(
        productId: (m['productId'] as String?) ?? '',
      );
}

/// Emitted when the user accepts an offer tip.
final class ZSEventOfferAccepted extends ZeroSettleEvent {
  /// The product ID for which the offer was accepted.
  final String productId;

  const ZSEventOfferAccepted({required this.productId});

  factory ZSEventOfferAccepted._fromMap(Map<String, dynamic> m) =>
      ZSEventOfferAccepted(
        productId: (m['productId'] as String?) ?? '',
      );
}

/// Emitted when the user dismisses an offer tip without acting on it.
final class ZSEventOfferDismissed extends ZeroSettleEvent {
  /// The product ID for which the offer was dismissed.
  final String productId;

  const ZSEventOfferDismissed({required this.productId});

  factory ZSEventOfferDismissed._fromMap(Map<String, dynamic> m) =>
      ZSEventOfferDismissed(
        productId: (m['productId'] as String?) ?? '',
      );
}

/// Emitted when the SDK fails to evaluate an offer for the current user.
final class ZSEventOfferEvaluationFailed extends ZeroSettleEvent {
  /// Human-readable reason for the evaluation failure.
  final String reason;

  const ZSEventOfferEvaluationFailed({required this.reason});

  factory ZSEventOfferEvaluationFailed._fromMap(Map<String, dynamic> m) =>
      ZSEventOfferEvaluationFailed(
        reason: (m['reason'] as String?) ?? '',
      );
}

/// Emitted when a purchase completes successfully via any channel.
final class ZSEventPurchaseSucceeded extends ZeroSettleEvent {
  /// The product that was purchased.
  final String productId;

  /// The ZeroSettle transaction ID for the completed purchase.
  final String transactionId;

  const ZSEventPurchaseSucceeded({
    required this.productId,
    required this.transactionId,
  });

  factory ZSEventPurchaseSucceeded._fromMap(Map<String, dynamic> m) =>
      ZSEventPurchaseSucceeded(
        productId: (m['productId'] as String?) ?? '',
        transactionId: (m['transactionId'] as String?) ?? '',
      );
}

/// Emitted when a purchase attempt fails after exhausting retries.
final class ZSEventPurchaseFailed extends ZeroSettleEvent {
  /// The product for which the purchase failed.
  final String productId;

  /// Human-readable reason for the failure.
  final String reason;

  const ZSEventPurchaseFailed({
    required this.productId,
    required this.reason,
  });

  factory ZSEventPurchaseFailed._fromMap(Map<String, dynamic> m) =>
      ZSEventPurchaseFailed(
        productId: (m['productId'] as String?) ?? '',
        reason: (m['reason'] as String?) ?? '',
      );
}

/// Emitted when a Switch & Save migration has completed successfully.
final class ZSEventMigrationCompleted extends ZeroSettleEvent {
  /// The product ID that was migrated to web billing.
  final String productId;

  const ZSEventMigrationCompleted({required this.productId});

  factory ZSEventMigrationCompleted._fromMap(Map<String, dynamic> m) =>
      ZSEventMigrationCompleted(
        productId: (m['productId'] as String?) ?? '',
      );
}

/// Emitted when a background store-transaction sync fails.
///
/// When [terminal] is `true` the SDK has given up retrying and the purchase
/// may not be reflected in the backend until the user manually restores.
final class ZSEventSyncFailed extends ZeroSettleEvent {
  /// The Play purchase token (Android) or StoreKit original transaction ID
  /// (iOS) that failed to sync.
  final String purchaseToken;

  /// The number of sync attempts made so far.
  final int attempts;

  /// Whether the SDK considers this failure terminal (no further retries).
  final bool terminal;

  const ZSEventSyncFailed({
    required this.purchaseToken,
    required this.attempts,
    required this.terminal,
  });

  factory ZSEventSyncFailed._fromMap(Map<String, dynamic> m) =>
      ZSEventSyncFailed(
        purchaseToken: (m['purchaseToken'] as String?) ?? '',
        attempts: (m['attempts'] as int?) ?? 0,
        terminal: (m['terminal'] as bool?) ?? false,
      );
}

/// Emitted when the SDK's entitlement cache is refreshed from the backend.
final class ZSEventEntitlementsRefreshed extends ZeroSettleEvent {
  /// The total number of active entitlements after the refresh.
  final int count;

  const ZSEventEntitlementsRefreshed({required this.count});

  factory ZSEventEntitlementsRefreshed._fromMap(Map<String, dynamic> m) =>
      ZSEventEntitlementsRefreshed(
        count: (m['count'] as int?) ?? 0,
      );
}

/// Emitted when the SDK surfaces a pending-action banner to the user.
final class ZSEventPendingActionShown extends ZeroSettleEvent {
  /// The pending-action type string (e.g. `'migrationCompletedInfo'`).
  final String actionType;

  const ZSEventPendingActionShown({required this.actionType});

  factory ZSEventPendingActionShown._fromMap(Map<String, dynamic> m) =>
      ZSEventPendingActionShown(
        actionType: (m['actionType'] as String?) ?? '',
      );
}

/// Fallback variant for any event type not recognised by this SDK version.
///
/// Forward-compatibility: new event types introduced by the server or a newer
/// SDK version are surfaced here rather than thrown, so existing apps continue
/// to function without crashing.
final class ZSEventUnknown extends ZeroSettleEvent {
  /// The raw `type` string from the event map.
  final String type;

  const ZSEventUnknown(this.type);
}
