/// Models for the `fetchUserOffer()` response. Mirrors the Android
/// `UserOffer` namespace from the ZeroSettle Android SDK.
library;

/// The action the offer instructs the SDK to take for the user.
///
/// Mirrors `UserOffer.ActionType` on Android.
enum UserOfferActionType {
  /// No action — the user is ineligible or no offer is configured.
  noAction,

  /// Migrate an active StoreKit subscription to web (Stripe) billing.
  migrateStorekitToWeb,

  /// Migrate an active Google Play subscription to web (Stripe) billing.
  migratePlayToWeb,

  /// Upgrade the user's StoreKit subscription to a higher-tier web plan.
  upgradeStorekitToWeb,

  /// Switch the user from one web subscription to another (web→web upgrade).
  upgradeWebToWeb;

  /// Decode a camelCase wire string. Returns [noAction] on null or unknown
  /// values so callers never need to handle `null` from the server.
  static UserOfferActionType fromWire(String? s) {
    switch (s) {
      case 'migrateStorekitToWeb':
        return UserOfferActionType.migrateStorekitToWeb;
      case 'migratePlayToWeb':
        return UserOfferActionType.migratePlayToWeb;
      case 'upgradeStorekitToWeb':
        return UserOfferActionType.upgradeStorekitToWeb;
      case 'upgradeWebToWeb':
        return UserOfferActionType.upgradeWebToWeb;
      case 'noAction':
      default:
        return UserOfferActionType.noAction;
    }
  }
}

/// The storefront the user's current active subscription originates from.
///
/// Mirrors `UserOffer.SourceStorefront` on Android.
enum UserOfferSourceStorefront {
  /// Apple App Store / StoreKit.
  storeKit,

  /// Google Play Store.
  playStore;

  /// Decode a camelCase wire string. Returns `null` on null or unknown values
  /// since the source field is optional (absent on web-originating offers).
  static UserOfferSourceStorefront? fromWire(String? s) {
    switch (s) {
      case 'storeKit':
        return UserOfferSourceStorefront.storeKit;
      case 'playStore':
        return UserOfferSourceStorefront.playStore;
      default:
        return null;
    }
  }
}

/// Server-configurable display copy for all tip-card states.
///
/// Mirrors `UserOffer.Display` on Android. Empty strings mean "use SDK default".
class UserOfferDisplay {
  /// The primary headline shown on the offer card.
  final String title;

  /// The body copy explaining the offer.
  final String body;

  /// Label for the primary call-to-action button.
  final String ctaText;

  /// Label for the dismiss/decline button.
  final String dismissText;

  /// Headline shown after the user accepts the offer.
  final String acceptedTitle;

  /// Body copy shown after the user accepts the offer.
  final String acceptedBody;

  /// Headline shown after the offer checkout completes.
  final String completedTitle;

  /// Body copy shown after the offer checkout completes.
  final String completedBody;

  /// Instructions for manually cancelling the Apple subscription post-migration.
  final String appleCancelInstructions;

  const UserOfferDisplay({
    required this.title,
    required this.body,
    required this.ctaText,
    required this.dismissText,
    required this.acceptedTitle,
    required this.acceptedBody,
    required this.completedTitle,
    required this.completedBody,
    required this.appleCancelInstructions,
  });

  factory UserOfferDisplay.fromMap(Map<String, dynamic> m) {
    return UserOfferDisplay(
      title: (m['title'] as String?) ?? '',
      body: (m['body'] as String?) ?? '',
      ctaText: (m['ctaText'] as String?) ?? '',
      dismissText: (m['dismissText'] as String?) ?? '',
      acceptedTitle: (m['acceptedTitle'] as String?) ?? '',
      acceptedBody: (m['acceptedBody'] as String?) ?? '',
      completedTitle: (m['completedTitle'] as String?) ?? '',
      completedBody: (m['completedBody'] as String?) ?? '',
      appleCancelInstructions: (m['appleCancelInstructions'] as String?) ?? '',
    );
  }
}

/// Proration details for a web→web or storeKit→web subscription upgrade.
///
/// Mirrors `UserOffer.Proration` on Android.
class UserOfferProration {
  /// The credit amount in the smallest currency unit (e.g. cents for USD).
  final int amountCents;

