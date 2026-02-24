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
