import 'package:flutter/services.dart';

import 'zerosettle_platform_interface.dart';
import 'errors/zs_exception.dart';
import 'models/entitlement.dart';
import 'models/product_catalog.dart';
import 'models/remote_config.dart';
import 'models/enums.dart';
import 'models/zs_product.dart';
import 'models/zs_transaction.dart';
import 'models/cancel_flow.dart';
import 'models/upgrade_offer.dart';

export 'models/price.dart';
export 'models/enums.dart';
export 'models/zs_product.dart';
export 'models/entitlement.dart';
export 'models/zs_transaction.dart';
export 'models/promotion.dart';
export 'models/product_catalog.dart';
export 'models/remote_config.dart';
export 'errors/zs_exception.dart';
export 'widgets/zs_migrate_tip_view.dart';
export 'models/cancel_flow.dart';
export 'models/upgrade_offer.dart';

/// Main entry point for the ZeroSettle Flutter SDK.
///
/// Use [ZeroSettle.instance] to access the singleton. Call [configure] before
/// any other methods.
///
/// ```dart
/// await ZeroSettle.instance.configure(publishableKey: 'zs_pk_live_...');
/// final catalog = await ZeroSettle.instance.bootstrap(userId: 'user_123');
/// ```
class ZeroSettle {
  ZeroSettle._();

  static final ZeroSettle instance = ZeroSettle._();

  ZeroSettlePlatform get _platform => ZeroSettlePlatform.instance;

  // -- Configuration --

  /// Override the backend base URL for local development.
  /// Set before calling [configure]. Pass `null` to clear.
  Future<void> setBaseUrlOverride(String? url) {
    return _wrap(() => _platform.setBaseUrlOverride(url));
  }

  /// Configure the SDK with your publishable key.
  /// Must be called before any other methods.
  Future<void> configure({
    required String publishableKey,
    bool syncStoreKitTransactions = true,
  }) {
    return _wrap(() => _platform.configure(
          publishableKey: publishableKey,
          syncStoreKitTransactions: syncStoreKitTransactions,
        ));
  }

  // -- Bootstrap --

  /// Fetch products and restore entitlements.
  ///
  /// Convenience method equivalent to calling [fetchProducts] and
  /// [restoreEntitlements] in sequence.
  ///
  /// - [userId]: Your app's user identifier
  Future<ProductCatalog> bootstrap({required String userId}) {
    return _wrap(() async {
      final map = await _platform.bootstrap(userId: userId);
      return ProductCatalog.fromMap(map);
    });
  }

  // -- Products --

  /// Fetch the product catalog from ZeroSettle.
  Future<ProductCatalog> fetchProducts({String? userId}) {
    return _wrap(() async {
      final map = await _platform.fetchProducts(userId: userId);
      return ProductCatalog.fromMap(map);
    });
  }

  /// Get the cached products from the last fetch.
  Future<List<Product>> getProducts() {
    return _wrap(() async {
      final list = await _platform.getProducts();
      return list.map((e) => Product.fromMap(e)).toList();
    });
  }

  // -- Payment Sheet --

  /// Present the payment sheet for a product.
  ///
  /// Returns a [CheckoutTransaction] on successful payment.
  /// Throws [ZSCancelledException] if the user dismisses the sheet.
  /// Throws [ZSCheckoutFailedException] if the payment fails.
  ///
  /// - [productId]: The product to purchase
  /// - [userId]: Optional user identifier
  /// - [freeTrialDays]: Number of free trial days to grant on web billing subscriptions (defaults to 0)
  /// - [dismissible]: Whether the sheet can be dismissed by the user
  Future<CheckoutTransaction> presentPaymentSheet({
    required String productId,
    String? userId,
    int freeTrialDays = 0,
    bool dismissible = true,
  }) {
    return _wrap(() async {
      final map = await _platform.presentPaymentSheet(
        productId: productId,
        userId: userId,
        freeTrialDays: freeTrialDays,
        dismissible: dismissible,
      );
      return CheckoutTransaction.fromMap(map);
    });
  }

  /// Preload the payment sheet for faster presentation.
  ///
  /// - [productId]: The product to preload
  /// - [userId]: Optional user identifier
  /// - [freeTrialDays]: Number of free trial days to grant on web billing subscriptions (defaults to 0)
  Future<void> preloadPaymentSheet({required String productId, String? userId, int freeTrialDays = 0}) {
    return _wrap(() => _platform.preloadPaymentSheet(
          productId: productId,
          userId: userId,
          freeTrialDays: freeTrialDays,
        ));
  }

