/// Product type for in-app purchases.
enum ZSProductType {
  autoRenewableSubscription('auto_renewable_subscription'),
  nonRenewingSubscription('non_renewing_subscription'),
  consumable('consumable'),
  nonConsumable('non_consumable');

  const ZSProductType(this.rawValue);
  final String rawValue;

  static ZSProductType fromRawValue(String value) {
    return ZSProductType.values.firstWhere(
      (e) => e.rawValue == value,
      orElse: () => throw ArgumentError('Unknown ZSProductType: $value'),
    );
  }
}

/// The origin of a purchase/entitlement.
///
/// A single user can hold entitlements from multiple sources simultaneously
/// (e.g., a StoreKit subscription and a web checkout consumable).
/// [ZeroSettle.showManageSubscription] uses these values to route to the
/// appropriate management UI.
enum EntitlementSource {
  /// Purchased through Apple StoreKit (App Store billing).
  /// On Android, this represents a cross-platform entitlement from an iOS purchase.
  storeKit('store_kit'),

  /// Purchased through Google Play Store billing.
  /// On iOS, this represents a cross-platform entitlement from an Android purchase.
  playStore('play_store'),

  /// Purchased through ZeroSettle's web checkout (Stripe billing).
  webCheckout('web_checkout');

  const EntitlementSource(this.rawValue);
  final String rawValue;

  static EntitlementSource fromRawValue(String value) {
    return EntitlementSource.values.firstWhere(
      (e) => e.rawValue == value,
      orElse: () => throw ArgumentError('Unknown EntitlementSource: $value'),
    );
  }
}

/// The status of a transaction.
enum TransactionStatus {
  completed('completed'),
  pending('pending'),
  processing('processing'),
  failed('failed'),
  refunded('refunded');

  const TransactionStatus(this.rawValue);
  final String rawValue;

  static TransactionStatus fromRawValue(String value) {
    return TransactionStatus.values.firstWhere(
      (e) => e.rawValue == value,
      orElse: () => throw ArgumentError('Unknown TransactionStatus: $value'),
    );
  }
}

/// The type of promotional discount.
enum PromotionType {
  percentOff('percent_off'),
  fixedAmount('fixed_amount'),
  freeTrial('free_trial');

  const PromotionType(this.rawValue);
  final String rawValue;

  static PromotionType fromRawValue(String value) {
    return PromotionType.values.firstWhere(
      (e) => e.rawValue == value,
      orElse: () => throw ArgumentError('Unknown PromotionType: $value'),
    );
  }
}

/// The type of checkout UI to present.
enum CheckoutType {
  webView('webview'),
  safariVC('safari_vc'),
  safari('safari'),
  nativePay('native_pay');

  const CheckoutType(this.rawValue);
  final String rawValue;

  static CheckoutType fromRawValue(String value) {
    return CheckoutType.values.firstWhere(
      (e) => e.rawValue == value,
      orElse: () => throw ArgumentError('Unknown CheckoutType: $value'),
    );
  }
}

/// The user's choice from the save-the-sale retention sheet.
enum ZSSaveTheSaleResult {
  pauseAccount('pauseAccount'),
  stayWithDiscount('stayWithDiscount'),
  dismissed('dismissed');

  const ZSSaveTheSaleResult(this.rawValue);
  final String rawValue;

  static ZSSaveTheSaleResult fromRawValue(String value) {
    return ZSSaveTheSaleResult.values.firstWhere(
      (e) => e.rawValue == value,
      orElse: () => ZSSaveTheSaleResult.dismissed,
    );
  }
}

/// Geographic jurisdiction for checkout configuration.
enum Jurisdiction {
  us('us'),
  eu('eu'),
  row('row');

  const Jurisdiction(this.rawValue);
  final String rawValue;

  static Jurisdiction fromRawValue(String value) {
    return Jurisdiction.values.firstWhere(
      (e) => e.rawValue == value,
      orElse: () => throw ArgumentError('Unknown Jurisdiction: $value'),
    );
  }
}

