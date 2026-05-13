/// Models bridging ZeroSettleKit's `Offer` namespace
/// (`Sources/ZeroSettleKit/Models/Offer.swift`).
///
/// `Offer` on iOS is a public enum used purely as a namespace for the
/// nested types: `FlowType`, `UpgradeType`, `CheckoutPresentation`,
/// `State`, `Display`, `PerProductOffer`, and `OfferData`. Dart names
/// keep the `Offer` prefix to mirror that nesting (e.g. `OfferFlowType`,
/// `OfferDisplay`), EXCEPT `OfferData` itself — the doubled-prefix form
/// (`OfferOfferData`) was too awkward to live with, so the bare
/// `OfferData` name was chosen instead. Same field-for-field shape as
/// Swift's `Offer.OfferData`.
library;

/// The type of offer flow, determined by the server. Mirrors
/// `Offer.FlowType`.
enum OfferFlowType {
  migration('migration'),
  upgrade('upgrade');

  const OfferFlowType(this.rawValue);
  final String rawValue;

  static OfferFlowType fromRawValue(String value) {
    return OfferFlowType.values.firstWhere(
      (e) => e.rawValue == value,
      orElse: () => OfferFlowType.migration,
    );
  }
}

/// The upgrade-path type (only relevant for upgrade flows). Mirrors
/// `Offer.UpgradeType`.
enum OfferUpgradeType {
  storekitToWeb('storekit_to_web'),
  webToWeb('web_to_web');

  const OfferUpgradeType(this.rawValue);
  final String rawValue;

  static OfferUpgradeType fromRawValue(String value) {
    return OfferUpgradeType.values.firstWhere(
      (e) => e.rawValue == value,
      orElse: () => OfferUpgradeType.storekitToWeb,
    );
  }
}

/// How the tip view presents checkout when the CTA is tapped. Mirrors
/// `Offer.CheckoutPresentation`. When `null`, the SDK uses the global
/// `checkoutType` setting.
enum OfferCheckoutPresentation {
  /// Expand checkout inline within the tip card.
  inline('inline'),

  /// Present the bottom checkout sheet overlay.
  sheet('sheet'),

  /// Open an in-app browser (SFSafariViewController).
  safariVC('safari_vc'),

  /// Open external Safari.
  safari('safari');

  const OfferCheckoutPresentation(this.rawValue);
  final String rawValue;

  static OfferCheckoutPresentation fromRawValue(String value) {
    return OfferCheckoutPresentation.values.firstWhere(
      (e) => e.rawValue == value,
      orElse: () => OfferCheckoutPresentation.inline,
    );
  }
}

/// Lifecycle state of the offer flow. Mirrors `Offer.State`.
enum OfferState {
  loading('loading'),
  ineligible('ineligible'),
  eligible('eligible'),
  presented('presented'),
  accepted('accepted'),
  completed('completed'),
  dismissed('dismissed');

  const OfferState(this.rawValue);
  final String rawValue;

  static OfferState fromRawValue(String value) {
    return OfferState.values.firstWhere(
      (e) => e.rawValue == value,
      orElse: () => OfferState.loading,
    );
  }
}

/// Server-configurable display copy for every tip-card state. Empty
/// strings mean "use SDK default". Mirrors `Offer.Display`.
class OfferDisplay {
  final String offerTitle;
  final String offerMessage;
  final String offerCta;
  final String acceptedTitle;
  final String acceptedMessage;
  final String acceptedCta;
  final String completedTitle;
  final String completedMessage;

  const OfferDisplay({
    required this.offerTitle,
    required this.offerMessage,
    required this.offerCta,
    required this.acceptedTitle,
    required this.acceptedMessage,
    required this.acceptedCta,
    required this.completedTitle,
    required this.completedMessage,
  });

