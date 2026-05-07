import 'enums.dart';

/// Per-jurisdiction checkout configuration override.
class JurisdictionCheckoutConfig {
  final CheckoutType sheetType;
  final bool isEnabled;

  const JurisdictionCheckoutConfig({
    required this.sheetType,
    required this.isEnabled,
  });

  factory JurisdictionCheckoutConfig.fromMap(Map<String, dynamic> map) {
    return JurisdictionCheckoutConfig(
      sheetType: CheckoutType.fromRawValue(map['sheetType'] as String),
      isEnabled: map['isEnabled'] as bool,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sheetType': sheetType.rawValue,
      'isEnabled': isEnabled,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JurisdictionCheckoutConfig &&
          sheetType == other.sheetType &&
          isEnabled == other.isEnabled;

  @override
  int get hashCode => Object.hash(sheetType, isEnabled);
}

/// Configuration for the checkout UI behavior.
class CheckoutConfig {
  final CheckoutType sheetType;
  final bool isEnabled;
  final Map<Jurisdiction, JurisdictionCheckoutConfig> jurisdictions;

  /// Allowed payment methods for this merchant. `null` (or missing on the
  /// wire) means no restriction. `["apple_pay"]` restricts the SDK to
  /// Apple-Pay-only behavior. Other values are accepted for forward
  /// compatibility but trigger no current behavior change.
  final List<String>? paymentMethods;

  const CheckoutConfig({
    required this.sheetType,
    required this.isEnabled,
    this.jurisdictions = const {},
    this.paymentMethods,
  });

  /// True when the merchant has restricted payment to Apple Pay only.
  /// Drives native availability checks and banner CTA swap.
  ///
  /// Mirrors the iOS Kit's `CheckoutConfig.isApplePayOnly` computed
  /// property — true iff `paymentMethods == ["apple_pay"]`.
  bool get isApplePayOnly =>
      paymentMethods != null &&
      paymentMethods!.length == 1 &&
      paymentMethods!.first == 'apple_pay';

  factory CheckoutConfig.fromMap(Map<String, dynamic> map) {
    final jurisdictionsMap = <Jurisdiction, JurisdictionCheckoutConfig>{};
    if (map['jurisdictions'] != null) {
      final raw = Map<String, dynamic>.from(map['jurisdictions'] as Map);
      for (final entry in raw.entries) {
        jurisdictionsMap[Jurisdiction.fromRawValue(entry.key)] =
            JurisdictionCheckoutConfig.fromMap(
                Map<String, dynamic>.from(entry.value as Map));
      }
    }
    final paymentMethodsRaw = map['paymentMethods'];
    final List<String>? paymentMethods = paymentMethodsRaw == null
        ? null
        : (paymentMethodsRaw as List).map((e) => e as String).toList();
    return CheckoutConfig(
      sheetType: CheckoutType.fromRawValue(map['sheetType'] as String),
      isEnabled: map['isEnabled'] as bool,
      jurisdictions: jurisdictionsMap,
      paymentMethods: paymentMethods,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sheetType': sheetType.rawValue,
      'isEnabled': isEnabled,
      'jurisdictions': jurisdictions.map(
        (k, v) => MapEntry(k.rawValue, v.toMap()),
      ),
      if (paymentMethods != null) 'paymentMethods': paymentMethods,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CheckoutConfig &&
          sheetType == other.sheetType &&
          isEnabled == other.isEnabled;

  @override
  int get hashCode => Object.hash(sheetType, isEnabled);
}

/// Data for a migration campaign prompt.
class MigrationPrompt {
  final String productId;
  final int discountPercent;
  final String title;
  final String message;
  final String ctaText;

  const MigrationPrompt({
    required this.productId,
    required this.discountPercent,
    required this.title,
    required this.message,
    required this.ctaText,
  });

  factory MigrationPrompt.fromMap(Map<String, dynamic> map) {
    final discountPercent = map['discountPercent'] as int;
    return MigrationPrompt(
      productId: map['productId'] as String,
      discountPercent: discountPercent,
      title: map['title'] as String,
      message: map['message'] as String,
      ctaText: map['ctaText'] as String? ?? 'Save $discountPercent% Forever',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'discountPercent': discountPercent,
      'title': title,
      'message': message,
      'ctaText': ctaText,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MigrationPrompt &&
          productId == other.productId &&
          discountPercent == other.discountPercent &&
          title == other.title &&
          message == other.message &&
          ctaText == other.ctaText;

  @override
  int get hashCode => Object.hash(productId, discountPercent, title, message, ctaText);
}

/// Remote configuration from the ZeroSettle backend.
class RemoteConfig {
  final CheckoutConfig checkout;
  final MigrationPrompt? migration;

  const RemoteConfig({
    required this.checkout,
    this.migration,
  });

  factory RemoteConfig.fromMap(Map<String, dynamic> map) {
    return RemoteConfig(
      checkout: CheckoutConfig.fromMap(
        Map<String, dynamic>.from(map['checkout'] as Map),
      ),
      migration: map['migration'] != null
          ? MigrationPrompt.fromMap(
              Map<String, dynamic>.from(map['migration'] as Map))
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'checkout': checkout.toMap(),
      'migration': migration?.toMap(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RemoteConfig &&
          checkout == other.checkout &&
          migration == other.migration;

  @override
  int get hashCode => Object.hash(checkout, migration);
}
