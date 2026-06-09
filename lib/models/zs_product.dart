import 'enums.dart';
import 'price.dart';
import 'promotion.dart';

/// Trial billing facts for a subscription product.
///
/// When the bridge emits a `trial` map with an unrecognised `mode`,
/// [fromMap] returns `null` — mirroring the iOS ZSProduct behaviour.
class TrialFacts {
  final ZSTrialMode mode;
  final String? duration;
  final int upfrontAmountCents;
  final int holdAmountCents;
  final bool validatesCard;

  const TrialFacts({
    required this.mode,
    this.duration,
    this.upfrontAmountCents = 0,
    this.holdAmountCents = 0,
    this.validatesCard = false,
  });

  /// Returns null (the whole trial) when mode is missing/unknown — mirrors iOS.
  static TrialFacts? fromMap(Map<String, dynamic> map) {
    final raw = map['mode'] as String?;
    final mode = raw == null ? null : ZSTrialMode.fromRawValueOrNull(raw);
    if (mode == null) return null;
    return TrialFacts(
      mode: mode,
      duration: map['duration'] as String?,
      upfrontAmountCents: map['upfrontAmountCents'] as int? ?? 0,
      holdAmountCents: map['holdAmountCents'] as int? ?? 0,
      validatesCard: map['validatesCard'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'mode': mode.rawValue,
        if (duration != null) 'duration': duration,
        'upfrontAmountCents': upfrontAmountCents,
        'holdAmountCents': holdAmountCents,
        'validatesCard': validatesCard,
      };

  @override
  bool operator ==(Object other) =>
      other is TrialFacts &&
      other.mode == mode &&
      other.duration == duration &&
      other.upfrontAmountCents == upfrontAmountCents &&
      other.holdAmountCents == holdAmountCents &&
      other.validatesCard == validatesCard;

  @override
  int get hashCode => Object.hash(
        mode,
        duration,
        upfrontAmountCents,
        holdAmountCents,
        validatesCard,
      );
}

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
  final String? billingInterval;
  final String? freeTrialDuration;
  final bool? isTrialEligible;
  final TrialFacts? trial;

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
    this.billingInterval,
    this.freeTrialDuration,
    this.isTrialEligible,
    this.trial,
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
      subscriptionGroupId: map['subscriptionGroupId'] as int?,
      promotion: map['promotion'] != null
          ? Promotion.fromMap(Map<String, dynamic>.from(map['promotion'] as Map))
          : null,
      storeKitAvailable: map['storeKitAvailable'] as bool? ?? false,
      storeKitPrice: map['storeKitPrice'] != null
          ? Price.fromMap(Map<String, dynamic>.from(map['storeKitPrice'] as Map))
          : null,
      savingsPercent: map['savingsPercent'] as int?,
      billingInterval: map['billingInterval'] as String?,
      freeTrialDuration: map['freeTrialDuration'] as String?,
      isTrialEligible: map['isTrialEligible'] as bool?,
      trial: map['trial'] != null
          ? TrialFacts.fromMap(Map<String, dynamic>.from(map['trial'] as Map))
          : null,
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
      'billingInterval': billingInterval,
      'freeTrialDuration': freeTrialDuration,
      'isTrialEligible': isTrialEligible,
      if (trial != null) 'trial': trial!.toMap(),
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
          subscriptionGroupId == other.subscriptionGroupId &&
          billingInterval == other.billingInterval &&
          freeTrialDuration == other.freeTrialDuration &&
          isTrialEligible == other.isTrialEligible &&
          trial == other.trial;

  @override
  int get hashCode => Object.hash(
        id, displayName, productDescription, type,
        webPrice, appStorePrice, syncedToAppStoreConnect, promotion, subscriptionGroupId,
        billingInterval, freeTrialDuration, isTrialEligible, trial,
      );

  @override
  String toString() => 'Product(id: $id, displayName: $displayName)';
}

/// Backward-compatible typedef. Use [Product] instead.
@Deprecated('Use Product instead')
typedef ZSProduct = Product;