  factory OfferDisplay.fromMap(Map<String, dynamic> map) {
    return OfferDisplay(
      offerTitle: map['offerTitle'] as String? ?? '',
      offerMessage: map['offerMessage'] as String? ?? '',
      offerCta: map['offerCta'] as String? ?? '',
      acceptedTitle: map['acceptedTitle'] as String? ?? '',
      acceptedMessage: map['acceptedMessage'] as String? ?? '',
      acceptedCta: map['acceptedCta'] as String? ?? '',
      completedTitle: map['completedTitle'] as String? ?? '',
      completedMessage: map['completedMessage'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'offerTitle': offerTitle,
        'offerMessage': offerMessage,
        'offerCta': offerCta,
        'acceptedTitle': acceptedTitle,
        'acceptedMessage': acceptedMessage,
        'acceptedCta': acceptedCta,
        'completedTitle': completedTitle,
        'completedMessage': completedMessage,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfferDisplay &&
          offerTitle == other.offerTitle &&
          offerMessage == other.offerMessage &&
          offerCta == other.offerCta &&
          acceptedTitle == other.acceptedTitle &&
          acceptedMessage == other.acceptedMessage &&
          acceptedCta == other.acceptedCta &&
          completedTitle == other.completedTitle &&
          completedMessage == other.completedMessage;

  @override
  int get hashCode => Object.hash(
        offerTitle,
        offerMessage,
        offerCta,
        acceptedTitle,
        acceptedMessage,
        acceptedCta,
        completedTitle,
        completedMessage,
      );
}

/// Per-product offer override. Mirrors `Offer.PerProductOffer`.
class OfferPerProductOffer {
  final String productId;
  final int savingsPercent;
  final OfferDisplay display;

  const OfferPerProductOffer({
    required this.productId,
    required this.savingsPercent,
    required this.display,
  });

  factory OfferPerProductOffer.fromMap(Map<String, dynamic> map) {
    return OfferPerProductOffer(
      productId: map['productId'] as String,
      savingsPercent: map['savingsPercent'] as int? ?? 0,
      display: OfferDisplay.fromMap(
        Map<String, dynamic>.from(map['display'] as Map),
      ),
    );
  }

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'savingsPercent': savingsPercent,
        'display': display.toMap(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfferPerProductOffer &&
          productId == other.productId &&
          savingsPercent == other.savingsPercent &&
          display == other.display;

  @override
  int get hashCode => Object.hash(productId, savingsPercent, display);
}

/// Server-resolved offer payload. Mirrors `Offer.OfferData`.
///
/// The Dart class name keeps the `Offer` prefix to mirror Swift's
/// nested `Offer.OfferData` namespacing.
class OfferData {
  final OfferFlowType flowType;
  final String productId;
  final List<String> eligibleProductIds;
  final int savingsPercent;
  final OfferDisplay display;

  // Migration-specific
  final int freeTrialDays;
  final int minSubscriptionDays;
  final int? maxSubscriptionDays;
  final int? rolloutPercent;

  // Upgrade-specific
  final OfferUpgradeType? upgradeType;
  final String? fromProductId;
  final String? toProductId;

  // Experiment
  final int? variantId;

  // Per-product overrides (keyed by productId)
  final Map<String, OfferPerProductOffer>? perProductPrompts;

  // Checkout presentation mode (nil = use global checkoutType)
  final OfferCheckoutPresentation? checkoutPresentation;

  const OfferData({
    required this.flowType,
    required this.productId,
    required this.eligibleProductIds,
    required this.savingsPercent,
    required this.display,
    required this.freeTrialDays,
    required this.minSubscriptionDays,
    this.maxSubscriptionDays,
    this.rolloutPercent,
    this.upgradeType,
    this.fromProductId,
    this.toProductId,
    this.variantId,
    this.perProductPrompts,
    this.checkoutPresentation,
  });

  factory OfferData.fromMap(Map<String, dynamic> map) {
    final rawPerProduct = map['perProductPrompts'];
    Map<String, OfferPerProductOffer>? perProduct;
    if (rawPerProduct is Map) {
      perProduct = rawPerProduct.map(
        (key, value) => MapEntry(
          key as String,
          OfferPerProductOffer.fromMap(
            Map<String, dynamic>.from(value as Map),
          ),
        ),
      );
    }

    return OfferData(
      flowType: OfferFlowType.fromRawValue(map['flowType'] as String),
      productId: map['productId'] as String,
      eligibleProductIds: (map['eligibleProductIds'] as List?)
              ?.map((e) => e as String)
              .toList() ??
          <String>[],
      savingsPercent: map['savingsPercent'] as int? ?? 0,
      display: OfferDisplay.fromMap(
        Map<String, dynamic>.from(map['display'] as Map),
      ),
      freeTrialDays: map['freeTrialDays'] as int? ?? 0,
      minSubscriptionDays: map['minSubscriptionDays'] as int? ?? 0,
      maxSubscriptionDays: map['maxSubscriptionDays'] as int?,
      rolloutPercent: map['rolloutPercent'] as int?,
      upgradeType: map['upgradeType'] != null
          ? OfferUpgradeType.fromRawValue(map['upgradeType'] as String)
          : null,
      fromProductId: map['fromProductId'] as String?,
      toProductId: map['toProductId'] as String?,
      variantId: map['variantId'] as int?,
      perProductPrompts: perProduct,
      checkoutPresentation: map['checkoutPresentation'] != null
          ? OfferCheckoutPresentation.fromRawValue(
              map['checkoutPresentation'] as String,
            )
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'flowType': flowType.rawValue,
        'productId': productId,
        'eligibleProductIds': eligibleProductIds,
        'savingsPercent': savingsPercent,
        'display': display.toMap(),
        'freeTrialDays': freeTrialDays,
        'minSubscriptionDays': minSubscriptionDays,
        if (maxSubscriptionDays != null)
          'maxSubscriptionDays': maxSubscriptionDays,
        if (rolloutPercent != null) 'rolloutPercent': rolloutPercent,
        if (upgradeType != null) 'upgradeType': upgradeType!.rawValue,
        if (fromProductId != null) 'fromProductId': fromProductId,
        if (toProductId != null) 'toProductId': toProductId,
        if (variantId != null) 'variantId': variantId,
        if (perProductPrompts != null)
          'perProductPrompts':
              perProductPrompts!.map((k, v) => MapEntry(k, v.toMap())),
        if (checkoutPresentation != null)
          'checkoutPresentation': checkoutPresentation!.rawValue,
      };

  /// Whether this offer requires Apple subscription cancellation
  /// post-checkout. Mirrors `Offer.OfferData.needsAppleCancel`.
  bool get needsAppleCancel {
    switch (flowType) {
      case OfferFlowType.migration:
        return true;
      case OfferFlowType.upgrade:
        return upgradeType == OfferUpgradeType.storekitToWeb;
    }
  }

  /// The target product ID for checkout (`toProductId` for upgrades,
  /// `productId` for migration). Mirrors
  /// `Offer.OfferData.checkoutProductId`.
  String get checkoutProductId => toProductId ?? productId;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! OfferData) return false;
    if (flowType != other.flowType) return false;
    if (productId != other.productId) return false;
    if (savingsPercent != other.savingsPercent) return false;
    if (display != other.display) return false;
    if (freeTrialDays != other.freeTrialDays) return false;
    if (minSubscriptionDays != other.minSubscriptionDays) return false;
    if (maxSubscriptionDays != other.maxSubscriptionDays) return false;
    if (rolloutPercent != other.rolloutPercent) return false;
    if (upgradeType != other.upgradeType) return false;
    if (fromProductId != other.fromProductId) return false;
    if (toProductId != other.toProductId) return false;
    if (variantId != other.variantId) return false;
    if (checkoutPresentation != other.checkoutPresentation) return false;
    if (eligibleProductIds.length != other.eligibleProductIds.length) {
      return false;
    }
    for (var i = 0; i < eligibleProductIds.length; i++) {
      if (eligibleProductIds[i] != other.eligibleProductIds[i]) return false;
    }
    if (perProductPrompts == null) {
      if (other.perProductPrompts != null) return false;
    } else {
      final a = perProductPrompts!;
      final b = other.perProductPrompts;
      if (b == null) return false;
      if (a.length != b.length) return false;
      for (final entry in a.entries) {
        if (b[entry.key] != entry.value) return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        flowType,
        productId,
        Object.hashAll(eligibleProductIds),
        savingsPercent,
        display,
        freeTrialDays,
        minSubscriptionDays,
        maxSubscriptionDays,
        rolloutPercent,
        upgradeType,
        fromProductId,
        toProductId,
        variantId,
        // Hash on length only — Map order is not stable. Equality above
        // compares every entry so this is safe for hash-set membership.
        perProductPrompts?.length ?? 0,
        checkoutPresentation,
      );
}

/// Coherent snapshot of `ZSOfferManager`'s 5 published properties.
/// Emitted on every state-property change via the manager's stream.
class OfferManagerState {
  final OfferState state;
  final OfferData? offerData;
  final String? checkoutErrorMessage;
  final bool isLoading;
  final bool storekitCancelRequired;

  const OfferManagerState({
    required this.state,
    this.offerData,
    this.checkoutErrorMessage,
    required this.isLoading,
    required this.storekitCancelRequired,
  });

  factory OfferManagerState.fromMap(Map<String, dynamic> map) {
    return OfferManagerState(
      state: OfferState.fromRawValue(map['state'] as String),
      offerData: map['offerData'] != null
          ? OfferData.fromMap(
              Map<String, dynamic>.from(map['offerData'] as Map),
            )
          : null,
      checkoutErrorMessage: map['checkoutErrorMessage'] as String?,
      isLoading: map['isLoading'] as bool,
      storekitCancelRequired: map['storekitCancelRequired'] as bool,
    );
  }

  Map<String, dynamic> toMap() => {
        'state': state.rawValue,
        if (offerData != null) 'offerData': offerData!.toMap(),
        if (checkoutErrorMessage != null)
          'checkoutErrorMessage': checkoutErrorMessage,
        'isLoading': isLoading,
        'storekitCancelRequired': storekitCancelRequired,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfferManagerState &&
          state == other.state &&
          offerData == other.offerData &&
          checkoutErrorMessage == other.checkoutErrorMessage &&
          isLoading == other.isLoading &&
          storekitCancelRequired == other.storekitCancelRequired;

  @override
  int get hashCode => Object.hash(
        state,
        offerData,
        checkoutErrorMessage,
        isLoading,
        storekitCancelRequired,
      );
}
