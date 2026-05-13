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
}
