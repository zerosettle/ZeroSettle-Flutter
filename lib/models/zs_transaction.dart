import 'enums.dart';

/// Represents a completed or pending purchase transaction.
class CheckoutTransaction {
  final String id;
  final String productId;
  final TransactionStatus status;
  final EntitlementSource source;
  final DateTime purchasedAt;
  final DateTime? expiresAt;
  final String? productName;
  final int? amountCents;
  final String? currency;

  const CheckoutTransaction({
    required this.id,
    required this.productId,
    required this.status,
    required this.source,
    required this.purchasedAt,
    this.expiresAt,
    this.productName,
    this.amountCents,
    this.currency,
  });

  factory CheckoutTransaction.fromMap(Map<String, dynamic> map) {
    return CheckoutTransaction(
      id: map['id'] as String,
      productId: map['productId'] as String,
      status: TransactionStatus.fromRawValue(map['status'] as String),
      source: EntitlementSource.fromRawValue(map['source'] as String),
      purchasedAt: DateTime.parse(map['purchasedAt'] as String),
      expiresAt: map['expiresAt'] != null
          ? DateTime.parse(map['expiresAt'] as String)
          : null,
      productName: map['productName'] as String?,
      amountCents: map['amountCents'] as int?,
      currency: map['currency'] as String?,
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
      'productName': productName,
      'amountCents': amountCents,
      'currency': currency,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CheckoutTransaction &&
          id == other.id &&
          productId == other.productId &&
          status == other.status &&
          source == other.source &&
          purchasedAt == other.purchasedAt &&
          expiresAt == other.expiresAt &&
          productName == other.productName &&
          amountCents == other.amountCents &&
          currency == other.currency;

  @override
  int get hashCode =>
      Object.hash(id, productId, status, source, purchasedAt, expiresAt,
          productName, amountCents, currency);

  @override
  String toString() =>
      'CheckoutTransaction(id: $id, productId: $productId, status: ${status.rawValue})';
}

/// Backward-compatible typedef. Use [CheckoutTransaction] instead.
@Deprecated('Use CheckoutTransaction instead')
typedef ZSTransaction = CheckoutTransaction;