  /// Warm up the payment sheet (preload + cache).
  ///
  /// - [productId]: The product to warm up
  /// - [userId]: Optional user identifier
  /// - [freeTrialDays]: Number of free trial days to grant on web billing subscriptions (defaults to 0)
  Future<void> warmUpPaymentSheet({required String productId, String? userId, int freeTrialDays = 0}) {
    return _wrap(() => _platform.warmUpPaymentSheet(
          productId: productId,
          userId: userId,
          freeTrialDays: freeTrialDays,
        ));
  }

  // -- Entitlements --

  /// Restore entitlements from both web checkout and StoreKit.
  Future<List<Entitlement>> restoreEntitlements({required String userId}) {
    return _wrap(() async {
      final list = await _platform.restoreEntitlements(userId: userId);
      return list.map((e) => Entitlement.fromMap(e)).toList();
    });
  }

  /// Get the current cached entitlements.
  Future<List<Entitlement>> getEntitlements() {
    return _wrap(() async {
      final list = await _platform.getEntitlements();
      return list.map((e) => Entitlement.fromMap(e)).toList();
    });
  }

  /// Stream of entitlement updates from the native SDK.
  Stream<List<Entitlement>> get entitlementUpdates {
    return _platform.entitlementUpdates.map(
      (list) => list.map((e) => Entitlement.fromMap(e)).toList(),
    );
  }

  // -- Subscription Management --

  /// Open the Stripe customer portal for subscription management.
  Future<void> openCustomerPortal({required String userId}) {
    return _wrap(() => _platform.openCustomerPortal(userId: userId));
  }

  /// Smart subscription management -- routes to Stripe portal or Apple's
  /// native management UI based on entitlement sources.
  Future<void> showManageSubscription({required String userId}) {
    return _wrap(() => _platform.showManageSubscription(userId: userId));
  }

  // -- Universal Links --

  /// Handle a universal link callback from web checkout.
  /// Returns `true` if the URL was handled by ZeroSettle.
  Future<bool> handleUniversalLink(String url) {
    return _wrap(() => _platform.handleUniversalLink(url));
  }

  // -- State Queries --

  /// Whether the SDK has been configured.
  Future<bool> getIsConfigured() {
    return _wrap(() => _platform.getIsConfigured());
  }

  /// Whether a checkout is currently in progress.
  Future<bool> getPendingCheckout() {
    return _wrap(() => _platform.getPendingCheckout());
  }

  /// Get the remote configuration from the last fetch.
  Future<RemoteConfig?> getRemoteConfig() {
    return _wrap(() async {
      final map = await _platform.getRemoteConfig();
      return map != null ? RemoteConfig.fromMap(map) : null;
    });
  }

  /// Get the detected jurisdiction.
  Future<Jurisdiction?> getDetectedJurisdiction() {
    return _wrap(() async {
      final raw = await _platform.getDetectedJurisdiction();
      return raw != null ? Jurisdiction.fromRawValue(raw) : null;
    });
  }

  // -- Cancel Flow --

  /// Present the cancel flow questionnaire for a subscription cancellation.
  ///
  /// Fetches the cancel flow configuration from the backend via the native
  /// SDK, then presents a native questionnaire sheet. If the flow is disabled
  /// or has no questions, returns [CancelFlowCancelled] immediately.
  ///
  /// - [productId]: The product the user wants to cancel
  /// - [userId]: Your app's user identifier
  Future<CancelFlowResult> presentCancelFlow({
    required String productId,
    required String userId,
  }) {
    return _wrap(() async {
      final resultString = await _platform.presentCancelFlow(
        productId: productId,
        userId: userId,
      );
      return CancelFlowResult.fromRawValue(resultString);
    });
  }

  /// Fetch the cancel flow configuration without presenting any UI.
  ///
  /// Use this for headless/custom cancel flow implementations.
  Future<CancelFlowConfig> fetchCancelFlowConfig() {
    return _wrap(() async {
      final map = await _platform.fetchCancelFlowConfig();
      return CancelFlowConfig.fromMap(map);
    });
  }

  /// Pause a subscription for the given user.
  ///
  /// Returns the resume date as a [DateTime] if the backend provides one,
  /// or `null` if no specific resume date was set.
  ///
  /// - [productId]: The product to pause
  /// - [userId]: Your app's user identifier
  /// - [pauseOptionId]: The ID of the selected pause option
  Future<DateTime?> pauseSubscription({
    required String productId,
    required String userId,
    required int pauseOptionId,
  }) {
    return _wrap(() async {
      final iso = await _platform.pauseSubscription(
        productId: productId,
        userId: userId,
        pauseOptionId: pauseOptionId,
      );
      return iso != null ? DateTime.parse(iso) : null;
    });
  }