  /// ISO 4217 currency code (e.g. `"usd"`).
  final String currency;

  /// ISO 8601 date string for the next billing date after the plan switch.
  /// `null` when the backend does not supply a date.
  final String? nextBillingDate;

  const UserOfferProration({
    required this.amountCents,
    required this.currency,
    this.nextBillingDate,
  });

  factory UserOfferProration.fromMap(Map<String, dynamic> m) {
    return UserOfferProration(
      amountCents: (m['amountCents'] as int?) ?? 0,
      currency: (m['currency'] as String?) ?? '',
      nextBillingDate: m['nextBillingDate'] as String?,
    );
  }
}

/// Current Apple subscription state for the user's active StoreKit product.
///
/// Mirrors `UserOffer.AppleSubscription` on Android.
class UserOfferAppleSubscription {
  /// Whether the subscription is currently active.
  final bool isActive;

  /// ISO 8601 expiry date string. `null` if not yet known.
  final String? expiresAt;

  /// Raw App Store status code (see Apple's `Status` enum).
  final int statusCode;

  /// Whether auto-renewal is enabled for the subscription.
  final bool autoRenewEnabled;

  const UserOfferAppleSubscription({
    required this.isActive,
    this.expiresAt,
    required this.statusCode,
    required this.autoRenewEnabled,
  });

  factory UserOfferAppleSubscription.fromMap(Map<String, dynamic> m) {
    return UserOfferAppleSubscription(
      isActive: (m['isActive'] as bool?) ?? false,
      expiresAt: m['expiresAt'] as String?,
      statusCode: (m['statusCode'] as int?) ?? 0,
      autoRenewEnabled: (m['autoRenewEnabled'] as bool?) ?? false,
    );
  }
}

/// Summary of the user's current subscription state.
///
/// Mirrors `UserOffer.Subscription` on Android.
class UserOfferSubscription {
  /// Subscription type descriptor (e.g. `"activeWeb"`, `"activeStorekit"`, `"none"`).
  final String type;

  /// The ZeroSettle product reference ID of the active subscription.
  /// `null` when [type] is `"none"`.
  final String? productId;

  const UserOfferSubscription({
    required this.type,
    this.productId,
  });

  factory UserOfferSubscription.fromMap(Map<String, dynamic> m) {
    return UserOfferSubscription(
      type: (m['type'] as String?) ?? '',
      productId: m['productId'] as String?,
    );
  }
}

/// The server-resolved offer payload for a single user.
///
/// Mirrors `UserOffer.OfferData` on Android. Contains eligibility, the target
/// checkout product, display copy, and optional proration / Apple subscription
/// details.
class UserOfferData {
  /// The action the SDK should take for this user.
  final UserOfferActionType actionType;

  /// Whether the user is currently eligible to receive the offer.
  final bool isEligible;

  /// Product ID to open in the checkout sheet when the CTA is tapped.
  /// `null` when [actionType] is [UserOfferActionType.noAction].
  final String? checkoutProductId;

  /// The user's current product ID being migrated away from (upgrade/migrate flows).
  final String? fromProductId;

  /// Percentage savings displayed in the offer tip.
  final int savingsPercent;

  /// Free-trial days granted by this offer on the new web subscription.
  final int freeTrialDays;

  /// Minimum subscription tenure (days) the user must have to be eligible.
  final int minSubscriptionDays;

  /// Maximum subscription tenure (days) above which the offer is suppressed.
  /// `null` means no upper bound.
  final int? maxSubscriptionDays;

  /// Percentage of eligible users who should receive the offer (A/B rollout).
  final int rolloutPercent;

  /// Server-configurable display copy. `null` means use SDK defaults.
  final UserOfferDisplay? display;

  /// Proration details for upgrade flows. `null` for migration flows.
  final UserOfferProration? proration;

  /// Whether the SDK must prompt the user to cancel their Apple subscription
  /// after checkout completes.
  final bool requiresAppleCancel;

  /// Current Apple subscription state. `null` for non-StoreKit users.
  final UserOfferAppleSubscription? appleSubscription;

