package com.zerosettle.flutter.ext

import com.google.common.truth.Truth.assertThat
import com.zerosettle.sdk.models.BillingInterval
import com.zerosettle.sdk.models.CheckoutTransaction
import com.zerosettle.sdk.models.Entitlement
import com.zerosettle.sdk.models.EntitlementSource
import com.zerosettle.sdk.models.PendingAction
import com.zerosettle.sdk.models.PendingClaim
import com.zerosettle.sdk.models.Price
import com.zerosettle.sdk.models.Product
import com.zerosettle.sdk.models.ProductType
import com.zerosettle.sdk.models.UserOffer
import com.zerosettle.sdk.models.ZeroSettleError
import com.zerosettle.sdk.offers.OfferManager
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.Assert.assertThrows
import org.junit.Test

/**
 * Pins the SDK-domain -> Map<String, Any?> wire shapes the Flutter MethodChannel
 * publishes. Dart-side `*.fromMap()` parsers in `lib/models/` are the contract;
 * iOS publishes the same shapes via its own `toFlutterMap()` Swift extensions.
 * Key drift here = silent runtime parse failure on the Dart side.
 */
class ModelToFlutterMapTest {

    @Test
    fun `Price encodes amountCents and currencyCode`() {
        val price = Price(amountCents = 999, currencyCode = "USD")

        val map = price.toFlutterMap()

        assertThat(map).containsExactly(
            "amountCents", 999,
            "currencyCode", "USD",
        )
    }

    @Test
    fun `Entitlement encodes all required keys with iOS-matching shape`() {
        val ent = Entitlement(
            id = "ent_123",
            productId = "com.app.pro",
            source = EntitlementSource.WEB_CHECKOUT,
            isActive = true,
            _statusRaw = "active",
            purchasedAt = "2026-05-01T10:00:00Z",
            expiresAt = "2026-06-01T10:00:00Z",
            willRenew = true,
            isTrial = false,
            trialEndsAt = null,
            cancelledAt = null,
            pausedAt = null,
            pauseResumesAt = null,
            storekitOriginalTransactionId = "abc-original",
            // Android-only fields that must NOT leak onto the wire:
            productType = "auto_renewable_subscription",
            gracePeriodEndsAt = "2026-06-08T10:00:00Z",
            subscriptionGroupId = "grp-1",
            playPurchaseToken = "play-token-xyz",
        )

        val map = ent.toFlutterMap()

        // Required keys Dart's Entitlement.fromMap reads non-null.
        assertThat(map["id"]).isEqualTo("ent_123")
        assertThat(map["productId"]).isEqualTo("com.app.pro")
        assertThat(map["source"]).isEqualTo("web_checkout")
        assertThat(map["isActive"]).isEqualTo(true)
        assertThat(map["purchasedAt"]).isEqualTo("2026-05-01T10:00:00Z")

        // Optional keys Dart reads — present when non-null.
        assertThat(map["expiresAt"]).isEqualTo("2026-06-01T10:00:00Z")
        assertThat(map["status"]).isEqualTo("active")
        assertThat(map["willRenew"]).isEqualTo(true)
        assertThat(map["isTrial"]).isEqualTo(false)
        assertThat(map["storekitOriginalTransactionId"]).isEqualTo("abc-original")

        // Android-only fields must be absent (Dart parser doesn't know them).
        assertThat(map).doesNotContainKey("productType")
        assertThat(map).doesNotContainKey("gracePeriodEndsAt")
        assertThat(map).doesNotContainKey("subscriptionGroupId")
        assertThat(map).doesNotContainKey("playPurchaseToken")
        // Null-valued optionals are omitted to match iOS shape exactly.
        assertThat(map).doesNotContainKey("pausedAt")
        assertThat(map).doesNotContainKey("pauseResumesAt")
        assertThat(map).doesNotContainKey("trialEndsAt")
        assertThat(map).doesNotContainKey("cancelledAt")
        // iOS-only field; Android SDK has no analogue.
        assertThat(map).doesNotContainKey("originalPurchaseDate")
    }

    @Test
    fun `Entitlement source enum encodes as backend wire string`() {
        val storeKit = Entitlement(
            id = "e1", productId = "p", source = EntitlementSource.STORE_KIT,
            isActive = true, _statusRaw = "active", purchasedAt = "2026-05-01T10:00:00Z",
        )
        val play = storeKit.copy(source = EntitlementSource.PLAY_STORE)
        val web = storeKit.copy(source = EntitlementSource.WEB_CHECKOUT)

        assertThat(storeKit.toFlutterMap()["source"]).isEqualTo("store_kit")
        assertThat(play.toFlutterMap()["source"]).isEqualTo("play_store")
        assertThat(web.toFlutterMap()["source"]).isEqualTo("web_checkout")
    }

