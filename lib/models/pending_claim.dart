/// A purchase that the current user could claim from a different
/// ZeroSettle account.
///
/// Surfaced when a store sync detects a cross-user ownership conflict (the
/// backend returns `conflict: true, claim_available: true`). The consuming
/// app can render UX ("This purchase belongs to another account — transfer
/// it?") and then call the matching transfer method to actually claim — or
/// ignore.
///
/// * **StoreKit** conflicts surface with [originalTransactionId] populated;
///   resolve via `transferStoreKitOwnershipToCurrentUser(productId:)`.
/// * **Play Billing** conflicts additionally carry [purchaseToken]; resolve
///   via `transferPlayOwnershipToCurrentUser(productId:)` — the SDK sources
///   the token internally from this claim.
class PendingClaim {
  /// The product identifier of the purchase that could be claimed.
  final String productId;

  /// The Apple StoreKit `originalTransactionId` (stringified UInt64) of the
  /// purchase backing this claim.
  final String originalTransactionId;

  /// Truncated SHA256 hash of the existing owner's `external_user_id`.
  ///
  /// Non-reversible; safe to display or log. Use for de-duplication or
  /// "previous account on this device" hints.
  final String existingOwnerHint;

  /// The Google Play `purchaseToken` for the conflicting purchase, when this
  /// claim originates from a Play Billing sync.
  ///
  /// `null` for StoreKit conflicts (Play has no token there). The SDK uses
  /// this to verify Play ownership server-side during a transfer; callers
  /// generally don't need to read it directly.
  final String? purchaseToken;

  const PendingClaim({
    required this.productId,
    required this.originalTransactionId,
    required this.existingOwnerHint,
    this.purchaseToken,
  });

  factory PendingClaim.fromMap(Map<String, dynamic> map) {
    return PendingClaim(
      productId: map['productId'] as String,
      originalTransactionId: map['originalTransactionId'] as String,
      existingOwnerHint: map['existingOwnerHint'] as String,
      purchaseToken: map['purchaseToken'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'originalTransactionId': originalTransactionId,
      'existingOwnerHint': existingOwnerHint,
      if (purchaseToken != null) 'purchaseToken': purchaseToken,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingClaim &&
          productId == other.productId &&
          originalTransactionId == other.originalTransactionId &&
          existingOwnerHint == other.existingOwnerHint &&
          purchaseToken == other.purchaseToken;

  @override
  int get hashCode => Object.hash(
        productId,
        originalTransactionId,
        existingOwnerHint,
        purchaseToken,
      );

  @override
  String toString() =>
      'PendingClaim(productId: $productId, originalTransactionId: $originalTransactionId)';
}