  /// Checkout presentation style override (e.g. `"sheet"`, `"inline"`).
  /// `null` means use the global SDK default.
  final String? checkoutPresentation;

  /// A/B experiment variant ID echoed back for analytics. `null` when no
  /// experiment is active.
  final String? experimentVariantId;

  /// The storefront from which the user's active subscription originates.
  /// `null` for web-originated subscriptions or when there is no active sub.
  final UserOfferSourceStorefront? source;

  const UserOfferData({
    required this.actionType,
    required this.isEligible,
    this.checkoutProductId,
    this.fromProductId,
    required this.savingsPercent,
    required this.freeTrialDays,
    required this.minSubscriptionDays,
    this.maxSubscriptionDays,
    required this.rolloutPercent,
    this.display,
    this.proration,
    required this.requiresAppleCancel,
    this.appleSubscription,
    this.checkoutPresentation,
    this.experimentVariantId,
    this.source,
  });

  factory UserOfferData.fromMap(Map<String, dynamic> m) {
    return UserOfferData(
      actionType: UserOfferActionType.fromWire(m['actionType'] as String?),
      isEligible: (m['isEligible'] as bool?) ?? false,
      checkoutProductId: m['checkoutProductId'] as String?,
      fromProductId: m['fromProductId'] as String?,
      savingsPercent: (m['savingsPercent'] as int?) ?? 0,
      freeTrialDays: (m['freeTrialDays'] as int?) ?? 0,
      minSubscriptionDays: (m['minSubscriptionDays'] as int?) ?? 0,
      maxSubscriptionDays: m['maxSubscriptionDays'] as int?,
      rolloutPercent: (m['rolloutPercent'] as int?) ?? 0,
      display: m['display'] != null
          ? UserOfferDisplay.fromMap(Map<String, dynamic>.from(m['display'] as Map))
          : null,
      proration: m['proration'] != null
          ? UserOfferProration.fromMap(Map<String, dynamic>.from(m['proration'] as Map))
          : null,
      requiresAppleCancel: (m['requiresAppleCancel'] as bool?) ?? false,
      appleSubscription: m['appleSubscription'] != null
          ? UserOfferAppleSubscription.fromMap(
              Map<String, dynamic>.from(m['appleSubscription'] as Map))
          : null,
      checkoutPresentation: m['checkoutPresentation'] as String?,
      experimentVariantId: m['experimentVariantId'] as String?,
      source: UserOfferSourceStorefront.fromWire(m['source'] as String?),
    );
  }
}

/// Top-level response from `fetchUserOffer()`.
///
/// Mirrors `UserOfferResponse` on Android. The [isEligible] getter is a
/// convenience accessor that delegates to [offer.isEligible].
class UserOfferResponse {
  /// The ZeroSettle user identifier.
  final String userId;

  /// The app identifier this offer was resolved for.
  final String appId;

  /// Whether the offer was resolved in sandbox mode.
  final bool isSandbox;

  /// The user's current subscription summary.
  final UserOfferSubscription subscription;

  /// The resolved offer data.
  final UserOfferData offer;

  /// ISO 8601 server timestamp when the response was generated.
  final String serverTime;

  const UserOfferResponse({
    required this.userId,
    required this.appId,
    required this.isSandbox,
    required this.subscription,
    required this.offer,
    required this.serverTime,
  });

  factory UserOfferResponse.fromMap(Map<String, dynamic> m) {
    return UserOfferResponse(
      userId: (m['userId'] as String?) ?? '',
      appId: (m['appId'] as String?) ?? '',
      isSandbox: (m['isSandbox'] as bool?) ?? false,
      subscription: UserOfferSubscription.fromMap(
        Map<String, dynamic>.from(m['subscription'] as Map),
      ),
      offer: UserOfferData.fromMap(
        Map<String, dynamic>.from(m['offer'] as Map),
      ),
      serverTime: (m['serverTime'] as String?) ?? '',
    );
  }

  /// Whether the user is eligible for the offer. Convenience accessor that
  /// delegates to [offer.isEligible].
  bool get isEligible => offer.isEligible;
}