    @Test
    fun `Product encodes with iOS-matching keys and webPrice as nested map`() {
        val product = Product(
            id = "com.app.pro_monthly",
            displayName = "Pro Monthly",
            productDescription = "All features, billed monthly.",
            type = ProductType.AUTO_RENEWABLE_SUBSCRIPTION,
            webPrice = Price(amountCents = 499, currencyCode = "USD"),
            appStorePrice = Price(amountCents = 599, currencyCode = "USD"),
            syncedToAppStoreConnect = true,
            billingInterval = BillingInterval.MONTH,
            subscriptionGroupId = 42,
            freeTrialDuration = "P7D",
            isTrialEligible = true,
            // Android-only fields — must not leak onto the wire:
            playStorePrice = Price(amountCents = 599, currencyCode = "USD"),
            playProductId = "com.app.pro_monthly",
            playBasePlanId = "monthly",
        )

        val map = product.toFlutterMap()

        assertThat(map["id"]).isEqualTo("com.app.pro_monthly")
        assertThat(map["displayName"]).isEqualTo("Pro Monthly")
        assertThat(map["productDescription"]).isEqualTo("All features, billed monthly.")
        assertThat(map["type"]).isEqualTo("auto_renewable_subscription")
        assertThat(map["syncedToAppStoreConnect"]).isEqualTo(true)
        assertThat(map["billingInterval"]).isEqualTo("month")
        assertThat(map["subscriptionGroupId"]).isEqualTo(42)
        assertThat(map["freeTrialDuration"]).isEqualTo("P7D")
        assertThat(map["isTrialEligible"]).isEqualTo(true)

        // Nested Price maps mirror iOS encoding shape exactly.
        @Suppress("UNCHECKED_CAST")
        assertThat(map["webPrice"] as Map<String, Any?>).containsExactly(
            "amountCents", 499,
            "currencyCode", "USD",
        )
        @Suppress("UNCHECKED_CAST")
        assertThat(map["appStorePrice"] as Map<String, Any?>).containsExactly(
            "amountCents", 599,
            "currencyCode", "USD",
        )

        // Android-only fields must not be in the map.
        assertThat(map).doesNotContainKey("playStorePrice")
        assertThat(map).doesNotContainKey("playProductId")
        assertThat(map).doesNotContainKey("playBasePlanId")
    }

    @Test
    fun `Product omits null-valued optional fields`() {
        val minimal = Product(
            id = "com.app.coins100",
            displayName = "100 Coins",
            productDescription = "Consumable currency.",
            type = ProductType.CONSUMABLE,
        )

        val map = minimal.toFlutterMap()

        assertThat(map["id"]).isEqualTo("com.app.coins100")
        assertThat(map["type"]).isEqualTo("consumable")
        assertThat(map["syncedToAppStoreConnect"]).isEqualTo(false)
        assertThat(map).doesNotContainKey("webPrice")
        assertThat(map).doesNotContainKey("appStorePrice")
        assertThat(map).doesNotContainKey("billingInterval")
        assertThat(map).doesNotContainKey("subscriptionGroupId")
        assertThat(map).doesNotContainKey("freeTrialDuration")
        assertThat(map).doesNotContainKey("isTrialEligible")
    }

    @Test
    fun `CheckoutTransaction encodes with iOS-matching keys`() {
        val txn = CheckoutTransaction(
            id = "txn_abc",
            productId = "com.app.pro",
            status = CheckoutTransaction.Status.COMPLETED,
            source = EntitlementSource.WEB_CHECKOUT,
            purchasedAt = "2026-05-01T10:00:00Z",
            expiresAt = "2026-06-01T10:00:00Z",
            productName = "Pro Monthly",
            amountCents = 499,
            currency = "USD",
        )

        val map = txn.toFlutterMap()

        assertThat(map["id"]).isEqualTo("txn_abc")
        assertThat(map["productId"]).isEqualTo("com.app.pro")
        assertThat(map["status"]).isEqualTo("completed")
        assertThat(map["source"]).isEqualTo("web_checkout")
        assertThat(map["purchasedAt"]).isEqualTo("2026-05-01T10:00:00Z")
        assertThat(map["expiresAt"]).isEqualTo("2026-06-01T10:00:00Z")
        assertThat(map["productName"]).isEqualTo("Pro Monthly")
        assertThat(map["amountCents"]).isEqualTo(499)
        assertThat(map["currency"]).isEqualTo("USD")
        // iOS-only field; Android SDK has no analogue.
        assertThat(map).doesNotContainKey("storekitStatus")
    }

