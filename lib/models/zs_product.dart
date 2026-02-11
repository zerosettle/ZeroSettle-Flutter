import 'enums.dart';
import 'price.dart';
import 'promotion.dart';

/// A product available for web checkout via ZeroSettle.
class ZSProduct {
  final String id;
  final String displayName;
  final String productDescription;
  final ZSProductType type;
  final Price webPrice;
  final Price? appStorePrice;
  final bool syncedToASC;
  final Promotion? promotion;
  final bool storeKitAvailable;
  final Price? storeKitPrice;
  final int? savingsPercent;

  const ZSProduct({
    required this.id,
    required this.displayName,
    required this.productDescription,
    required this.type,
    required this.webPrice,
    this.appStorePrice,
    this.syncedToASC = false,
    this.promotion,
    this.storeKitAvailable = false,
    this.storeKitPrice,
    this.savingsPercent,
  });

  factory ZSProduct.fromMap(Map<String, dynamic> map) {
    return ZSProduct(
      id: map['id'] as String,
      displayName: map['displayName'] as String,
      productDescription: map['productDescription'] as String,
      type: ZSProductType.fromRawValue(map['type'] as String),
      webPrice: Price.fromMap(Map<String, dynamic>.from(map['webPrice'] as Map)),
      appStorePrice: map['appStorePrice'] != null
          ? Price.fromMap(Map<String, dynamic>.from(map['appStorePrice'] as Map))
          : null,
      syncedToASC: map['syncedToASC'] as bool? ?? false,
      promotion: map['promotion'] != null
          ? Promotion.fromMap(Map<String, dynamic>.from(map['promotion'] as Map))
          : null,
      storeKitAvailable: map['storeKitAvailable'] as bool? ?? false,
      storeKitPrice: map['storeKitPrice'] != null
          ? Price.fromMap(Map<String, dynamic>.from(map['storeKitPrice'] as Map))
          : null,
      savingsPercent: map['savingsPercent'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'productDescription': productDescription,
      'type': type.rawValue,
      'webPrice': webPrice.toMap(),
      'appStorePrice': appStorePrice?.toMap(),
      'syncedToASC': syncedToASC,
      'promotion': promotion?.toMap(),
      'storeKitAvailable': storeKitAvailable,
      'storeKitPrice': storeKitPrice?.toMap(),
      'savingsPercent': savingsPercent,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZSProduct &&
          id == other.id &&
          displayName == other.displayName &&
          productDescription == other.productDescription &&
          type == other.type &&
          webPrice == other.webPrice &&
          appStorePrice == other.appStorePrice &&
          syncedToASC == other.syncedToASC &&
          promotion == other.promotion;

  @override
  int get hashCode => Object.hash(
        id, displayName, productDescription, type,
        webPrice, appStorePrice, syncedToASC, promotion,
      );

  @override
  String toString() => 'ZSProduct(id: $id, displayName: $displayName)';
}
