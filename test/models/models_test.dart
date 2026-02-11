import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerosettle/zerosettle.dart';

void main() {
  group('Price', () {
    test('fromMap / toMap round-trip', () {
      final map = {'amountMicros': 9990000, 'currencyCode': 'USD'};
      final price = Price.fromMap(map);
      expect(price.amountMicros, 9990000);
      expect(price.currencyCode, 'USD');
      expect(price.toMap(), map);
    });

    test('formatted returns correct string', () {
      final price = Price(amountMicros: 9990000, currencyCode: 'USD');
      expect(price.formatted, '\$9.99');
    });

    test('equality', () {
      final a = Price(amountMicros: 9990000, currencyCode: 'USD');
      final b = Price(amountMicros: 9990000, currencyCode: 'USD');
      final c = Price(amountMicros: 4990000, currencyCode: 'USD');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('Enums', () {
    test('ZSProductType round-trip', () {
      for (final t in ZSProductType.values) {
        expect(ZSProductType.fromRawValue(t.rawValue), t);
      }
    });

    test('EntitlementSource round-trip', () {
      for (final s in EntitlementSource.values) {
        expect(EntitlementSource.fromRawValue(s.rawValue), s);
      }
    });

    test('TransactionStatus round-trip', () {
      for (final s in TransactionStatus.values) {
        expect(TransactionStatus.fromRawValue(s.rawValue), s);
      }
    });

    test('PromotionType round-trip', () {
      for (final t in PromotionType.values) {
        expect(PromotionType.fromRawValue(t.rawValue), t);
      }
    });

    test('CheckoutType round-trip', () {
      for (final t in CheckoutType.values) {
        expect(CheckoutType.fromRawValue(t.rawValue), t);
      }
    });

    test('Jurisdiction round-trip', () {
      for (final j in Jurisdiction.values) {
        expect(Jurisdiction.fromRawValue(j.rawValue), j);
      }
    });
  });

  group('Promotion', () {
    test('fromMap / toMap round-trip', () {
      final map = {
        'id': 'promo_1',
        'displayName': 'Launch Sale',
        'promotionalPrice': {'amountMicros': 2990000, 'currencyCode': 'USD'},
        'expiresAt': '2025-03-01T00:00:00.000Z',
        'type': 'percent_off',
      };
      final promo = Promotion.fromMap(map);
      expect(promo.id, 'promo_1');
      expect(promo.type, PromotionType.percentOff);
      expect(promo.promotionalPrice.amountMicros, 2990000);
      expect(promo.expiresAt, isNotNull);

      final roundTrip = Promotion.fromMap(promo.toMap());
      expect(roundTrip, equals(promo));
    });

    test('fromMap with null expiresAt', () {
      final map = {
        'id': 'promo_2',
        'displayName': 'Forever Free',
        'promotionalPrice': {'amountMicros': 0, 'currencyCode': 'USD'},
        'type': 'free_trial',
      };
      final promo = Promotion.fromMap(map);
      expect(promo.expiresAt, isNull);
    });
  });

  group('ZSProduct', () {
    test('fromMap / toMap round-trip', () {
      final map = {
        'id': 'premium_monthly',
        'displayName': 'Premium Monthly',
        'productDescription': 'All features',
        'type': 'auto_renewable_subscription',
        'webPrice': {'amountMicros': 4990000, 'currencyCode': 'USD'},
        'appStorePrice': {'amountMicros': 5990000, 'currencyCode': 'USD'},
        'syncedToASC': true,
        'storeKitAvailable': true,
        'storeKitPrice': {'amountMicros': 5990000, 'currencyCode': 'USD'},
        'savingsPercent': 17,
      };
      final product = ZSProduct.fromMap(map);
      expect(product.id, 'premium_monthly');
      expect(product.type, ZSProductType.autoRenewableSubscription);
      expect(product.webPrice.formatted, '\$4.99');
      expect(product.savingsPercent, 17);

      final roundTrip = ZSProduct.fromMap(product.toMap());
      expect(roundTrip, equals(product));
    });

    test('fromMap with minimal fields', () {
      final map = {
        'id': 'basic',
        'displayName': 'Basic',
        'productDescription': 'Basic plan',
        'type': 'non_consumable',
        'webPrice': {'amountMicros': 1990000, 'currencyCode': 'USD'},
      };
      final product = ZSProduct.fromMap(map);
      expect(product.appStorePrice, isNull);
      expect(product.syncedToASC, isFalse);
      expect(product.promotion, isNull);
      expect(product.storeKitAvailable, isFalse);
    });
  });

  group('Entitlement', () {
    test('fromMap / toMap round-trip', () {
      final map = {
        'id': 'ent_123',
        'productId': 'premium_monthly',
        'source': 'web_checkout',
        'isActive': true,
        'purchasedAt': '2025-01-15T10:30:00.000Z',
        'expiresAt': '2025-02-15T10:30:00.000Z',
      };
      final ent = Entitlement.fromMap(map);
      expect(ent.id, 'ent_123');
      expect(ent.source, EntitlementSource.webCheckout);
      expect(ent.isActive, isTrue);

      final roundTrip = Entitlement.fromMap(ent.toMap());
      expect(roundTrip, equals(ent));
    });

    test('fromMap with storeKit source', () {
      final map = {
        'id': 'ent_456',
        'productId': 'pro',
        'source': 'store_kit',
        'isActive': true,
        'purchasedAt': '2025-01-01T00:00:00.000Z',
      };
      final ent = Entitlement.fromMap(map);
      expect(ent.source, EntitlementSource.storeKit);
      expect(ent.expiresAt, isNull);
    });
  });

  group('ZSTransaction', () {
    test('fromMap / toMap round-trip', () {
      final map = {
        'id': 'txn_abc',
        'productId': 'premium_monthly',
        'status': 'completed',
        'source': 'web_checkout',
        'purchasedAt': '2025-01-15T10:30:00.000Z',
        'expiresAt': '2025-02-15T10:30:00.000Z',
      };
      final txn = ZSTransaction.fromMap(map);
      expect(txn.id, 'txn_abc');
      expect(txn.status, TransactionStatus.completed);
      expect(txn.source, EntitlementSource.webCheckout);

      final roundTrip = ZSTransaction.fromMap(txn.toMap());
      expect(roundTrip, equals(txn));
    });

    test('all transaction statuses parse correctly', () {
      for (final status in TransactionStatus.values) {
        final map = {
          'id': 'txn_1',
          'productId': 'p',
          'status': status.rawValue,
          'source': 'web_checkout',
          'purchasedAt': '2025-01-01T00:00:00.000Z',
        };
        expect(ZSTransaction.fromMap(map).status, status);
      }
    });
  });

  group('RemoteConfig', () {
    test('fromMap / toMap round-trip', () {
      final map = {
        'checkout': {
          'sheetType': 'webview',
          'isEnabled': true,
          'jurisdictions': {
            'eu': {'sheetType': 'safari', 'isEnabled': false},
            'us': {'sheetType': 'webview', 'isEnabled': true},
          },
        },
        'migration': {
          'productId': 'premium',
          'discountPercent': 20,
          'title': 'Switch & Save',
          'message': 'Save 20%',
        },
      };
      final config = RemoteConfig.fromMap(map);
      expect(config.checkout.sheetType, CheckoutType.webview);
      expect(config.checkout.isEnabled, isTrue);
      expect(config.checkout.jurisdictions, hasLength(2));
      expect(config.checkout.jurisdictions[Jurisdiction.eu]!.isEnabled, isFalse);
      expect(config.migration!.discountPercent, 20);

      final roundTrip = RemoteConfig.fromMap(config.toMap());
      expect(roundTrip, equals(config));
    });

    test('fromMap without migration', () {
      final map = {
        'checkout': {
          'sheetType': 'safari_vc',
          'isEnabled': true,
          'jurisdictions': <String, dynamic>{},
        },
      };
      final config = RemoteConfig.fromMap(map);
      expect(config.migration, isNull);
      expect(config.checkout.sheetType, CheckoutType.safariVC);
    });
  });

  group('ProductCatalog', () {
    test('fromMap / toMap round-trip', () {
      final map = {
        'products': [
          {
            'id': 'p1',
            'displayName': 'P1',
            'productDescription': 'Desc',
            'type': 'consumable',
            'webPrice': {'amountMicros': 990000, 'currencyCode': 'USD'},
          }
        ],
        'config': {
          'checkout': {
            'sheetType': 'safari',
            'isEnabled': true,
            'jurisdictions': <String, dynamic>{},
          },
        },
      };
      final catalog = ProductCatalog.fromMap(map);
      expect(catalog.products, hasLength(1));
      expect(catalog.products.first.type, ZSProductType.consumable);
      expect(catalog.config, isNotNull);
    });

    test('fromMap without config', () {
      final map = {
        'products': <Map<String, dynamic>>[],
      };
      final catalog = ProductCatalog.fromMap(map);
      expect(catalog.products, isEmpty);
      expect(catalog.config, isNull);
    });
  });

  group('ZSException', () {
    test('fromPlatformException maps codes correctly', () {
      expect(
        ZSException.fromPlatformException(
          PlatformException(code: 'cancelled', message: 'User cancelled'),
        ),
        isA<ZSCancelledException>(),
      );
      expect(
        ZSException.fromPlatformException(
          PlatformException(code: 'not_configured', message: 'Not configured'),
        ),
        isA<ZSNotConfiguredException>(),
      );
      expect(
        ZSException.fromPlatformException(
          PlatformException(code: 'product_not_found', message: 'Not found'),
        ),
        isA<ZSProductNotFoundException>(),
      );
      expect(
        ZSException.fromPlatformException(
          PlatformException(code: 'checkout_failed', message: 'Failed'),
        ),
        isA<ZSCheckoutFailedException>(),
      );
      expect(
        ZSException.fromPlatformException(
          PlatformException(code: 'user_id_required', message: 'Required'),
        ),
        isA<ZSUserIdRequiredException>(),
      );
      expect(
        ZSException.fromPlatformException(
          PlatformException(code: 'web_checkout_disabled', message: 'Disabled'),
        ),
        isA<ZSWebCheckoutDisabledException>(),
      );
      expect(
        ZSException.fromPlatformException(
          PlatformException(code: 'unknown_code', message: 'Something'),
        ),
        isA<ZSApiException>(),
      );
    });
  });
}
