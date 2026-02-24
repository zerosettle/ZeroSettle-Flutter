/// Upgrade offer configuration returned by the backend.
class UpgradeOfferConfig {
  final bool available;
  final String? reason;
  final UpgradeOfferCurrentProduct? currentProduct;
  final UpgradeOfferTargetProduct? targetProduct;
  final int? savingsPercent;
  final String? upgradeType;
  final UpgradeOfferProration? proration;
  final UpgradeOfferDisplay? display;

  /// A/B experiment variant identifier, if this config is part of an experiment.
  final int? variantId;

  UpgradeOfferConfig({
    required this.available,
    this.reason,
    this.currentProduct,
    this.targetProduct,
    this.savingsPercent,
    this.upgradeType,
    this.proration,
    this.display,
    this.variantId,
  });

  factory UpgradeOfferConfig.fromMap(Map<String, dynamic> map) {
    return UpgradeOfferConfig(
      available: map['available'] as bool,
      reason: map['reason'] as String?,
      currentProduct: map['currentProduct'] != null
          ? UpgradeOfferCurrentProduct.fromMap(
              Map<String, dynamic>.from(map['currentProduct'] as Map))
          : null,
      targetProduct: map['targetProduct'] != null
          ? UpgradeOfferTargetProduct.fromMap(
              Map<String, dynamic>.from(map['targetProduct'] as Map))
          : null,
      savingsPercent: map['savingsPercent'] as int?,
      upgradeType: map['upgradeType'] as String?,
      proration: map['proration'] != null
          ? UpgradeOfferProration.fromMap(
              Map<String, dynamic>.from(map['proration'] as Map))
          : null,
      display: map['display'] != null
          ? UpgradeOfferDisplay.fromMap(
              Map<String, dynamic>.from(map['display'] as Map))
          : null,
      variantId: map['variantId'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'available': available,
      if (reason != null) 'reason': reason,
      if (currentProduct != null) 'currentProduct': currentProduct!.toMap(),
      if (targetProduct != null) 'targetProduct': targetProduct!.toMap(),
      if (savingsPercent != null) 'savingsPercent': savingsPercent,
      if (upgradeType != null) 'upgradeType': upgradeType,
      if (proration != null) 'proration': proration!.toMap(),
      if (display != null) 'display': display!.toMap(),
      if (variantId != null) 'variantId': variantId,
    };
  }
}

/// The user's current subscription product within an upgrade offer.
class UpgradeOfferCurrentProduct {
  final String referenceId;
  final String name;
  final int priceCents;
  final String currency;
  final int durationDays;
  final String billingLabel;

  UpgradeOfferCurrentProduct({
    required this.referenceId,
    required this.name,
    required this.priceCents,
    required this.currency,
    required this.durationDays,
    required this.billingLabel,
  });

  factory UpgradeOfferCurrentProduct.fromMap(Map<String, dynamic> map) {
    return UpgradeOfferCurrentProduct(
      referenceId: map['referenceId'] as String,
      name: map['name'] as String,
      priceCents: map['priceCents'] as int,
      currency: map['currency'] as String,
      durationDays: map['durationDays'] as int,
      billingLabel: map['billingLabel'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'referenceId': referenceId,
      'name': name,
      'priceCents': priceCents,
      'currency': currency,
      'durationDays': durationDays,
      'billingLabel': billingLabel,
    };
  }
}

/// The target subscription product the user can upgrade to.
class UpgradeOfferTargetProduct {
  final String referenceId;
  final String name;
  final int priceCents;
  final String currency;
  final int durationDays;
  final String billingLabel;
  final int monthlyEquivalentCents;

  UpgradeOfferTargetProduct({
    required this.referenceId,
    required this.name,
    required this.priceCents,
    required this.currency,
    required this.durationDays,
    required this.billingLabel,
    required this.monthlyEquivalentCents,
  });

