package com.zerosettle.flutter.ext

import com.zerosettle.sdk.models.BillingInterval
import com.zerosettle.sdk.models.CheckoutTransaction
import com.zerosettle.sdk.models.Entitlement
import com.zerosettle.sdk.models.EntitlementSource
import com.zerosettle.sdk.models.PendingAction
import com.zerosettle.sdk.models.PendingClaim
import com.zerosettle.sdk.models.Price
import com.zerosettle.sdk.models.Product
import com.zerosettle.sdk.models.ProductType

/**
 * SDK-domain → `Map<String, Any?>` encoders for the Flutter MethodChannel wire.
 *
 * **Wire contract:** the Dart-side parsers in
 * `/Users/ryanelliott/dev/zerosettle/ZeroSettle-Flutter/lib/models/` (e.g.
 * `Entitlement.fromMap`, `Product.fromMap`, `CheckoutTransaction.fromMap`,
 * `PendingClaim.fromMap`) are the source of truth for key names and types.
 * The iOS plugin publishes the same shapes via `toFlutterMap()` Swift
 * extensions in `ios/zerosettle/Sources/zerosettle/ZeroSettlePlugin.swift`.
 *
 * Key drift here is silent runtime breakage on the Dart side — same
 * regression class as the `convertFromSnakeCase` incident. Protected by
 * `ModelToFlutterMapTest.kt`; if you change a key, the test must change
 * too (and Dart must be checked).
 *
 * **Shape conventions** (matched against iOS encoders, field-by-field):
 *
 *   - **Snake_case wire enum values** (e.g. `"store_kit"`, `"web_checkout"`,
 *     `"auto_renewable_subscription"`) are produced from explicit `when`
 *     mappings, not via kotlinx-serialization descriptors. The Dart parsers
 *     decode the same strings via `EntitlementSource.fromRawValue`,
 *     `ZSProductType.fromRawValue`, etc.
 *   - **CamelCase wire keys** (`productId`, `isActive`, `purchasedAt`,
 *     `webPrice`, …) regardless of the Kotlin model's `@SerialName`. The
 *     `@SerialName` annotations are for the *backend* JSON ↔ SDK boundary;
 *     the Flutter wire is a separate, camelCase boundary anchored on the
 *     Dart parsers.
 *   - **Null-valued optional fields are omitted**, mirroring iOS's
 *     `if let x { map["x"] = x }` pattern. Dart parsers tolerate missing
 *     keys for optional fields; emitting explicit `null` would be wider than
 *     the iOS shape and risks parser branches that read `as bool?` on a
 *     present-but-null key incorrectly.
 *   - **Android-only SDK fields are dropped** (e.g. `gracePeriodEndsAt`,
 *     `productType`, `subscriptionGroupId` on `Entitlement`;
 *     `playProductId`, `playBasePlanId`, `playStorePrice` on `Product`).
 *     Dart parsers don't know these and would silently lose them; we don't
 *     extend the contract unilaterally.
 *
 * **`Entitlement.status`** uses the public [Entitlement.statusRaw] getter
 * (the wire string preserved by the SDK), not the enum — mirrors iOS's
 * `map["status"] = status.rawString`. Unknown backend statuses round-trip.
 *
 * **`PendingAction`** has no Dart parser or iOS emitter yet — Android is
 * the first consumer (per the Kotlin SDK doc comment on `PendingAction`).
 * The shape defined here therefore *is* the contract for future adopters.
 * The map carries a `"type"` discriminator (`"migration_completed_info"`
 * or `"manual_play_cancel"`) matching the backend's action-type strings,
 * with the remaining keys in camelCase to stay consistent with the rest of
 * the wire.
 */

fun Price.toFlutterMap(): Map<String, Any?> = mapOf(
    "amountCents" to amountCents,
    "currencyCode" to currencyCode,
)

fun EntitlementSource.toWireString(): String = when (this) {
    EntitlementSource.STORE_KIT -> "store_kit"
    EntitlementSource.WEB_CHECKOUT -> "web_checkout"
    EntitlementSource.PLAY_STORE -> "play_store"
}

fun ProductType.toWireString(): String = when (this) {
    ProductType.AUTO_RENEWABLE_SUBSCRIPTION -> "auto_renewable_subscription"
    ProductType.NON_RENEWING_SUBSCRIPTION -> "non_renewing_subscription"
    ProductType.CONSUMABLE -> "consumable"
    ProductType.NON_CONSUMABLE -> "non_consumable"
}

fun BillingInterval.toWireString(): String = when (this) {
    BillingInterval.WEEK -> "week"
    BillingInterval.MONTH -> "month"
    BillingInterval.YEAR -> "year"
}

fun CheckoutTransaction.Status.toWireString(): String = when (this) {
    CheckoutTransaction.Status.COMPLETED -> "completed"
    CheckoutTransaction.Status.PENDING -> "pending"
    CheckoutTransaction.Status.PROCESSING -> "processing"
    CheckoutTransaction.Status.FAILED -> "failed"
    CheckoutTransaction.Status.REFUNDED -> "refunded"
}

