import 'package:flutter/services.dart';

import 'zerosettle_platform_interface.dart';
import 'errors/zs_exception.dart';
import 'models/entitlement.dart';
import 'models/product_catalog.dart';
import 'models/remote_config.dart';
import 'models/enums.dart';
import 'models/zs_product.dart';
import 'models/zs_transaction.dart';

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

  /// Fetch products, warm up the payment sheet, and restore entitlements.
  ///
  /// Convenience method equivalent to calling [fetchProducts], warming up,
  /// and [restoreEntitlements] in sequence.
  ///
  /// - [userId]: Your app's user identifier
  /// - [freeTrialDays]: Number of free trial days to grant on web billing subscriptions
  Future<ProductCatalog> bootstrap({required String userId, required int freeTrialDays}) {
    return _wrap(() async {
      final map = await _platform.bootstrap(userId: userId, freeTrialDays: freeTrialDays);
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
  Future<List<ZSProduct>> getProducts() {
    return _wrap(() async {
      final list = await _platform.getProducts();
      return list.map((e) => ZSProduct.fromMap(e)).toList();
    });
  }

  // -- Payment Sheet --

  /// Present the payment sheet for a product.
  ///
  /// Returns a [ZSTransaction] on successful payment.
  /// Throws [ZSCancelledException] if the user dismisses the sheet.
  /// Throws [ZSCheckoutFailedException] if the payment fails.
  ///
  /// - [productId]: The product to purchase
  /// - [userId]: Optional user identifier
  /// - [freeTrialDays]: Number of free trial days to grant on web billing subscriptions
  /// - [dismissible]: Whether the sheet can be dismissed by the user
  Future<ZSTransaction> presentPaymentSheet({
    required String productId,
    String? userId,
    required int freeTrialDays,
    bool dismissible = true,
  }) {
    return _wrap(() async {
      final map = await _platform.presentPaymentSheet(
        productId: productId,
        userId: userId,
        freeTrialDays: freeTrialDays,
        dismissible: dismissible,
      );
      return ZSTransaction.fromMap(map);
    });
  }

  /// Preload the payment sheet for faster presentation.
  ///
  /// - [productId]: The product to preload
  /// - [userId]: Optional user identifier
  /// - [freeTrialDays]: Number of free trial days to grant on web billing subscriptions
  Future<void> preloadPaymentSheet({required String productId, String? userId, required int freeTrialDays}) {
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
  /// - [freeTrialDays]: Number of free trial days to grant on web billing subscriptions
  Future<void> warmUpPaymentSheet({required String productId, String? userId, required int freeTrialDays}) {
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

  /// Smart subscription management — routes to Stripe portal or Apple's
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

  // -- Checkout Events --

  /// Stream of checkout lifecycle events from the native SDK.
  Stream<Map<String, dynamic>> get checkoutEvents {
    return _platform.checkoutEvents;
  }

  // -- Error wrapping --

  Future<T> _wrap<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on PlatformException catch (e) {
      throw ZSException.fromPlatformException(e);
    }
  }
}
