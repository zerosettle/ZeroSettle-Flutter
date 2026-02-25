import 'enums.dart';
import 'price.dart';
import 'promotion.dart';

/// A product available for web checkout via ZeroSettle.
class Product {
  final String id;
  final String displayName;
  final String productDescription;
  final ZSProductType type;
  final Price? webPrice;
  final Price? appStorePrice;
  final bool syncedToAppStoreConnect;
  final Promotion? promotion;
  final int? subscriptionGroupId;
  final bool storeKitAvailable;
  final Price? storeKitPrice;
  final int? savingsPercent;

  const Product({
    required this.id,
    required this.displayName,
    required this.productDescription,
    required this.type,
    this.webPrice,
    this.appStorePrice,
    this.syncedToAppStoreConnect = false,
    this.promotion,
    this.subscriptionGroupId,
    this.storeKitAvailable = false,
    this.storeKitPrice,
    this.savingsPercent,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String,
      displayName: map['displayName'] as String,
      productDescription: map['productDescription'] as String,
      type: ZSProductType.fromRawValue(map['type'] as String),
      webPrice: map['webPrice'] != null
          ? Price.fromMap(Map<String, dynamic>.from(map['webPrice'] as Map))
          : null,
      appStorePrice: map['appStorePrice'] != null
          ? Price.fromMap(Map<String, dynamic>.from(map['appStorePrice'] as Map))
          : null,
      syncedToAppStoreConnect: map['syncedToAppStoreConnect'] as bool? ?? false,
      subscriptionGroupId: map['subscription_group_id'] as int?,
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
      'webPrice': webPrice?.toMap(),
      'appStorePrice': appStorePrice?.toMap(),
      'syncedToAppStoreConnect': syncedToAppStoreConnect,
      'subscriptionGroupId': subscriptionGroupId,
      'promotion': promotion?.toMap(),
      'storeKitAvailable': storeKitAvailable,
      'storeKitPrice': storeKitPrice?.toMap(),
      'savingsPercent': savingsPercent,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product &&
          id == other.id &&
          displayName == other.displayName &&
          productDescription == other.productDescription &&
          type == other.type &&
          webPrice == other.webPrice &&
          appStorePrice == other.appStorePrice &&
          syncedToAppStoreConnect == other.syncedToAppStoreConnect &&
          promotion == other.promotion &&
          subscriptionGroupId == other.subscriptionGroupId;

  @override
  int get hashCode => Object.hash(
        id, displayName, productDescription, type,
        webPrice, appStorePrice, syncedToAppStoreConnect, promotion, subscriptionGroupId,
      );

  @override
  String toString() => 'Product(id: $id, displayName: $displayName)';
}

/// Backward-compatible typedef. Use [Product] instead.
@Deprecated('Use Product instead')
typedef ZSProduct = Product;
