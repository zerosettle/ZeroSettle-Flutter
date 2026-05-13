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
import com.zerosettle.sdk.models.UserOffer

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

// ---------------------------------------------------------------------------
// UserOffer.OfferData adapter
// ---------------------------------------------------------------------------
//
// Android's [UserOffer.OfferData] is the *modern* offer shape (discriminated by
// [UserOffer.ActionType]). The Dart-side `OfferData.fromMap` at
// `lib/models/offer.dart` reads the *iOS-legacy* `Offer.OfferData` shape
// (discriminated by `flowType` + optional `upgradeType`). This adapter bridges
// those two shapes so Android can keep using its modern internal model while
// publishing the wire shape the existing Dart parser expects.
//
// Mapping summary:
//   - `ActionType.MIGRATE_STOREKIT_TO_WEB` → `flowType=migration` (no upgradeType)
//   - `ActionType.UPGRADE_STOREKIT_TO_WEB` → `flowType=upgrade`, `upgradeType=storekit_to_web`
//   - `ActionType.UPGRADE_WEB_TO_WEB`      → `flowType=upgrade`, `upgradeType=web_to_web`
//   - `ActionType.NO_ACTION`               → throws `IllegalStateException`
//     (callers MUST null-check via `UserOffer.Response.eligibleOffer` first;
//     silent null-return would be wider than the Dart wire contract, which
//     requires non-null `flowType` + `productId` + `display`).
//
// Field-by-field rules (see `lib/models/offer.dart:258-300`):
//
//   - `productId`: For *migrations* this is the target (`checkoutProductId`).
//     For *upgrades* this is the source — iOS legacy semantics treat
//     `productId` as the source and `toProductId` as the target (see the
//     computed property `Offer.OfferData.checkoutProductId: toProductId ?? productId`).
//     If Android's `fromProductId` is null on an upgrade, fall back to
//     `checkoutProductId` so the required Dart field stays non-null.
//
//   - `eligibleProductIds`: Always emitted (matches iOS encoder shape). Android
//     has no equivalent source field on `UserOffer.OfferData`, so this is the
//     empty list. Dart tolerates empty via `?? <String>[]`. Fabricating a
//     single-element list would invent data — the "drop fields, don't invent"
//     principle wins.
//
//   - `display`: Required by Dart (`OfferData.fromMap` decodes it as
//     `Map<String, dynamic>.from(map['display'] as Map)` — null would crash).
//     When Android's `display` is null, emit an empty-string Display map; each
//     iOS-legacy field is `?? ''` on the Dart side, so this is graceful.
//
//   - `checkoutPresentation`: Dart's `OfferCheckoutPresentation` is
//     `{inline, sheet, safari_vc, safari}`. Android's `CheckoutPresentation`
//     is `{webview, native_pay, safari_vc, safari}`. Only `safari_vc` and
//     `safari` overlap. For non-overlapping values (`WEBVIEW`, `NATIVE_PAY`),
//     OMIT the key — Dart's `fromRawValue` would silently fall back to
//     `inline` (its `orElse`), which is a hidden behaviour bug. Omitting →
//     Dart sees null → SDK uses the global `checkoutType`.
//
//   - `OfferDisplay`: Android uses different field names. Mapping:
//       Android.title   → iOS.offerTitle
//       Android.body    → iOS.offerMessage
//       Android.ctaText → iOS.offerCta
//       Android.acceptedTitle → iOS.acceptedTitle      (name matches)
//       Android.acceptedBody  → iOS.acceptedMessage
//       Android.completedTitle → iOS.completedTitle    (name matches)
//       Android.completedBody  → iOS.completedMessage
//       Android.dismissText             → DROP (no iOS equivalent)
//       Android.appleCancelInstructions → DROP (no iOS equivalent)
//       iOS.acceptedCta                 → emit empty string (no Android source).
//     The iOS encoder always emits all 8 keys; we match that shape exactly.
//
//   - `variantId`: Android's `experimentVariantId` → Dart's `variantId`.
//
//   - DROPPED (not in the iOS-legacy wire contract):
//       proration, appleSubscription, source, requiresAppleCancel,
//       perProductPrompts (Android has no source field).
//     `requiresAppleCancel` is computed Dart-side via `flowType + upgradeType`,
//     so it would be redundant data anyway.

/**
 * Encodes Android's modern [UserOffer.OfferData] into the iOS-legacy
 * `Offer.OfferData` wire shape that Dart's `OfferData.fromMap` consumes.
 *
 * **Caller contract:** Only call this for offers where
 * [UserOffer.OfferData.actionType] is NOT [UserOffer.ActionType.NO_ACTION].
 * The recommended path is to encode `UserOffer.Response.eligibleOffer` (which
 * filters on both `isEligible` and `actionType != NO_ACTION`); calling on a
 * `NO_ACTION` offer throws [IllegalStateException].
 *
 * @throws IllegalStateException if [UserOffer.OfferData.actionType] is
 *   [UserOffer.ActionType.NO_ACTION] — encoding a no-action offer would emit
 *   a Map missing the required `flowType` semantics. Caller should null-check.
 */
