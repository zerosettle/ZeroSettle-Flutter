/// A StoreKit purchase that the current user could claim from a different
/// ZeroSettle account.
///
/// Surfaced when StoreKit sync detects a cross-user original-transaction-id
/// conflict (the backend returns `conflict: true, claim_available: true`). The
/// consuming app can render UX ("This purchase belongs to another account —
/// transfer it?") and then call
/// `ZeroSettle.instance.transferStoreKitOwnershipToCurrentUser(productId: ...)`
/// to actually claim — or ignore.
class PendingClaim {
  /// The product identifier of the StoreKit purchase that could be claimed.
  final String productId;

  /// The Apple StoreKit `originalTransactionId` (stringified UInt64) of the
  /// purchase backing this claim.
  final String originalTransactionId;

  /// Truncated SHA256 hash of the existing owner's `external_user_id`.
  ///
  /// Non-reversible; safe to display or log. Use for de-duplication or
  /// "previous account on this device" hints.
  final String existingOwnerHint;

  const PendingClaim({
    required this.productId,
    required this.originalTransactionId,
    required this.existingOwnerHint,
  });

  factory PendingClaim.fromMap(Map<String, dynamic> map) {
    return PendingClaim(
      productId: map['productId'] as String,
      originalTransactionId: map['originalTransactionId'] as String,
      existingOwnerHint: map['existingOwnerHint'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'originalTransactionId': originalTransactionId,
      'existingOwnerHint': existingOwnerHint,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingClaim &&
          productId == other.productId &&
          originalTransactionId == other.originalTransactionId &&
          existingOwnerHint == other.existingOwnerHint;

  @override
  int get hashCode =>
      Object.hash(productId, originalTransactionId, existingOwnerHint);

  @override
  String toString() =>
      'PendingClaim(productId: $productId, originalTransactionId: $originalTransactionId)';
}
