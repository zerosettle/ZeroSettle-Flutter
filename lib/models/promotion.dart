import 'enums.dart';
import 'price.dart';

/// An active promotion for a product.
class Promotion {
  final String id;
  final String displayName;
  final Price promotionalPrice;
  final DateTime? expiresAt;
  final PromotionType type;

  const Promotion({
    required this.id,
    required this.displayName,
    required this.promotionalPrice,
    this.expiresAt,
    required this.type,
  });

  factory Promotion.fromMap(Map<String, dynamic> map) {
    return Promotion(
      id: map['id'] as String,
      displayName: map['displayName'] as String,
      promotionalPrice: Price.fromMap(
        Map<String, dynamic>.from(map['promotionalPrice'] as Map),
      ),
      expiresAt: map['expiresAt'] != null
          ? DateTime.parse(map['expiresAt'] as String)
          : null,
      type: PromotionType.fromRawValue(map['type'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'promotionalPrice': promotionalPrice.toMap(),
      'expiresAt': expiresAt?.toIso8601String(),
      'type': type.rawValue,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Promotion &&
          id == other.id &&
          displayName == other.displayName &&
          promotionalPrice == other.promotionalPrice &&
          expiresAt == other.expiresAt &&
          type == other.type;

  @override
  int get hashCode => Object.hash(id, displayName, promotionalPrice, expiresAt, type);

  @override
  String toString() => 'Promotion(id: $id, displayName: $displayName, type: ${type.rawValue})';
}