/// How the SDK reacts when the merchant is Apple-Pay-only and the device's
/// Wallet has no supported card configured ([ApplePayAvailabilityState.setupRequired]).
///
/// Pass to [ZeroSettle.configure] via the `applePaySetupBehavior` parameter.
/// Mirrors the iOS Kit's `ApplePaySetupBehavior` enum.
enum ApplePaySetupBehavior {
  /// SDK opens the system Wallet setup flow automatically when the merchant
  /// is Apple-Pay-only and the device's Wallet has no supported card. The
  /// banner shows a built-in "Set up Apple Pay" CTA inline. Default behavior
  /// on iOS.
  presentBuiltInUI('presentBuiltInUI'),

  /// SDK delegates the setup flow to your app. The banner hides itself on
  /// `setupRequired`; all imperative entry points surface
  /// [ZSApplePaySetupRequiredException] without auto-opening Wallet. Observe
  /// [ZeroSettle.applePayStateUpdates] to drive your own UI, then call
  /// [ZeroSettle.presentApplePaySetup] when ready.
  delegateToApp('delegateToApp');

  const ApplePaySetupBehavior(this.rawValue);
  final String rawValue;

  static ApplePaySetupBehavior fromRawValue(String value) {
    return ApplePaySetupBehavior.values.firstWhere(
      (e) => e.rawValue == value,
      orElse: () => throw ArgumentError('Unknown ApplePaySetupBehavior: $value'),
    );
  }
}

/// Where the backend wants this cohort to check out.
///
/// Driven by a `checkout_routing` experiment on the backend. ORTHOGONAL to
/// [Product.webPrice]: [web] does NOT imply a web price is present — a
/// store-only product (web storefront not opted in) reports [web] with a
/// null `webPrice`. The SDK's `purchase()` already applies the routing rule
/// natively (use web checkout only when route is [web] AND a web price
/// exists; otherwise route to StoreKit/Play); this field is exposed so host
/// apps can read the directive (e.g. to label or pre-flight their own UI).
///
/// Soft-fails to [web] on absent/unknown values — mirrors the native SDKs,
/// which default to `web` when the backend omits the field (older servers)
/// or sends a future value.
enum ZSCheckoutRoute {
  /// Route this cohort through ZeroSettle web checkout (Stripe).
  web('web'),

  /// Route this cohort to the native store (StoreKit / Play Billing).
  store('store');

  const ZSCheckoutRoute(this.rawValue);
  final String rawValue;

  static ZSCheckoutRoute fromRawValue(String? value) {
    if (value == null) return ZSCheckoutRoute.web;
    for (final r in ZSCheckoutRoute.values) {
      if (r.rawValue == value) return r;
    }
    return ZSCheckoutRoute.web;
  }
}

/// The trial billing mode for a subscription product.
enum ZSTrialMode {
  free('free'),
  paid('paid'),
  authHold('auth_hold');

  const ZSTrialMode(this.rawValue);
  final String rawValue;

  static ZSTrialMode? fromRawValueOrNull(String value) {
    for (final m in ZSTrialMode.values) {
      if (m.rawValue == value) return m;
    }
    return null;
  }
}

/// Tri-state Apple Pay availability on the device, observed from the iOS
/// Kit's `ApplePayAvailability` service.
///
/// Raw values match what the iOS Kit's `ApplePayAvailability.State`
/// persists/exchanges so the wire format stays stable across versions.
enum ApplePayAvailabilityState {
  /// Device supports Apple Pay AND user has at least one supported card.
  ready('ready'),

  /// Device supports Apple Pay but Wallet has no supported cards.
  /// Call [ZeroSettle.presentApplePaySetup] to launch the Wallet setup flow.
  setupRequired('setupRequired'),

  /// Device cannot do Apple Pay (older hardware, simulator,
  /// MDM/parental restriction).
  unavailable('unavailable');

  const ApplePayAvailabilityState(this.rawValue);
  final String rawValue;

  static ApplePayAvailabilityState fromRawValue(String value) {
    return ApplePayAvailabilityState.values.firstWhere(
      (e) => e.rawValue == value,
      orElse: () =>
          throw ArgumentError('Unknown ApplePayAvailabilityState: $value'),
    );
  }
}