  factory UpgradeOfferTargetProduct.fromMap(Map<String, dynamic> map) {
    return UpgradeOfferTargetProduct(
      referenceId: map['referenceId'] as String,
      name: map['name'] as String,
      priceCents: map['priceCents'] as int,
      currency: map['currency'] as String,
      durationDays: map['durationDays'] as int,
      billingLabel: map['billingLabel'] as String,
      monthlyEquivalentCents: map['monthlyEquivalentCents'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'referenceId': referenceId,
      'name': name,
      'priceCents': priceCents,
      'currency': currency,
      'durationDays': durationDays,
      'billingLabel': billingLabel,
      'monthlyEquivalentCents': monthlyEquivalentCents,
    };
  }
}

/// Proration details for the upgrade transition.
class UpgradeOfferProration {
  final int prorationAmountCents;
  final String currency;
  final int? nextBillingDate;

  UpgradeOfferProration({
    required this.prorationAmountCents,
    required this.currency,
    this.nextBillingDate,
  });

  factory UpgradeOfferProration.fromMap(Map<String, dynamic> map) {
    return UpgradeOfferProration(
      prorationAmountCents: map['prorationAmountCents'] as int,
      currency: map['currency'] as String,
      nextBillingDate: map['nextBillingDate'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'prorationAmountCents': prorationAmountCents,
      'currency': currency,
      if (nextBillingDate != null) 'nextBillingDate': nextBillingDate,
    };
  }
}

/// Display copy for the upgrade offer sheet.
class UpgradeOfferDisplay {
  final String title;
  final String body;
  final String ctaText;
  final String dismissText;
  final String? storekitMigrationBody;
  final String? cancelInstructions;

  UpgradeOfferDisplay({
    required this.title,
    required this.body,
    required this.ctaText,
    required this.dismissText,
    this.storekitMigrationBody,
    this.cancelInstructions,
  });

  factory UpgradeOfferDisplay.fromMap(Map<String, dynamic> map) {
    return UpgradeOfferDisplay(
      title: map['title'] as String,
      body: map['body'] as String,
      ctaText: map['ctaText'] as String,
      dismissText: map['dismissText'] as String,
      storekitMigrationBody: map['storekitMigrationBody'] as String?,
      cancelInstructions: map['cancelInstructions'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'ctaText': ctaText,
      'dismissText': dismissText,
      if (storekitMigrationBody != null)
        'storekitMigrationBody': storekitMigrationBody,
      if (cancelInstructions != null) 'cancelInstructions': cancelInstructions,
    };
  }
}

/// The outcome of an upgrade offer presentation.
sealed class UpgradeOfferResult {
  const UpgradeOfferResult();

  /// Parse a raw result string from the native method channel.
  ///
  /// Valid values: "upgraded", "declined", "dismissed".
  static UpgradeOfferResult fromRawValue(String value) {
    switch (value) {
      case 'upgraded':
        return const UpgradeOfferUpgraded();
      case 'declined':
        return const UpgradeOfferDeclined();
      case 'dismissed':
      default:
        return const UpgradeOfferDismissed();
    }
  }
}

/// The user accepted the upgrade offer and was upgraded.
class UpgradeOfferUpgraded extends UpgradeOfferResult {
  const UpgradeOfferUpgraded();
}

/// The user explicitly declined the upgrade offer.
class UpgradeOfferDeclined extends UpgradeOfferResult {
  const UpgradeOfferDeclined();
}

/// The user dismissed the sheet without completing the flow.
class UpgradeOfferDismissed extends UpgradeOfferResult {
  const UpgradeOfferDismissed();
}

/// Payload submitted to the backend after an upgrade offer completes.
class UpgradeOfferResponsePayload {
  final String userId;
  final String currentProductId;
  final String targetProductId;
  final String outcome;
  final String upgradeType;

  /// A/B experiment variant identifier echoed back from the config.
  final int? variantId;

  UpgradeOfferResponsePayload({
    required this.userId,
    required this.currentProductId,
    required this.targetProductId,
    required this.outcome,
    required this.upgradeType,
    this.variantId,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'currentProductId': currentProductId,
      'targetProductId': targetProductId,
      'outcome': outcome,
      'upgradeType': upgradeType,
      if (variantId != null) 'variantId': variantId,
    };
  }
}