fun Entitlement.toFlutterMap(): Map<String, Any?> {
    val map = mutableMapOf<String, Any?>(
        "id" to id,
        "productId" to productId,
        "source" to source.toWireString(),
        "isActive" to isActive,
        "status" to statusRaw,
        "willRenew" to willRenew,
        "isTrial" to isTrial,
    )
    // `purchasedAt` is `String? = null` on the Kotlin model defensively, but
    // the backend always provides it; iOS treats the field as required.
    // Emit when present, omit when null — Dart's parser will throw on the
    // omitted case, which is the desired loud failure.
    purchasedAt?.let { map["purchasedAt"] = it }
    expiresAt?.let { map["expiresAt"] = it }
    pausedAt?.let { map["pausedAt"] = it }
    pauseResumesAt?.let { map["pauseResumesAt"] = it }
    trialEndsAt?.let { map["trialEndsAt"] = it }
    cancelledAt?.let { map["cancelledAt"] = it }
    storekitOriginalTransactionId?.let { map["storekitOriginalTransactionId"] = it }
    // Intentionally omitted (Android-only or iOS-only fields with no Dart
    // parser counterpart): productType, gracePeriodEndsAt, subscriptionGroupId,
    // playPurchaseToken, originalPurchaseDate.
    return map
}

fun Product.toFlutterMap(): Map<String, Any?> {
    val map = mutableMapOf<String, Any?>(
        "id" to id,
        "displayName" to displayName,
        "productDescription" to productDescription,
        "type" to type.toWireString(),
        "syncedToAppStoreConnect" to syncedToAppStoreConnect,
    )
    webPrice?.let { map["webPrice"] = it.toFlutterMap() }
    appStorePrice?.let { map["appStorePrice"] = it.toFlutterMap() }
    billingInterval?.let { map["billingInterval"] = it.toWireString() }
    subscriptionGroupId?.let { map["subscriptionGroupId"] = it }
    freeTrialDuration?.let { map["freeTrialDuration"] = it }
    isTrialEligible?.let { map["isTrialEligible"] = it }
    // Intentionally omitted (Android-only fields with no Dart parser
    // counterpart): playStorePrice, playProductId, playBasePlanId.
    return map
}

fun CheckoutTransaction.toFlutterMap(): Map<String, Any?> {
    val map = mutableMapOf<String, Any?>(
        "id" to id,
        "productId" to productId,
        "status" to status.toWireString(),
        "source" to source.toWireString(),
        "purchasedAt" to purchasedAt,
    )
    expiresAt?.let { map["expiresAt"] = it }
    productName?.let { map["productName"] = it }
    amountCents?.let { map["amountCents"] = it }
    currency?.let { map["currency"] = it }
    // Intentionally omitted: storekitStatus (iOS-only field; Android SDK
    // doesn't carry it).
    return map
}

fun PendingClaim.toFlutterMap(): Map<String, Any?> = mapOf(
    "productId" to productId,
    "originalTransactionId" to originalTransactionId,
    "existingOwnerHint" to existingOwnerHint,
)

/**
 * Encodes a [PendingAction] for the Flutter wire with a `"type"`
 * discriminator. The variant strings (`"migration_completed_info"` /
 * `"manual_play_cancel"`) match the backend's action-type identifiers.
 *
 * No Dart `fromMap` parser exists for this type yet (Android is the first
 * consumer per the SDK doc comment). The shape defined here is the wire
 * contract for future adopters.
 */
fun PendingAction.toFlutterMap(): Map<String, Any?> = when (this) {
    // Kotlin extension dispatch is static on declared type; explicit subtype
    // qualification avoids any ambiguity with the outer PendingAction
    // extension and rules out accidental recursion if the resolution rules
    // ever change.
    is PendingAction.MigrationCompletedInfo ->
        (this as PendingAction.MigrationCompletedInfo).toFlutterMap()
    is PendingAction.ManualPlayCancel ->
        (this as PendingAction.ManualPlayCancel).toFlutterMap()
}

fun PendingAction.MigrationCompletedInfo.toFlutterMap(): Map<String, Any?> {
    val map = mutableMapOf<String, Any?>(
        "type" to "migration_completed_info",
        "transactionId" to transactionId,
        "userMessage" to userMessage,
    )
    playAccessEndsAtIso?.let { map["playAccessEndsAtIso"] = it }
    newSubscriptionPriceCents?.let { map["newSubscriptionPriceCents"] = it }
    newSubscriptionCurrency?.let { map["newSubscriptionCurrency"] = it }
    newSubscriptionInterval?.let { map["newSubscriptionInterval"] = it }
    return map
}

fun PendingAction.ManualPlayCancel.toFlutterMap(): Map<String, Any?> {
    val map = mutableMapOf<String, Any?>(
        "type" to "manual_play_cancel",
        "transactionId" to transactionId,
        "userMessage" to userMessage,
        "originalPlayPurchaseToken" to originalPlayPurchaseToken,
        "deepLink" to deepLink,
    )
    expiresAtIso?.let { map["expiresAtIso"] = it }
    return map
}