    @Test
    fun `CheckoutTransaction omits null optionals`() {
        val minimal = CheckoutTransaction(
            id = "txn_pending",
            productId = "com.app.pro",
            status = CheckoutTransaction.Status.PENDING,
            source = EntitlementSource.STORE_KIT,
            purchasedAt = "2026-05-01T10:00:00Z",
        )

        val map = minimal.toFlutterMap()

        assertThat(map["status"]).isEqualTo("pending")
        assertThat(map["source"]).isEqualTo("store_kit")
        assertThat(map).doesNotContainKey("expiresAt")
        assertThat(map).doesNotContainKey("productName")
        assertThat(map).doesNotContainKey("amountCents")
        assertThat(map).doesNotContainKey("currency")
    }

    @Test
    fun `PendingClaim encodes with iOS-matching keys`() {
        val claim = PendingClaim(
            productId = "com.app.pro",
            originalTransactionId = "100000123",
            existingOwnerHint = "a1b2c3d4",
        )

        val map = claim.toFlutterMap()

        assertThat(map).containsExactly(
            "productId", "com.app.pro",
            "originalTransactionId", "100000123",
            "existingOwnerHint", "a1b2c3d4",
        )
    }

    @Test
    fun `PendingAction MigrationCompletedInfo encodes with type discriminator`() {
        val action = PendingAction.MigrationCompletedInfo(
            transactionId = "txn_migrate_1",
            userMessage = "Your old Play subscription stays active until June 1.",
            playAccessEndsAtIso = "2026-06-01T10:00:00Z",
            newSubscriptionPriceCents = 499,
            newSubscriptionCurrency = "USD",
            newSubscriptionInterval = "month",
        )

        val map = action.toFlutterMap()

        assertThat(map["type"]).isEqualTo("migration_completed_info")
        assertThat(map["transactionId"]).isEqualTo("txn_migrate_1")
        assertThat(map["userMessage"])
            .isEqualTo("Your old Play subscription stays active until June 1.")
        assertThat(map["playAccessEndsAtIso"]).isEqualTo("2026-06-01T10:00:00Z")
        assertThat(map["newSubscriptionPriceCents"]).isEqualTo(499)
        assertThat(map["newSubscriptionCurrency"]).isEqualTo("USD")
        assertThat(map["newSubscriptionInterval"]).isEqualTo("month")
    }

    @Test
    fun `PendingAction MigrationCompletedInfo omits null optionals`() {
        val action = PendingAction.MigrationCompletedInfo(
            transactionId = "txn_migrate_2",
            userMessage = "Migration complete.",
            playAccessEndsAtIso = null,
            newSubscriptionPriceCents = null,
            newSubscriptionCurrency = null,
            newSubscriptionInterval = null,
        )

        val map = action.toFlutterMap()

        assertThat(map["type"]).isEqualTo("migration_completed_info")
        assertThat(map["transactionId"]).isEqualTo("txn_migrate_2")
        assertThat(map["userMessage"]).isEqualTo("Migration complete.")
        assertThat(map).doesNotContainKey("playAccessEndsAtIso")
        assertThat(map).doesNotContainKey("newSubscriptionPriceCents")
        assertThat(map).doesNotContainKey("newSubscriptionCurrency")
        assertThat(map).doesNotContainKey("newSubscriptionInterval")
    }

    @Test
    fun `PendingAction ManualPlayCancel encodes with type discriminator and deep link`() {
        val action = PendingAction.ManualPlayCancel(
            transactionId = "txn_cancel_1",
            userMessage = "Cancel your old Play subscription to finish switching.",
            originalPlayPurchaseToken = "play-token-xyz",
            expiresAtIso = "2026-06-01T10:00:00Z",
            deepLink = "https://play.google.com/store/account/subscriptions",
        )

        val map = action.toFlutterMap()

        assertThat(map["type"]).isEqualTo("manual_play_cancel")
        assertThat(map["transactionId"]).isEqualTo("txn_cancel_1")
        assertThat(map["userMessage"])
            .isEqualTo("Cancel your old Play subscription to finish switching.")
        assertThat(map["originalPlayPurchaseToken"]).isEqualTo("play-token-xyz")
        assertThat(map["expiresAtIso"]).isEqualTo("2026-06-01T10:00:00Z")
        assertThat(map["deepLink"])
            .isEqualTo("https://play.google.com/store/account/subscriptions")
    }

