import 'enums.dart';

/// Represents an active entitlement from either a StoreKit or web checkout purchase.
class Entitlement {
  final String id;
  final String productId;
  final EntitlementSource source;
  final bool isActive;
  final DateTime? expiresAt;
  final DateTime purchasedAt;

  const Entitlement({
    required this.id,
    required this.productId,
    required this.source,
    required this.isActive,
    this.expiresAt,
    required this.purchasedAt,
  });

  factory Entitlement.fromMap(Map<String, dynamic> map) {
    return Entitlement(
      id: map['id'] as String,
      productId: map['productId'] as String,
      source: EntitlementSource.fromRawValue(map['source'] as String),
      isActive: map['isActive'] as bool,
      expiresAt: map['expiresAt'] != null
          ? DateTime.parse(map['expiresAt'] as String)
          : null,
      purchasedAt: DateTime.parse(map['purchasedAt'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'source': source.rawValue,
      'isActive': isActive,
      'expiresAt': expiresAt?.toIso8601String(),
      'purchasedAt': purchasedAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Entitlement &&
          id == other.id &&
          productId == other.productId &&
          source == other.source &&
          isActive == other.isActive &&
          expiresAt == other.expiresAt &&
          purchasedAt == other.purchasedAt;

  @override
  int get hashCode =>
      Object.hash(id, productId, source, isActive, expiresAt, purchasedAt);

  @override
  String toString() =>
      'Entitlement(id: $id, productId: $productId, source: ${source.rawValue}, isActive: $isActive)';
}