  /// Resume a paused subscription for the given user.
  ///
  /// - [productId]: The product to resume
  /// - [userId]: Your app's user identifier
  Future<void> resumeSubscription({
    required String productId,
    required String userId,
  }) {
    return _wrap(() => _platform.resumeSubscription(
          productId: productId,
          userId: userId,
        ));
  }

  // -- Cancel Flow (Headless) --

  /// Accept the save offer for a subscription about to be cancelled.
  ///
  /// Returns a [CancelFlowSaveOfferResult] with the discount details.
  ///
  /// - [productId]: The product the offer applies to
  /// - [userId]: Your app's user identifier
  Future<CancelFlowSaveOfferResult> acceptSaveOffer({
    required String productId,
    required String userId,
  }) {
    return _wrap(() async {
      final map = await _platform.acceptSaveOffer(
        productId: productId,
        userId: userId,
      );
      return CancelFlowSaveOfferResult.fromMap(map);
    });
  }

  /// Submit the complete cancel flow response for analytics and processing.
  ///
  /// - [response]: The cancel flow response containing answers and outcome
  Future<void> submitCancelFlowResponse(CancelFlowResponse response) {
    return _wrap(() => _platform.submitCancelFlowResponse(response.toMap()));
  }

  /// Get the cancel flow configuration from the cached config.
  ///
  /// Returns `null` if no config is available.
  Future<CancelFlowConfig?> getCancelFlowConfig() {
    return _wrap(() async {
      final map = await _platform.getCancelFlowConfig();
      return map != null ? CancelFlowConfig.fromMap(map) : null;
    });
  }

  /// Cancel a subscription immediately or at end of period.
  ///
  /// - [productId]: The product to cancel
  /// - [userId]: Your app's user identifier
  /// - [immediate]: Whether to cancel immediately (default: false, cancels at period end)
  Future<void> cancelSubscription({
    required String productId,
    required String userId,
    bool immediate = false,
  }) {
    return _wrap(() => _platform.cancelSubscription(
          productId: productId,
          userId: userId,
          immediate: immediate,
        ));
  }

  // -- Upgrade Offer --

  /// Present the upgrade offer sheet for a subscription upgrade.
  ///
  /// Fetches the upgrade offer configuration from the backend via the native
  /// SDK, then presents a native upgrade sheet. If no upgrade is available,
  /// returns [UpgradeOfferDismissed] immediately.
  ///
  /// - [productId]: The current product the user holds
  /// - [userId]: Your app's user identifier
  Future<UpgradeOfferResult> presentUpgradeOffer({
    required String productId,
    required String userId,
  }) {
    return _wrap(() async {
      final resultString = await _platform.presentUpgradeOffer(
        productId: productId,
        userId: userId,
      );
      return UpgradeOfferResult.fromRawValue(resultString);
    });
  }

  /// Fetch the upgrade offer configuration without presenting any UI.
  ///
  /// Use this for headless/custom upgrade offer implementations.
  ///
  /// - [productId]: The current product to check upgrades for
  /// - [userId]: Your app's user identifier
  Future<UpgradeOfferConfig> fetchUpgradeOfferConfig({
    required String productId,
    required String userId,
  }) {
    return _wrap(() async {
      final map = await _platform.fetchUpgradeOfferConfig(
        productId: productId,
        userId: userId,
      );
      return UpgradeOfferConfig.fromMap(map);
    });
  }


  // -- Checkout Events --

  /// Stream of checkout lifecycle events from the native SDK.
  Stream<Map<String, dynamic>> get checkoutEvents {
    return _platform.checkoutEvents;
  }

  // -- Save the Sale --

  /// Present the save-the-sale retention sheet.
  ///
  /// Shows two options: Pause Account and Stay & Save 40%.
  /// Returns the user's choice as a [ZSSaveTheSaleResult].
  Future<ZSSaveTheSaleResult> presentSaveTheSaleSheet() {
    return _wrap(() async {
      final raw = await _platform.presentSaveTheSaleSheet();
      return ZSSaveTheSaleResult.fromRawValue(raw);
    });
  }

  // -- Error wrapping --

  Future<T> _wrap<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on PlatformException catch (e) {
      throw ZeroSettleException.fromPlatformException(e);
    }
  }
}
