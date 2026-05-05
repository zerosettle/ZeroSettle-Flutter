import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerosettle/errors/zs_exception.dart';

void main() {
  group('ZeroSettleException.fromPlatformException — existing raw codes', () {
    test('not_configured maps to ZSNotConfiguredException', () {
      final e = ZeroSettleException.fromPlatformException(
        PlatformException(code: 'not_configured', message: 'SDK not configured'),
      );
      expect(e, isA<ZSNotConfiguredException>());
      expect(e.message, 'SDK not configured');
    });

    test('cancelled maps to ZSCancelledException', () {
      final e = ZeroSettleException.fromPlatformException(
        PlatformException(code: 'cancelled', message: 'User cancelled'),
      );
      expect(e, isA<ZSCancelledException>());
      expect(e.message, 'User cancelled');
    });

    test('product_not_found maps to ZSProductNotFoundException', () {
      final e = ZeroSettleException.fromPlatformException(
        PlatformException(code: 'product_not_found', message: 'Product not found'),
      );
      expect(e, isA<ZSProductNotFoundException>());
      expect(e.message, 'Product not found');
    });

    test('checkout_failed maps to ZSCheckoutFailedException', () {
      final e = ZeroSettleException.fromPlatformException(
        PlatformException(code: 'checkout_failed', message: 'Checkout failed'),
      );
      expect(e, isA<ZSCheckoutFailedException>());
      expect(e.message, 'Checkout failed');
    });

    test('api_error maps to ZSApiException', () {
      final e = ZeroSettleException.fromPlatformException(
        PlatformException(code: 'api_error', message: 'API error'),
      );
      expect(e, isA<ZSApiException>());
      expect(e.message, 'API error');
    });

    test('user_id_required maps to ZSUserIdRequiredException', () {
      final e = ZeroSettleException.fromPlatformException(
        PlatformException(code: 'user_id_required', message: 'User ID required'),
      );
      expect(e, isA<ZSUserIdRequiredException>());
      expect(e.message, 'User ID required');
    });

    test('web_checkout_disabled maps to ZSWebCheckoutDisabledException', () {
      final e = ZeroSettleException.fromPlatformException(
        PlatformException(code: 'web_checkout_disabled', message: 'Web checkout disabled'),
      );
      expect(e, isA<ZSWebCheckoutDisabledException>());
      expect(e.message, 'Web checkout disabled');
    });

    test('checkout_not_started maps to ZSCheckoutNotStartedException', () {
      final e = ZeroSettleException.fromPlatformException(
        PlatformException(code: 'checkout_not_started', message: 'Checkout not started'),
      );
      expect(e, isA<ZSCheckoutNotStartedException>());
      expect(e.message, 'Checkout not started');
    });
  });

  group('ZeroSettleException.fromPlatformException — 1.3.0 new raw codes', () {
    test('invalid_publishable_key maps to ZSInvalidPublishableKeyException', () {
      final e = ZeroSettleException.fromPlatformException(
        PlatformException(code: 'invalid_publishable_key', message: 'Invalid publishable key'),
      );
      expect(e, isA<ZSInvalidPublishableKeyException>());
      expect(e.message, 'Invalid publishable key');
    });

    test('checkout_config_expired maps to ZSCheckoutConfigExpiredException', () {
      final e = ZeroSettleException.fromPlatformException(
        PlatformException(code: 'checkout_config_expired', message: 'Checkout config expired'),
      );
      expect(e, isA<ZSCheckoutConfigExpiredException>());
      expect(e.message, 'Checkout config expired');
    });

    test('transaction_verification_failed maps to ZSTransactionVerificationFailedException', () {
      final e = ZeroSettleException.fromPlatformException(
        PlatformException(
          code: 'transaction_verification_failed',
          message: 'Transaction verification failed',
        ),
      );
      expect(e, isA<ZSTransactionVerificationFailedException>());
      expect(e.message, 'Transaction verification failed');
    });

    test('purchase_pending maps to ZSPurchasePendingException', () {
      final e = ZeroSettleException.fromPlatformException(
        PlatformException(code: 'purchase_pending', message: 'Purchase pending'),
      );
      expect(e, isA<ZSPurchasePendingException>());
      expect(e.message, 'Purchase pending');
    });

    test('user_not_identified maps to ZSUserNotIdentifiedException', () {
      final e = ZeroSettleException.fromPlatformException(
        PlatformException(code: 'user_not_identified', message: 'User not identified'),
      );
      expect(e, isA<ZSUserNotIdentifiedException>());
      expect(e.message, 'User not identified');
    });
  });

  group('ZeroSettleException.fromPlatformException — default fallback', () {
    test('unknown code returns a base ZeroSettleException', () {
      final e = ZeroSettleException.fromPlatformException(
        PlatformException(code: 'totally_unknown_code', message: 'something went wrong'),
      );
      expect(e, isA<ZeroSettleException>());
    });

    test('unknown code with null message produces a non-empty message', () {
      final e = ZeroSettleException.fromPlatformException(
        PlatformException(code: 'totally_unknown_code'),
      );
      expect(e, isA<ZeroSettleException>());
      expect(e.message, isNotEmpty);
    });
  });

  group('ZeroSettleException — null message handling', () {
    test('not_configured with null message uses default', () {
      final e = ZeroSettleException.fromPlatformException(
        PlatformException(code: 'not_configured'),
      );
      expect(e, isA<ZSNotConfiguredException>());
      expect(e.message, isNotEmpty);
    });

    test('cancelled with null message uses default', () {
      final e = ZeroSettleException.fromPlatformException(
        PlatformException(code: 'cancelled'),
      );
      expect(e, isA<ZSCancelledException>());
      expect(e.message, isNotEmpty);
    });
  });
}
