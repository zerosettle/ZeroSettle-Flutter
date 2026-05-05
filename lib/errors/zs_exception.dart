import 'package:flutter/services.dart';

/// Base exception type for the ZeroSettle SDK.
sealed class ZeroSettleException implements Exception {
  final String message;
  const ZeroSettleException(this.message);

  @override
  String toString() => '$runtimeType: $message';

  /// Maps a [PlatformException] from the native bridge to a typed [ZeroSettleException].
  static ZeroSettleException fromPlatformException(PlatformException e) {
    return switch (e.code) {
      'not_configured' => ZSNotConfiguredException(e.message ?? 'SDK not configured'),
      'cancelled' => ZSCancelledException(e.message ?? 'User cancelled'),
      'product_not_found' => ZSProductNotFoundException(e.message ?? 'Product not found'),
      'checkout_failed' => ZSCheckoutFailedException(e.message ?? 'Checkout failed'),
      'api_error' => ZSApiException(e.message ?? 'API error'),
      'user_id_required' => ZSUserIdRequiredException(e.message ?? 'User ID required'),
      'web_checkout_disabled' => ZSWebCheckoutDisabledException(e.message ?? 'Web checkout disabled'),
      'checkout_not_started' => ZSCheckoutNotStartedException(e.message ?? 'Checkout not started'),
      'invalid_publishable_key' => ZSInvalidPublishableKeyException(e.message ?? 'Invalid publishable key'),
      'checkout_config_expired' => ZSCheckoutConfigExpiredException(e.message ?? 'Checkout config expired'),
      'transaction_verification_failed' => ZSTransactionVerificationFailedException(e.message ?? 'Transaction verification failed'),
      'purchase_pending' => ZSPurchasePendingException(e.message ?? 'Purchase pending'),
      'user_not_identified' => ZSUserNotIdentifiedException(e.message ?? 'User not identified'),
      _ => ZSApiException(e.message ?? 'Unknown error: ${e.code}'),
    };
  }
}

/// The SDK has not been configured. Call [ZeroSettle.configure] first.
class ZSNotConfiguredException extends ZeroSettleException {
  const ZSNotConfiguredException(super.message);
}

/// The user cancelled the checkout flow.
class ZSCancelledException extends ZeroSettleException {
  const ZSCancelledException(super.message);
}

/// No product found with the given identifier.
class ZSProductNotFoundException extends ZeroSettleException {
  const ZSProductNotFoundException(super.message);
}

/// The checkout flow failed.
class ZSCheckoutFailedException extends ZeroSettleException {
  const ZSCheckoutFailedException(super.message);
}

/// An API or network error occurred.
class ZSApiException extends ZeroSettleException {
  const ZSApiException(super.message);
}

/// A userId is required for this product type.
class ZSUserIdRequiredException extends ZeroSettleException {
  const ZSUserIdRequiredException(super.message);
}

/// Web checkout is disabled for the user's jurisdiction.
class ZSWebCheckoutDisabledException extends ZeroSettleException {
  const ZSWebCheckoutDisabledException(super.message);
}

/// Checkout could not start (e.g. backend failed to create the payment intent).
/// Distinct from terminal errors that occur after checkout is in flight.
class ZSCheckoutNotStartedException extends ZeroSettleException {
  const ZSCheckoutNotStartedException(super.message);
}

/// The publishable key format is invalid. Check your ZeroSettle dashboard.
class ZSInvalidPublishableKeyException extends ZeroSettleException {
  const ZSInvalidPublishableKeyException(super.message);
}

/// The deferred-mode checkout config expired (the server-side PENDING
/// transaction's `checkout_config_expires_at` has passed). Re-initiate
/// checkout to obtain a fresh session rather than retrying finalize.
class ZSCheckoutConfigExpiredException extends ZeroSettleException {
  const ZSCheckoutConfigExpiredException(super.message);
}

/// Transaction verification failed after checkout (e.g., signature or
/// JWS validation rejected by the backend or by Apple).
class ZSTransactionVerificationFailedException extends ZeroSettleException {
  const ZSTransactionVerificationFailedException(super.message);
}

/// The purchase is pending approval (e.g., StoreKit Ask to Buy). The
/// user has not been charged; the SDK will surface a follow-up event
/// when the purchase resolves.
class ZSPurchasePendingException extends ZeroSettleException {
  const ZSPurchasePendingException(super.message);
}

/// A user-scoped method was called before [ZeroSettle.identify]. Call
/// [ZeroSettle.identify] with [Identity.user] (or [Identity.anonymous])
/// at app launch (after [ZeroSettle.configure]) before invoking
/// user-scoped APIs like [ZeroSettle.restoreEntitlements].
class ZSUserNotIdentifiedException extends ZeroSettleException {
  const ZSUserNotIdentifiedException(super.message);
}

/// Backward-compatible typedef. Use [ZeroSettleException] instead.
@Deprecated('Use ZeroSettleException instead')
typedef ZSException = ZeroSettleException;
