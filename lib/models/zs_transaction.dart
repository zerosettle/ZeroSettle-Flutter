import 'enums.dart';

/// Represents a completed or pending purchase transaction.
class ZSTransaction {
  final String id;
  final String productId;
  final TransactionStatus status;
  final EntitlementSource source;
  final DateTime purchasedAt;
  final DateTime? expiresAt;

  const ZSTransaction({
    required this.id,
    required this.productId,
    required this.status,
    required this.source,
    required this.purchasedAt,
    this.expiresAt,
  });

  factory ZSTransaction.fromMap(Map<String, dynamic> map) {
    return ZSTransaction(
      id: map['id'] as String,
      productId: map['productId'] as String,
      status: TransactionStatus.fromRawValue(map['status'] as String),
      source: EntitlementSource.fromRawValue(map['source'] as String),
      purchasedAt: DateTime.parse(map['purchasedAt'] as String),
      expiresAt: map['expiresAt'] != null
          ? DateTime.parse(map['expiresAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'status': status.rawValue,
      'source': source.rawValue,
      'purchasedAt': purchasedAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZSTransaction &&
          id == other.id &&
          productId == other.productId &&
          status == other.status &&
          source == other.source &&
          purchasedAt == other.purchasedAt &&
          expiresAt == other.expiresAt;

  @override
  int get hashCode =>
      Object.hash(id, productId, status, source, purchasedAt, expiresAt);

  @override
  String toString() =>
      'ZSTransaction(id: $id, productId: $productId, status: ${status.rawValue})';
}
