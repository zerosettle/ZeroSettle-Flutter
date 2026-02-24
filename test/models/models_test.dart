import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerosettle/zerosettle.dart';

void main() {
  group('Price', () {
    test('fromMap / toMap round-trip', () {
      final map = {'amountCents': 999, 'currencyCode': 'USD'};
      final price = Price.fromMap(map);
      expect(price.amountCents, 999);
      expect(price.currencyCode, 'USD');
      expect(price.toMap(), map);
    });

    test('formatted returns correct string', () {
      final price = Price(amountCents: 999, currencyCode: 'USD');
      expect(price.formatted, '\$9.99');
    });

    test('equality', () {
      final a = Price(amountCents: 999, currencyCode: 'USD');
      final b = Price(amountCents: 999, currencyCode: 'USD');
      final c = Price(amountCents: 499, currencyCode: 'USD');
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
        'promotionalPrice': {'amountCents': 299, 'currencyCode': 'USD'},
        'expiresAt': '2025-03-01T00:00:00.000Z',
        'type': 'percent_off',
      };
      final promo = Promotion.fromMap(map);
      expect(promo.id, 'promo_1');
      expect(promo.type, PromotionType.percentOff);
      expect(promo.promotionalPrice.amountCents, 299);
      expect(promo.expiresAt, isNotNull);

      final roundTrip = Promotion.fromMap(promo.toMap());
      expect(roundTrip, equals(promo));
    });

    test('fromMap with null expiresAt', () {
      final map = {
        'id': 'promo_2',
        'displayName': 'Forever Free',
        'promotionalPrice': {'amountCents': 0, 'currencyCode': 'USD'},
        'type': 'free_trial',
      };
      final promo = Promotion.fromMap(map);
      expect(promo.expiresAt, isNull);
    });
  });

  group('Product', () {
    test('fromMap / toMap round-trip', () {
      final map = {
        'id': 'premium_monthly',
        'displayName': 'Premium Monthly',
        'productDescription': 'All features',
        'type': 'auto_renewable_subscription',
        'webPrice': {'amountCents': 499, 'currencyCode': 'USD'},
        'appStorePrice': {'amountCents': 599, 'currencyCode': 'USD'},
        'syncedToAppStoreConnect': true,
        'storeKitAvailable': true,
        'storeKitPrice': {'amountCents': 599, 'currencyCode': 'USD'},
        'savingsPercent': 17,
      };
      final product = Product.fromMap(map);
      expect(product.id, 'premium_monthly');
      expect(product.type, ZSProductType.autoRenewableSubscription);
      expect(product.webPrice!.formatted, '\$4.99');
      expect(product.savingsPercent, 17);

      final roundTrip = Product.fromMap(product.toMap());
      expect(roundTrip, equals(product));
    });

    test('fromMap with minimal fields', () {
      final map = {
        'id': 'basic',
        'displayName': 'Basic',
        'productDescription': 'Basic plan',
        'type': 'non_consumable',
        'webPrice': {'amountCents': 199, 'currencyCode': 'USD'},
      };
      final product = Product.fromMap(map);
      expect(product.appStorePrice, isNull);
      expect(product.syncedToAppStoreConnect, isFalse);
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

  group('CheckoutTransaction', () {
    test('fromMap / toMap round-trip', () {
      final map = {
        'id': 'txn_abc',
        'productId': 'premium_monthly',
        'status': 'completed',
        'source': 'web_checkout',
        'purchasedAt': '2025-01-15T10:30:00.000Z',
        'expiresAt': '2025-02-15T10:30:00.000Z',
      };
      final txn = CheckoutTransaction.fromMap(map);
      expect(txn.id, 'txn_abc');
      expect(txn.status, TransactionStatus.completed);
      expect(txn.source, EntitlementSource.webCheckout);

      final roundTrip = CheckoutTransaction.fromMap(txn.toMap());
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
        expect(CheckoutTransaction.fromMap(map).status, status);
      }
    });

    test('fromMap with new optional fields present', () {
      final map = {
        'id': 'txn_full',
        'productId': 'premium_monthly',
        'status': 'completed',
        'source': 'web_checkout',
        'purchasedAt': '2025-06-15T10:30:00.000Z',
        'expiresAt': '2025-07-15T10:30:00.000Z',
        'productName': 'Premium Monthly',
        'amountCents': 499,
        'currency': 'USD',
      };
      final txn = CheckoutTransaction.fromMap(map);
      expect(txn.id, 'txn_full');
      expect(txn.productName, 'Premium Monthly');
      expect(txn.amountCents, 499);
      expect(txn.currency, 'USD');
      expect(txn.expiresAt, isNotNull);

      final roundTrip = CheckoutTransaction.fromMap(txn.toMap());
      expect(roundTrip, equals(txn));
    });

    test('fromMap with new optional fields absent', () {
      final map = {
        'id': 'txn_minimal',
        'productId': 'coins_100',
        'status': 'completed',
        'source': 'store_kit',
        'purchasedAt': '2025-06-15T10:30:00.000Z',
      };
      final txn = CheckoutTransaction.fromMap(map);
      expect(txn.id, 'txn_minimal');
      expect(txn.productName, isNull);
      expect(txn.amountCents, isNull);
      expect(txn.currency, isNull);
      expect(txn.expiresAt, isNull);
    });

    test('equality includes new optional fields', () {
      final map = {
        'id': 'txn_eq',
        'productId': 'p',
        'status': 'completed',
        'source': 'web_checkout',
        'purchasedAt': '2025-01-01T00:00:00.000Z',
        'productName': 'Product',
        'amountCents': 100,
        'currency': 'USD',
      };
      final a = CheckoutTransaction.fromMap(map);
      final b = CheckoutTransaction.fromMap(map);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));

      // Different amountCents => not equal
      final c = CheckoutTransaction.fromMap({...map, 'amountCents': 200});
      expect(a, isNot(equals(c)));
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
          'ctaText': 'Save 20% Forever',
        },
      };
      final config = RemoteConfig.fromMap(map);
      expect(config.checkout.sheetType, CheckoutType.webView);
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
            'webPrice': {'amountCents': 99, 'currencyCode': 'USD'},
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

  group('ZeroSettleException', () {
    test('fromPlatformException maps codes correctly', () {
      expect(
        ZeroSettleException.fromPlatformException(
          PlatformException(code: 'cancelled', message: 'User cancelled'),
        ),
        isA<ZSCancelledException>(),
      );
      expect(
        ZeroSettleException.fromPlatformException(
          PlatformException(code: 'not_configured', message: 'Not configured'),
        ),
        isA<ZSNotConfiguredException>(),
      );
      expect(
        ZeroSettleException.fromPlatformException(
          PlatformException(code: 'product_not_found', message: 'Not found'),
        ),
        isA<ZSProductNotFoundException>(),
      );
      expect(
        ZeroSettleException.fromPlatformException(
          PlatformException(code: 'checkout_failed', message: 'Failed'),
        ),
        isA<ZSCheckoutFailedException>(),
      );
      expect(
        ZeroSettleException.fromPlatformException(
          PlatformException(code: 'user_id_required', message: 'Required'),
        ),
        isA<ZSUserIdRequiredException>(),
      );
      expect(
        ZeroSettleException.fromPlatformException(
          PlatformException(code: 'web_checkout_disabled', message: 'Disabled'),
        ),
        isA<ZSWebCheckoutDisabledException>(),
      );
      expect(
        ZeroSettleException.fromPlatformException(
          PlatformException(code: 'unknown_code', message: 'Something'),
        ),
        isA<ZSApiException>(),
      );
    });
  });

  group('CancelFlowConfig', () {
    test('fromMap / toMap round-trip with full payload', () {
      final map = {
        'enabled': true,
        'questions': [
          {
            'id': 1,
            'order': 1,
            'questionText': 'Why are you leaving?',
            'questionType': 'single_select',
            'isRequired': true,
            'options': [
              {
                'id': 10,
                'order': 1,
                'label': 'Too expensive',
                'triggersOffer': true,
                'triggersPause': false,
              },
              {
                'id': 11,
                'order': 2,
                'label': 'Not using it',
                'triggersOffer': false,
                'triggersPause': true,
              },
            ],
          },
          {
            'id': 2,
            'order': 2,
            'questionText': 'Anything else?',
            'questionType': 'free_text',
            'isRequired': false,
            'options': <Map<String, dynamic>>[],
          },
        ],
        'offer': {
          'enabled': true,
          'title': 'Stay with us!',
          'body': 'We\'ll give you 40% off for 3 months.',
          'ctaText': 'Accept Offer',
          'type': 'percent_off',
          'value': '40',
        },
        'pause': {
          'enabled': true,
          'title': 'Take a break',
          'body': 'Pause your subscription instead of cancelling.',
          'ctaText': 'Pause',
          'options': [
            {
              'id': 100,
              'order': 1,
              'label': '1 month',
              'durationType': 'days',
              'durationDays': 30,
            },
            {
              'id': 101,
              'order': 2,
              'label': 'Until March',
              'durationType': 'fixed_date',
              'resumeDate': '2026-03-01T00:00:00.000Z',
            },
          ],
        },
        'variantId': 42,
      };

      final config = CancelFlowConfig.fromMap(map);
      expect(config.enabled, isTrue);
      expect(config.questions, hasLength(2));
      expect(config.questions.first.questionText, 'Why are you leaving?');
      expect(config.questions.first.options, hasLength(2));
      expect(config.questions.first.options.first.triggersOffer, isTrue);
      expect(config.questions.first.options.last.triggersPause, isTrue);
      expect(config.questions.last.options, isEmpty);
      expect(config.offer, isNotNull);
      expect(config.offer!.type, 'percent_off');
      expect(config.offer!.value, '40');
      expect(config.pause, isNotNull);
      expect(config.pause!.options, hasLength(2));
      expect(config.pause!.options.first.durationDays, 30);
      expect(config.pause!.options.last.resumeDate, isNotNull);
      expect(config.variantId, 42);

      // Round-trip
      final roundTrip = CancelFlowConfig.fromMap(config.toMap());
      expect(roundTrip.enabled, config.enabled);
      expect(roundTrip.questions.length, config.questions.length);
      expect(roundTrip.questions.first.id, config.questions.first.id);
      expect(roundTrip.offer!.title, config.offer!.title);
      expect(roundTrip.pause!.options.length, config.pause!.options.length);
      expect(roundTrip.variantId, config.variantId);
    });

    test('fromMap with minimal payload (no offer, no pause, no variantId)', () {
      final map = {
        'enabled': false,
        'questions': <Map<String, dynamic>>[],
      };
      final config = CancelFlowConfig.fromMap(map);
      expect(config.enabled, isFalse);
      expect(config.questions, isEmpty);
      expect(config.offer, isNull);
      expect(config.pause, isNull);
      expect(config.variantId, isNull);
    });

    test('CancelFlowPauseOption with no durationDays or resumeDate', () {
      final map = {
        'id': 200,
        'order': 1,
        'label': 'Indefinite',
        'durationType': 'indefinite',
      };
      final option = CancelFlowPauseOption.fromMap(map);
      expect(option.durationDays, isNull);
      expect(option.resumeDate, isNull);

      final rt = CancelFlowPauseOption.fromMap(option.toMap());
      expect(rt.id, option.id);
      expect(rt.durationDays, isNull);
      expect(rt.resumeDate, isNull);
    });

    test('CancelFlowOption triggersPause defaults to false when absent', () {
      final map = {
        'id': 1,
        'order': 1,
        'label': 'Test',
        'triggersOffer': false,
      };
      final option = CancelFlowOption.fromMap(map);
      expect(option.triggersPause, isFalse);
    });
  });

  group('CancelFlowResult', () {
    test('"cancelled" returns CancelFlowCancelled', () {
      final result = CancelFlowResult.fromRawValue('cancelled');
      expect(result, isA<CancelFlowCancelled>());
    });

    test('"retained" returns CancelFlowRetained', () {
      final result = CancelFlowResult.fromRawValue('retained');
      expect(result, isA<CancelFlowRetained>());
    });

    test('"dismissed" returns CancelFlowDismissed', () {
      final result = CancelFlowResult.fromRawValue('dismissed');
      expect(result, isA<CancelFlowDismissed>());
    });

    test('"paused" without date returns CancelFlowPaused with null resumesAt', () {
      final result = CancelFlowResult.fromRawValue('paused');
      expect(result, isA<CancelFlowPaused>());
      expect((result as CancelFlowPaused).resumesAt, isNull);
    });

    test('"paused:<ISO8601>" returns CancelFlowPaused with parsed date', () {
      final result = CancelFlowResult.fromRawValue('paused:2026-03-01T00:00:00.000Z');
      expect(result, isA<CancelFlowPaused>());
      final paused = result as CancelFlowPaused;
      expect(paused.resumesAt, isNotNull);
      expect(paused.resumesAt!.year, 2026);
      expect(paused.resumesAt!.month, 3);
      expect(paused.resumesAt!.day, 1);
    });

    test('unknown value falls through to CancelFlowCancelled', () {
      final result = CancelFlowResult.fromRawValue('some_unknown_value');
      expect(result, isA<CancelFlowCancelled>());
    });
  });

  group('CancelFlowResponsePayload', () {
    test('toMap includes all fields', () {
      final payload = CancelFlowResponsePayload(
        userId: 'user_1',
        productId: 'premium_monthly',
        outcome: 'retained',
        offerShown: true,
        offerAccepted: true,
        pauseShown: false,
        pauseAccepted: false,
        lastStepSeen: 3,
        answers: [
          CancelFlowAnswerPayload(questionId: 1, selectedOptionId: 10),
          CancelFlowAnswerPayload(questionId: 2, freeText: 'Great app!'),
        ],
        variantId: 42,
      );
      final map = payload.toMap();
      expect(map['userId'], 'user_1');
      expect(map['outcome'], 'retained');
      expect(map['offerShown'], isTrue);
      expect(map['offerAccepted'], isTrue);
      expect(map['pauseShown'], isFalse);
      expect(map['pauseAccepted'], isFalse);
      expect(map['lastStepSeen'], 3);
      expect(map['answers'], hasLength(2));
      expect(map['variantId'], 42);
    });

    test('toMap omits null optional fields', () {
      final payload = CancelFlowResponsePayload(
        userId: 'user_1',
        productId: 'p',
        outcome: 'cancelled',
        offerShown: false,
        offerAccepted: false,
        lastStepSeen: 1,
        answers: [],
      );
      final map = payload.toMap();
      expect(map.containsKey('pauseDurationDays'), isFalse);
      expect(map.containsKey('variantId'), isFalse);
    });
  });

  group('UpgradeOfferConfig', () {
    test('fromMap / toMap round-trip with full payload', () {
      final map = {
        'available': true,
        'reason': 'eligible_for_annual',
        'currentProduct': {
          'referenceId': 'com.app.monthly',
          'name': 'Monthly Plan',
          'priceCents': 999,
          'currency': 'USD',
          'durationDays': 30,
          'billingLabel': '\$9.99/month',
        },
        'targetProduct': {
          'referenceId': 'com.app.annual',
          'name': 'Annual Plan',
          'priceCents': 7999,
          'currency': 'USD',
          'durationDays': 365,
          'billingLabel': '\$79.99/year',
          'monthlyEquivalentCents': 667,
        },
        'savingsPercent': 33,
        'upgradeType': 'annual_upgrade',
        'proration': {
          'prorationAmountCents': 500,
          'currency': 'USD',
          'nextBillingDate': 1740787200,
        },
        'display': {
          'title': 'Save 33%',
          'body': 'Switch to annual and save.',
          'ctaText': 'Upgrade Now',
          'dismissText': 'Not Now',
          'storekitMigrationBody': 'Cancel your App Store sub first.',
          'cancelInstructions': 'Go to Settings > Subscriptions.',
        },
        'variantId': 7,
      };

      final config = UpgradeOfferConfig.fromMap(map);
      expect(config.available, isTrue);
      expect(config.reason, 'eligible_for_annual');
      expect(config.currentProduct, isNotNull);
      expect(config.currentProduct!.referenceId, 'com.app.monthly');
      expect(config.currentProduct!.priceCents, 999);
      expect(config.targetProduct, isNotNull);
      expect(config.targetProduct!.monthlyEquivalentCents, 667);
      expect(config.savingsPercent, 33);
      expect(config.upgradeType, 'annual_upgrade');
      expect(config.proration, isNotNull);
      expect(config.proration!.prorationAmountCents, 500);
      expect(config.proration!.nextBillingDate, 1740787200);
      expect(config.display, isNotNull);
      expect(config.display!.storekitMigrationBody, isNotNull);
      expect(config.display!.cancelInstructions, isNotNull);
      expect(config.variantId, 7);

      // Round-trip
      final roundTrip = UpgradeOfferConfig.fromMap(config.toMap());
      expect(roundTrip.available, config.available);
      expect(roundTrip.reason, config.reason);
      expect(roundTrip.currentProduct!.referenceId, config.currentProduct!.referenceId);
      expect(roundTrip.targetProduct!.monthlyEquivalentCents, config.targetProduct!.monthlyEquivalentCents);
      expect(roundTrip.proration!.prorationAmountCents, config.proration!.prorationAmountCents);
      expect(roundTrip.display!.title, config.display!.title);
      expect(roundTrip.variantId, config.variantId);
    });

    test('fromMap with minimal payload (not available)', () {
      final map = {
        'available': false,
        'reason': 'already_on_annual',
      };
      final config = UpgradeOfferConfig.fromMap(map);
      expect(config.available, isFalse);
      expect(config.reason, 'already_on_annual');
      expect(config.currentProduct, isNull);
      expect(config.targetProduct, isNull);
      expect(config.proration, isNull);
      expect(config.display, isNull);
      expect(config.savingsPercent, isNull);
      expect(config.variantId, isNull);
    });

    test('UpgradeOfferProration with null nextBillingDate', () {
      final map = {
        'prorationAmountCents': 0,
        'currency': 'EUR',
      };
      final proration = UpgradeOfferProration.fromMap(map);
      expect(proration.prorationAmountCents, 0);
      expect(proration.currency, 'EUR');
      expect(proration.nextBillingDate, isNull);

      final rt = UpgradeOfferProration.fromMap(proration.toMap());
      expect(rt.nextBillingDate, isNull);
    });

    test('UpgradeOfferDisplay with null optional fields', () {
      final map = {
        'title': 'Upgrade',
        'body': 'Save money',
        'ctaText': 'Go',
        'dismissText': 'Skip',
      };
      final display = UpgradeOfferDisplay.fromMap(map);
      expect(display.storekitMigrationBody, isNull);
      expect(display.cancelInstructions, isNull);

      final rt = UpgradeOfferDisplay.fromMap(display.toMap());
      expect(rt.storekitMigrationBody, isNull);
      expect(rt.cancelInstructions, isNull);
    });
  });

  group('UpgradeOfferResult', () {
    test('"upgraded" returns UpgradeOfferUpgraded', () {
      final result = UpgradeOfferResult.fromRawValue('upgraded');
      expect(result, isA<UpgradeOfferUpgraded>());
    });

    test('"declined" returns UpgradeOfferDeclined', () {
      final result = UpgradeOfferResult.fromRawValue('declined');
      expect(result, isA<UpgradeOfferDeclined>());
    });

    test('"dismissed" returns UpgradeOfferDismissed', () {
      final result = UpgradeOfferResult.fromRawValue('dismissed');
      expect(result, isA<UpgradeOfferDismissed>());
    });

    test('unknown value falls through to UpgradeOfferDismissed', () {
      final result = UpgradeOfferResult.fromRawValue('some_unknown_value');
      expect(result, isA<UpgradeOfferDismissed>());
    });
  });

  group('UpgradeOfferResponsePayload', () {
    test('toMap includes all fields', () {
      final payload = UpgradeOfferResponsePayload(
        userId: 'user_1',
        currentProductId: 'com.app.monthly',
        targetProductId: 'com.app.annual',
        outcome: 'upgraded',
        upgradeType: 'annual_upgrade',
        variantId: 7,
      );
      final map = payload.toMap();
      expect(map['userId'], 'user_1');
      expect(map['currentProductId'], 'com.app.monthly');
      expect(map['targetProductId'], 'com.app.annual');
      expect(map['outcome'], 'upgraded');
      expect(map['upgradeType'], 'annual_upgrade');
      expect(map['variantId'], 7);
    });

    test('toMap omits null variantId', () {
      final payload = UpgradeOfferResponsePayload(
        userId: 'user_1',
        currentProductId: 'p1',
        targetProductId: 'p2',
        outcome: 'declined',
        upgradeType: 'annual_upgrade',
      );
      final map = payload.toMap();
      expect(map.containsKey('variantId'), isFalse);
    });
  });
}