fun UserOffer.OfferData.toFlutterMap(): Map<String, Any?> {
    val flow: String = when (actionType) {
        UserOffer.ActionType.MIGRATE_STOREKIT_TO_WEB -> "migration"
        UserOffer.ActionType.UPGRADE_STOREKIT_TO_WEB -> "upgrade"
        UserOffer.ActionType.UPGRADE_WEB_TO_WEB -> "upgrade"
        UserOffer.ActionType.NO_ACTION -> throw IllegalStateException(
            "Cannot encode UserOffer.OfferData with actionType=NO_ACTION — " +
                "caller should null-check via UserOffer.Response.eligibleOffer " +
                "before encoding."
        )
    }
    val isMigration = actionType == UserOffer.ActionType.MIGRATE_STOREKIT_TO_WEB
    // iOS-legacy `productId` semantics:
    //   migration: target product (what the user will buy on web)
    //   upgrade:   source product (the user's current sub; target lives in `toProductId`)
    val productIdOut: String = if (isMigration) {
        checkoutProductId
    } else {
        fromProductId ?: checkoutProductId
    }

    val map = mutableMapOf<String, Any?>(
        "flowType" to flow,
        "productId" to productIdOut,
        // Always emit (matches iOS shape). Android has no source field → empty list.
        "eligibleProductIds" to emptyList<String>(),
        "savingsPercent" to savingsPercent,
        // Dart requires a non-null Display map. Synthesize an empty one when
        // Android's optional Display is absent.
        "display" to (display?.toFlutterMap() ?: emptyOfferDisplayMap()),
        "freeTrialDays" to freeTrialDays,
        "minSubscriptionDays" to minSubscriptionDays,
        // `rolloutPercent` has a non-null Android default (100); always emit.
        "rolloutPercent" to rolloutPercent,
    )
    maxSubscriptionDays?.let { map["maxSubscriptionDays"] = it }
    // Upgrade-only keys.
    if (!isMigration) {
        map["upgradeType"] = when (actionType) {
            UserOffer.ActionType.UPGRADE_STOREKIT_TO_WEB -> "storekit_to_web"
            UserOffer.ActionType.UPGRADE_WEB_TO_WEB -> "web_to_web"
            // Unreachable: the migration/no_action branches return earlier.
            else -> error("upgradeType requested for non-upgrade actionType=$actionType")
        }
        fromProductId?.let { map["fromProductId"] = it }
        map["toProductId"] = checkoutProductId
    }
    experimentVariantId?.let { map["variantId"] = it }
    checkoutPresentation?.toWireStringOrNull()?.let { map["checkoutPresentation"] = it }
    // Intentionally omitted (not in the iOS-legacy wire contract): proration,
    // appleSubscription, source, requiresAppleCancel, perProductPrompts.
    return map
}

/**
 * Maps an Android [UserOffer.OfferDisplay] to the iOS-legacy `Offer.Display`
 * wire shape. Android-only fields (`dismissText`, `appleCancelInstructions`)
 * are dropped — they have no iOS analogue. The iOS-only `acceptedCta` field
 * is emitted as an empty string for shape parity with the iOS encoder, which
 * always emits all 8 keys.
 */
fun UserOffer.OfferDisplay.toFlutterMap(): Map<String, Any?> = mapOf(
    "offerTitle" to title,
    "offerMessage" to body,
    "offerCta" to ctaText,
    "acceptedTitle" to acceptedTitle,
    "acceptedMessage" to acceptedBody,
    // Android has no `acceptedCta` analogue; emit empty so the iOS shape's
    // 8-key layout is preserved (Dart's `OfferDisplay.fromMap` does `?? ''`).
    "acceptedCta" to "",
    "completedTitle" to completedTitle,
    "completedMessage" to completedBody,
)

/** Empty-string Display map for the null-Display fallback path. */
private fun emptyOfferDisplayMap(): Map<String, Any?> = mapOf(
    "offerTitle" to "",
    "offerMessage" to "",
    "offerCta" to "",
    "acceptedTitle" to "",
    "acceptedMessage" to "",
    "acceptedCta" to "",
    "completedTitle" to "",
    "completedMessage" to "",
)

/**
 * Returns the Dart-side `OfferCheckoutPresentation` rawValue for the values
 * that overlap, and `null` for values that don't.
 *
 * Dart enum:    inline, sheet, safari_vc, safari
 * Android enum: webview, native_pay, safari_vc, safari
 *
 * For `WEBVIEW` / `NATIVE_PAY`, Dart's `fromRawValue` would silently fall back
 * to `inline` (its `orElse` clause), masking the underlying mismatch. Returning
 * null here causes the encoder to omit the key, which makes Dart use the
 * SDK's global `checkoutType` — the correct default.
 */
private fun UserOffer.CheckoutPresentation.toWireStringOrNull(): String? = when (this) {
    UserOffer.CheckoutPresentation.SAFARI_VC -> "safari_vc"
    UserOffer.CheckoutPresentation.SAFARI -> "safari"
    UserOffer.CheckoutPresentation.WEBVIEW -> null
    UserOffer.CheckoutPresentation.NATIVE_PAY -> null
}