    @Test
    fun `PendingAction sealed dispatch via base type returns correct subtype shape`() {
        // Encoders must be callable through the sealed parent so callers don't
        // need to switch on the subtype themselves.
        val asBase: PendingAction = PendingAction.ManualPlayCancel(
            transactionId = "txn_cancel_via_base",
            userMessage = "Manual cancel needed.",
            originalPlayPurchaseToken = "tok",
            expiresAtIso = null,
            deepLink = "https://play.google.com/store/account/subscriptions",
        )

        val map = asBase.toFlutterMap()

        assertThat(map["type"]).isEqualTo("manual_play_cancel")
        assertThat(map["transactionId"]).isEqualTo("txn_cancel_via_base")
        assertThat(map).doesNotContainKey("expiresAtIso")
    }

    // ---------------------------------------------------------------------
    // UserOffer.OfferData adapter — Android `actionType` discriminator →
    // iOS-legacy `Offer.OfferData` wire shape (`flowType` + `upgradeType`)
    // that Dart's `OfferData.fromMap` reads. See ModelToFlutterMap.kt for
    // the field-by-field mapping rationale.
    // ---------------------------------------------------------------------

    private val fullDisplay = UserOffer.OfferDisplay(
        title = "Save 20%",
        body = "Switch to direct billing for 20% off.",
        ctaText = "Switch Now",
        dismissText = "Maybe Later",
        acceptedTitle = "Almost done",
        acceptedBody = "Complete checkout to finish switching.",
        completedTitle = "All set!",
        completedBody = "You're now on direct billing.",
        appleCancelInstructions = "Cancel your Apple subscription in Settings.",
    )

    @Test
    fun `UserOffer OfferData with MIGRATE_STOREKIT_TO_WEB encodes as flowType migration`() {
        val data = UserOffer.OfferData(
            actionType = UserOffer.ActionType.MIGRATE_STOREKIT_TO_WEB,
            isEligible = true,
            checkoutProductId = "com.app.pro_monthly_web",
            fromProductId = null,
            savingsPercent = 20,
            freeTrialDays = 7,
            minSubscriptionDays = 30,
            maxSubscriptionDays = 365,
            rolloutPercent = 100,
            display = fullDisplay,
            experimentVariantId = 3,
            checkoutPresentation = UserOffer.CheckoutPresentation.SAFARI_VC,
        )

        val map = data.toFlutterMap()

        // Required keys.
        assertThat(map["flowType"]).isEqualTo("migration")
        assertThat(map["productId"]).isEqualTo("com.app.pro_monthly_web")
        // Migration: no upgradeType.
        assertThat(map).doesNotContainKey("upgradeType")
        // Migration: no from/to product IDs on the wire — productId IS the target.
        assertThat(map).doesNotContainKey("fromProductId")
        assertThat(map).doesNotContainKey("toProductId")
        // eligibleProductIds is always emitted (per iOS encoder); empty list when
        // Android has no source for it.
        @Suppress("UNCHECKED_CAST")
        assertThat(map["eligibleProductIds"] as List<String>).isEmpty()
        // Scalars.
        assertThat(map["savingsPercent"]).isEqualTo(20)
        assertThat(map["freeTrialDays"]).isEqualTo(7)
        assertThat(map["minSubscriptionDays"]).isEqualTo(30)
        assertThat(map["maxSubscriptionDays"]).isEqualTo(365)
        assertThat(map["rolloutPercent"]).isEqualTo(100)
        assertThat(map["variantId"]).isEqualTo(3)
        // SAFARI_VC → "safari_vc" (overlapping with Dart enum).
        assertThat(map["checkoutPresentation"]).isEqualTo("safari_vc")
        // Display sub-map.
        @Suppress("UNCHECKED_CAST")
        val display = map["display"] as Map<String, Any?>
        assertThat(display["offerTitle"]).isEqualTo("Save 20%")
        assertThat(display["offerMessage"])
            .isEqualTo("Switch to direct billing for 20% off.")
        assertThat(display["offerCta"]).isEqualTo("Switch Now")
        assertThat(display["acceptedTitle"]).isEqualTo("Almost done")
        assertThat(display["acceptedMessage"])
            .isEqualTo("Complete checkout to finish switching.")
        assertThat(display["completedTitle"]).isEqualTo("All set!")
        assertThat(display["completedMessage"])
            .isEqualTo("You're now on direct billing.")
        // No Android-equivalent — emit empty string for iOS shape parity.
        assertThat(display["acceptedCta"]).isEqualTo("")
        // Android-only display keys MUST NOT leak onto the wire.
        assertThat(display).doesNotContainKey("dismissText")
        assertThat(display).doesNotContainKey("appleCancelInstructions")
    }

