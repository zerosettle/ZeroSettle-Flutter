import 'package:flutter/services.dart';

/// Base exception type for the ZeroSettle SDK.
sealed class ZSException implements Exception {
  final String message;
  const ZSException(this.message);

  @override
  String toString() => '$runtimeType: $message';

  /// Maps a [PlatformException] from the native bridge to a typed [ZSException].
  static ZSException fromPlatformException(PlatformException e) {
    return switch (e.code) {
      'not_configured' => ZSNotConfiguredException(e.message ?? 'SDK not configured'),
      'cancelled' => ZSCancelledException(e.message ?? 'User cancelled'),
      'product_not_found' => ZSProductNotFoundException(e.message ?? 'Product not found'),
      'checkout_failed' => ZSCheckoutFailedException(e.message ?? 'Checkout failed'),
      'api_error' => ZSApiException(e.message ?? 'API error'),
      'user_id_required' => ZSUserIdRequiredException(e.message ?? 'User ID required'),
      'web_checkout_disabled' => ZSWebCheckoutDisabledException(e.message ?? 'Web checkout disabled'),
      _ => ZSApiException(e.message ?? 'Unknown error: ${e.code}'),
    };
  }
}

/// The SDK has not been configured. Call [ZeroSettle.configure] first.
class ZSNotConfiguredException extends ZSException {
  const ZSNotConfiguredException(super.message);
}

/// The user cancelled the checkout flow.
class ZSCancelledException extends ZSException {
  const ZSCancelledException(super.message);
}

/// No product found with the given identifier.
class ZSProductNotFoundException extends ZSException {
  const ZSProductNotFoundException(super.message);
}

/// The checkout flow failed.
class ZSCheckoutFailedException extends ZSException {
  const ZSCheckoutFailedException(super.message);
}

/// An API or network error occurred.
class ZSApiException extends ZSException {
  const ZSApiException(super.message);
}

/// A userId is required for this product type.
class ZSUserIdRequiredException extends ZSException {
  const ZSUserIdRequiredException(super.message);
}

/// Web checkout is disabled for the user's jurisdiction.
class ZSWebCheckoutDisabledException extends ZSException {
  const ZSWebCheckoutDisabledException(super.message);
}