    @Test
    fun `UserOffer OfferData with UPGRADE_STOREKIT_TO_WEB encodes as upgrade flow`() {
        val data = UserOffer.OfferData(
            actionType = UserOffer.ActionType.UPGRADE_STOREKIT_TO_WEB,
            isEligible = true,
            checkoutProductId = "com.app.pro_yearly_web",
            fromProductId = "com.app.pro_monthly",
            savingsPercent = 30,
            display = fullDisplay,
        )

        val map = data.toFlutterMap()

        assertThat(map["flowType"]).isEqualTo("upgrade")
        assertThat(map["upgradeType"]).isEqualTo("storekit_to_web")
        // iOS-legacy semantics: `productId` = source, `toProductId` = target.
        // `Offer.OfferData.checkoutProductId` is `toProductId ?? productId`.
        assertThat(map["productId"]).isEqualTo("com.app.pro_monthly")
        assertThat(map["fromProductId"]).isEqualTo("com.app.pro_monthly")
        assertThat(map["toProductId"]).isEqualTo("com.app.pro_yearly_web")
        @Suppress("UNCHECKED_CAST")
        assertThat(map["eligibleProductIds"] as List<String>).isEmpty()
    }

    @Test
    fun `UserOffer OfferData with UPGRADE_WEB_TO_WEB encodes as web_to_web upgrade`() {
        val data = UserOffer.OfferData(
            actionType = UserOffer.ActionType.UPGRADE_WEB_TO_WEB,
            isEligible = true,
            checkoutProductId = "com.app.pro_yearly_web",
            fromProductId = "com.app.pro_monthly_web",
            display = fullDisplay,
        )

        val map = data.toFlutterMap()

        assertThat(map["flowType"]).isEqualTo("upgrade")
        assertThat(map["upgradeType"]).isEqualTo("web_to_web")
        assertThat(map["productId"]).isEqualTo("com.app.pro_monthly_web")
        assertThat(map["fromProductId"]).isEqualTo("com.app.pro_monthly_web")
        assertThat(map["toProductId"]).isEqualTo("com.app.pro_yearly_web")
    }

    @Test
    fun `UserOffer OfferData upgrade with null fromProductId falls back to checkoutProductId`() {
        // Edge case: backend (or future Android SDK) returns an upgrade offer
        // without a `from_product_id`. The encoder must still produce a valid
        // wire shape — fall back to `checkoutProductId` for `productId` and
        // `fromProductId` so Dart's parse doesn't blow up on a null required
        // field.
        val data = UserOffer.OfferData(
            actionType = UserOffer.ActionType.UPGRADE_WEB_TO_WEB,
            isEligible = true,
            checkoutProductId = "com.app.pro_yearly_web",
            fromProductId = null,
            display = fullDisplay,
        )

        val map = data.toFlutterMap()

        assertThat(map["productId"]).isEqualTo("com.app.pro_yearly_web")
        // fromProductId is null on the Android source → omitted on the wire.
        assertThat(map).doesNotContainKey("fromProductId")
        assertThat(map["toProductId"]).isEqualTo("com.app.pro_yearly_web")
    }

    @Test
    fun `UserOffer OfferData with NO_ACTION throws IllegalStateException`() {
        // Callers should null-check `eligibleOffer` before encoding. The encoder
        // is loud-fail to surface mis-encoding bugs immediately — silent null
        // return would be wider than the wire contract (Dart requires non-null
        // flowType + productId + display).
        val data = UserOffer.OfferData(
            actionType = UserOffer.ActionType.NO_ACTION,
            isEligible = false,
            checkoutProductId = "",
            display = null,
        )

        assertThrows(IllegalStateException::class.java) {
            data.toFlutterMap()
        }
    }

    @Test
    fun `UserOffer OfferData with null Display emits empty-string Display map`() {
        // Dart's OfferData.fromMap requires `display` non-null. When Android's
        // backend omits the display block (nullable on OfferData), the encoder
        // must still emit a valid Display map — populated with empty strings,
        // which Dart's OfferDisplay.fromMap tolerates (each field is `?? ''`).
        val data = UserOffer.OfferData(
            actionType = UserOffer.ActionType.MIGRATE_STOREKIT_TO_WEB,
            isEligible = true,
            checkoutProductId = "com.app.pro_monthly_web",
            display = null,
        )

        val map = data.toFlutterMap()

        @Suppress("UNCHECKED_CAST")
        val display = map["display"] as Map<String, Any?>
        assertThat(display["offerTitle"]).isEqualTo("")
        assertThat(display["offerMessage"]).isEqualTo("")
        assertThat(display["offerCta"]).isEqualTo("")
        assertThat(display["acceptedTitle"]).isEqualTo("")
        assertThat(display["acceptedMessage"]).isEqualTo("")
        assertThat(display["acceptedCta"]).isEqualTo("")
        assertThat(display["completedTitle"]).isEqualTo("")
        assertThat(display["completedMessage"]).isEqualTo("")
    }

    @Test
    fun `UserOffer OfferData omits non-overlapping CheckoutPresentation values`() {
        // Dart's OfferCheckoutPresentation has {inline, sheet, safari_vc, safari}.
        // Android's CheckoutPresentation has {webview, native_pay, safari_vc, safari}.
        // For non-overlapping values (WEBVIEW, NATIVE_PAY), the encoder MUST
        // omit the key — Dart's `fromRawValue` would silently downgrade to
        // `inline` (its orElse fallback), which is a hidden behaviour bug.
        // Omitting → Dart sees null → SDK uses the global `checkoutType`.
        val webview = UserOffer.OfferData(
            actionType = UserOffer.ActionType.MIGRATE_STOREKIT_TO_WEB,
            isEligible = true,
            checkoutProductId = "p",
            display = fullDisplay,
            checkoutPresentation = UserOffer.CheckoutPresentation.WEBVIEW,
        )
        val nativePay = webview.copy(
            checkoutPresentation = UserOffer.CheckoutPresentation.NATIVE_PAY,
        )
        val safariVc = webview.copy(
            checkoutPresentation = UserOffer.CheckoutPresentation.SAFARI_VC,
        )
        val safari = webview.copy(
            checkoutPresentation = UserOffer.CheckoutPresentation.SAFARI,
        )
        val none = webview.copy(checkoutPresentation = null)

        assertThat(webview.toFlutterMap()).doesNotContainKey("checkoutPresentation")
        assertThat(nativePay.toFlutterMap()).doesNotContainKey("checkoutPresentation")
        assertThat(safariVc.toFlutterMap()["checkoutPresentation"])
            .isEqualTo("safari_vc")
        assertThat(safari.toFlutterMap()["checkoutPresentation"])
            .isEqualTo("safari")
        assertThat(none.toFlutterMap()).doesNotContainKey("checkoutPresentation")
    }

    @Test
    fun `UserOffer OfferData omits Android-only fields`() {
        // proration, appleSubscription, source, requiresAppleCancel are not in
        // the iOS-legacy wire shape. Dart computes `needsAppleCancel` from
        // `flowType + upgradeType`, so requiresAppleCancel is redundant.
        val data = UserOffer.OfferData(
            actionType = UserOffer.ActionType.UPGRADE_WEB_TO_WEB,
            isEligible = true,
            checkoutProductId = "com.app.pro_yearly_web",
            fromProductId = "com.app.pro_monthly_web",
            display = fullDisplay,
            proration = UserOffer.OfferProration(
                amountCents = 250,
                currency = "USD",
                nextBillingDate = "2026-06-01",
            ),
            requiresAppleCancel = true,
            appleSubscription = UserOffer.AppleSubscriptionSummary(
                isActive = true,
                expiresAt = "2026-06-01",
                statusCode = 1,
                autoRenewEnabled = true,
            ),
            source = UserOffer.SourceStorefront.STORE_KIT,
        )

        val map = data.toFlutterMap()

        assertThat(map).doesNotContainKey("proration")
        assertThat(map).doesNotContainKey("appleSubscription")
        assertThat(map).doesNotContainKey("source")
        assertThat(map).doesNotContainKey("requiresAppleCancel")
        // Also: perProductPrompts has no Android source; must not appear.
        assertThat(map).doesNotContainKey("perProductPrompts")
    }

    @Test
    fun `UserOffer OfferData omits null optional scalars`() {
        val data = UserOffer.OfferData(
            actionType = UserOffer.ActionType.MIGRATE_STOREKIT_TO_WEB,
            isEligible = true,
            checkoutProductId = "com.app.pro_monthly_web",
            // maxSubscriptionDays defaulted to null, experimentVariantId null,
            // checkoutPresentation null.
            display = fullDisplay,
        )

        val map = data.toFlutterMap()

        assertThat(map).doesNotContainKey("maxSubscriptionDays")
        assertThat(map).doesNotContainKey("variantId")
        assertThat(map).doesNotContainKey("checkoutPresentation")
        assertThat(map).doesNotContainKey("upgradeType")
        // rolloutPercent has a non-null default (100); always emitted.
        assertThat(map["rolloutPercent"]).isEqualTo(100)
    }

    @Test
    fun `UserOffer OfferDisplay encoder maps Android fields to iOS-legacy keys`() {
        val display = UserOffer.OfferDisplay(
            title = "T",
            body = "B",
            ctaText = "C",
            dismissText = "D",
            acceptedTitle = "AT",
            acceptedBody = "AB",
            completedTitle = "CT",
            completedBody = "CB",
            appleCancelInstructions = "ACI",
        )

        val map = display.toFlutterMap()

        // iOS-legacy keys derived from Android source.
        assertThat(map["offerTitle"]).isEqualTo("T")
        assertThat(map["offerMessage"]).isEqualTo("B")
        assertThat(map["offerCta"]).isEqualTo("C")
        assertThat(map["acceptedTitle"]).isEqualTo("AT")
        assertThat(map["acceptedMessage"]).isEqualTo("AB")
        assertThat(map["completedTitle"]).isEqualTo("CT")
        assertThat(map["completedMessage"]).isEqualTo("CB")
        // iOS has acceptedCta; Android does not → empty string for parity with
        // the iOS encoder which always emits all 8 keys.
        assertThat(map["acceptedCta"]).isEqualTo("")
        // Android-only fields MUST NOT leak.
        assertThat(map).doesNotContainKey("dismissText")
        assertThat(map).doesNotContainKey("appleCancelInstructions")
    }

    // ---------------------------------------------------------------------
    // OfferManager.toCompositeStateMap  (per-handle state-channel wire pin)
    // ---------------------------------------------------------------------
    //
    // Wire contract: iOS `ZSOfferManager.toFlutterStateMap` at
    // ZeroSettlePlugin.swift:2007-2022. Required keys (state, isLoading,
    // storekitCancelRequired) always emit; optionals (offerData,
    // checkoutErrorMessage) omit when null. State strings are lowercase.

    /**
     * Builds a stubbed [OfferManager] with the supplied StateFlow values.
     * The SDK's `state`, `offerData`, `isLoading`, `checkoutError`,
     * `pendingCheckoutUrl` are read-only StateFlow properties; `mockk` lets
     * us stub each independently.
     */
    private fun stubManager(
        state: OfferManager.OfferState,
        offer: UserOffer.OfferData? = null,
        isLoading: Boolean = false,
        checkoutError: ZeroSettleError? = null,
        pendingCheckoutUrl: String? = null,
    ): OfferManager {
        val m = mockk<OfferManager>(relaxed = true)
        every { m.state } returns MutableStateFlow(state)
        every { m.offerData } returns MutableStateFlow(offer)
        every { m.isLoading } returns MutableStateFlow(isLoading)
        every { m.checkoutError } returns MutableStateFlow(checkoutError)
        every { m.pendingCheckoutUrl } returns MutableStateFlow(pendingCheckoutUrl)
        return m
    }

    @Test
    fun `toCompositeStateMap emits required keys with null-offer defaults`() {
        val m = stubManager(state = OfferManager.OfferState.LOADING)

        val map = m.toCompositeStateMap()

        assertThat(map["state"]).isEqualTo("loading")
        assertThat(map["isLoading"]).isEqualTo(false)
        // No offer -> storekitCancelRequired defaults to false (mirrors iOS,
        // which keeps the field non-nullable Bool).
        assertThat(map["storekitCancelRequired"]).isEqualTo(false)
        // Optionals omitted when null (matches iOS `if let ... { map[...] = ... }`).
        assertThat(map).doesNotContainKey("offerData")
        assertThat(map).doesNotContainKey("checkoutErrorMessage")
        // pendingCheckoutUrl is NOT a wire key (Dart parser doesn't read it).
        assertThat(map).doesNotContainKey("pendingCheckoutUrl")
    }

    @Test
    fun `toCompositeStateMap maps every OfferState to its lowercase wire string`() {
        // Pin the full enum -> wire mapping. ERROR maps to "ineligible"
        // (Dart has no "error" variant; mapping to "loading" would lie).
        val cases = mapOf(
            OfferManager.OfferState.LOADING to "loading",
            OfferManager.OfferState.INELIGIBLE to "ineligible",
            OfferManager.OfferState.ELIGIBLE to "eligible",
            OfferManager.OfferState.PRESENTED to "presented",
            OfferManager.OfferState.ACCEPTED to "accepted",
            OfferManager.OfferState.COMPLETED to "completed",
            OfferManager.OfferState.DISMISSED to "dismissed",
            OfferManager.OfferState.ERROR to "ineligible",
        )
        for ((kotlinState, wire) in cases) {
            assertThat(kotlinState.toWireString()).isEqualTo(wire)
        }
    }

    @Test
    fun `toCompositeStateMap encodes offerData when an eligible offer is present`() {
        val offer = UserOffer.OfferData(
            actionType = UserOffer.ActionType.MIGRATE_STOREKIT_TO_WEB,
            isEligible = true,
            checkoutProductId = "com.app.pro_yearly_web",
            requiresAppleCancel = true,
            display = UserOffer.OfferDisplay(
                title = "Save 30%",
                body = "Switch and save",
                ctaText = "Switch now",
                dismissText = "No thanks",
                acceptedTitle = "",
                acceptedBody = "",
                completedTitle = "",
                completedBody = "",
                appleCancelInstructions = "",
            ),
        )
        val m = stubManager(
            state = OfferManager.OfferState.PRESENTED,
            offer = offer,
            isLoading = false,
        )

        val map = m.toCompositeStateMap()

        assertThat(map["state"]).isEqualTo("presented")
        // needsStoreCancel derives from requiresAppleCancel (alias on Android).
        assertThat(map["storekitCancelRequired"]).isEqualTo(true)
        // offerData nested map is present and uses the iOS-legacy wire shape.
        @Suppress("UNCHECKED_CAST")
        val offerMap = map["offerData"] as Map<String, Any?>
        assertThat(offerMap["flowType"]).isEqualTo("migration")
        assertThat(offerMap["productId"]).isEqualTo("com.app.pro_yearly_web")
    }

    @Test
    fun `toCompositeStateMap encodes checkoutErrorMessage as String not Map`() {
        // iOS emits a String (error.localizedDescription); Dart's parser at
        // offer.dart:424 reads `map['checkoutErrorMessage'] as String?`. A Map
        // here would silently fail to decode.
        val m = stubManager(
            state = OfferManager.OfferState.ERROR,
            checkoutError = ZeroSettleError.CheckoutFailed("server returned 500"),
        )

        val map = m.toCompositeStateMap()

        assertThat(map["state"]).isEqualTo("ineligible")
        assertThat(map["checkoutErrorMessage"]).isInstanceOf(String::class.java)
        assertThat(map["checkoutErrorMessage"] as String).contains("server returned 500")
    }

    @Test
    fun `toCompositeStateMap forwards isLoading`() {
        val m = stubManager(state = OfferManager.OfferState.LOADING, isLoading = true)

        val map = m.toCompositeStateMap()

        assertThat(map["isLoading"]).isEqualTo(true)
    }

    @Test
    fun `toCompositeStateMap omits offerData when actionType is NO_ACTION`() {
        // Defensive: a NO_ACTION offer should never reach state PRESENTED,
        // but if it does we omit `offerData` rather than throwing — the
        // alternative is `UserOffer.OfferData.toFlutterMap()` throwing
        // IllegalStateException up through the state stream, which crashes
        // every subsequent emit.
        val noOpOffer = UserOffer.OfferData(
            actionType = UserOffer.ActionType.NO_ACTION,
            isEligible = false,
            checkoutProductId = "",
            display = null,
        )
        val m = stubManager(
            state = OfferManager.OfferState.INELIGIBLE,
            offer = noOpOffer,
        )

        val map = m.toCompositeStateMap()

        assertThat(map).doesNotContainKey("offerData")
        // storekitCancelRequired still derives from the offer (which has
        // requiresAppleCancel=false by default → false on the wire).
        assertThat(map["storekitCancelRequired"]).isEqualTo(false)
    }
}
