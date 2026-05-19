package com.zerosettle.flutter.ext

import com.zerosettle.sdk.models.BillingInterval
import com.zerosettle.sdk.models.CheckoutTransaction
import com.zerosettle.sdk.models.Entitlement
import com.zerosettle.sdk.models.EntitlementSource
import com.zerosettle.sdk.models.PendingAction
import com.zerosettle.sdk.models.PendingClaim
import com.zerosettle.sdk.models.Price
import com.zerosettle.sdk.models.Product
import com.zerosettle.sdk.models.ProductCatalog
import com.zerosettle.sdk.models.ProductType
import com.zerosettle.sdk.models.UpgradeOffer
import com.zerosettle.sdk.models.UserOffer
import com.zerosettle.sdk.offers.OfferManager

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
 * **`PendingAction`** has a Dart parser in `lib/models/pending_action.dart`
 * (Task 4). The map carries a `"type"` discriminator
 * (`"migrationCompletedInfo"` or `"manualPlayCancel"`) matching the Dart
 * `PendingAction.fromMap` switch cases, with all remaining keys in camelCase
 * (no `Iso` suffix on date fields — Dart reads `playAccessEndsAt` /
 * `expiresAt`, not `playAccessEndsAtIso` / `expiresAtIso`).
 */

fun Price.toFlutterMap(): Map<String, Any?> = mapOf(
    "amountCents" to amountCents,
    "currencyCode" to currencyCode,
)

fun EntitlementSource.toWireString(): String = when (this) {
    EntitlementSource.STORE_KIT -> "store_kit"
    EntitlementSource.WEB_CHECKOUT -> "web_checkout"
    EntitlementSource.PLAY_STORE -> "play_store"
    // SDK-side `UNKNOWN` fallback exists so unfamiliar backend values
    // don't crash decode. On the Flutter wire we surface it as the
    // literal "unknown" string — Dart `EntitlementSource.fromRawValue`
    // returns null for unknown raws, which is the desired soft-fail.
    EntitlementSource.UNKNOWN -> "unknown"
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
    // Backend emits `"superseded"` (Web→Web upgrade old-sub cancellation).
    // SDK added the variant + custom serializer so decode doesn't crash;
    // surface it on the Flutter wire byte-for-byte.
    CheckoutTransaction.Status.SUPERSEDED -> "superseded"
    // Soft-fail catch-all for future backend statuses the Dart parser
    // doesn't know — Dart's `Status.fromRawValue` returns null on
    // unrecognized strings (intentional).
    CheckoutTransaction.Status.UNKNOWN -> "unknown"
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

/**
 * Encode the SDK's [ProductCatalog] for the Flutter wire. iOS publishes a
 * `{"products": [...], "config": {...}}` shape (see
 * `ZeroSettlePlugin.swift:1585`). Android's [ProductCatalog] has no
 * `config` field — emit only `products`. Dart parsers tolerate the missing
 * key.
 */
fun ProductCatalog.toFlutterMap(): Map<String, Any?> = mapOf(
    "products" to products.map { it.toFlutterMap() },
)

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
    storekitStatus?.let { map["storekitStatus"] = it }
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
        "type" to "migrationCompletedInfo",
        "transactionId" to transactionId,
        "userMessage" to userMessage,
    )
    playAccessEndsAtIso?.let { map["playAccessEndsAt"] = it }
    newSubscriptionPriceCents?.let { map["newSubscriptionPriceCents"] = it }
    newSubscriptionCurrency?.let { map["newSubscriptionCurrency"] = it }
    newSubscriptionInterval?.let { map["newSubscriptionInterval"] = it }
    return map
}

fun PendingAction.ManualPlayCancel.toFlutterMap(): Map<String, Any?> {
    val map = mutableMapOf<String, Any?>(
        "type" to "manualPlayCancel",
        "transactionId" to transactionId,
        "userMessage" to userMessage,
        "originalPlayPurchaseToken" to originalPlayPurchaseToken,
        "deepLink" to deepLink,
    )
    expiresAtIso?.let { map["expiresAt"] = it }
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
        // `rolloutPercent` shape divergence vs iOS:
        //   iOS holds `rolloutPercent: Int?` and omits when null (i.e., when
        //     the server didn't include the field).
        //   Android holds `rolloutPercent: Int = 100` and can't distinguish
        //     "server explicitly sent 100" from "server omitted".
        //   We always emit — adopting the iOS shape would require
        //   conditionally omitting when value == 100, which would silently
        //   drop genuine server-sent 100s. The Dart parser treats it as
        //   nullable Int, so always-emitting is harmless wire-wise.
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

// ---------------------------------------------------------------------------
// UserOffer.Response → Flutter wire (Task 9: fetchUserOffer)
// ---------------------------------------------------------------------------
//
// This is the NEW wire shape for `fetchUserOffer()` — distinct from the
// iOS-legacy `Offer.OfferData.toFlutterMap()` above which targets the old
// `/v1/iap/products/` config.offer wire. The Dart parser is
// `UserOfferResponse.fromMap` in `lib/models/user_offer.dart`.
//
// Type coercions required (Kotlin → Dart):
//   Response.appId           : Int  → String  (Dart model decodes as String?)
//   OfferData.experimentVariantId: Int? → String? (Dart model decodes as String?)
//   Subscription.type        : snake_case → camelCase  (Dart expects camelCase)
//   ActionType               : explicit when → camelCase wire string
//   SourceStorefront         : explicit when → camelCase wire string
//   CheckoutPresentation     : explicit when → camelCase wire string
//
// Null-omission rule: optional fields that are null are OMITTED (not emitted
// as null), matching the iOS encoder convention and the rest of this file.

/**
 * Encodes the Kotlin SDK's `UserOffer.ActionType` to the camelCase wire string
 * that Dart's `UserOfferActionType.fromWire` accepts.
 */
private fun UserOffer.ActionType.toUserOfferWireString(): String = when (this) {
    UserOffer.ActionType.NO_ACTION -> "noAction"
    UserOffer.ActionType.MIGRATE_STOREKIT_TO_WEB -> "migrateStorekitToWeb"
    UserOffer.ActionType.UPGRADE_STOREKIT_TO_WEB -> "upgradeStorekitToWeb"
    UserOffer.ActionType.UPGRADE_WEB_TO_WEB -> "upgradeWebToWeb"
}

/**
 * Encodes the Kotlin SDK's `UserOffer.SourceStorefront` to the camelCase wire
 * string that Dart's `UserOfferSourceStorefront.fromWire` accepts.
 */
private fun UserOffer.SourceStorefront.toUserOfferWireString(): String = when (this) {
    UserOffer.SourceStorefront.STORE_KIT -> "storeKit"
    UserOffer.SourceStorefront.PLAY_STORE -> "playStore"
}

/**
 * Encodes the Kotlin SDK's `UserOffer.CheckoutPresentation` to the camelCase
 * wire string that Dart's `UserOfferData.checkoutPresentation` field expects.
 */
private fun UserOffer.CheckoutPresentation.toUserOfferWireString(): String = when (this) {
    UserOffer.CheckoutPresentation.WEBVIEW -> "webview"
    UserOffer.CheckoutPresentation.NATIVE_PAY -> "nativePay"
    UserOffer.CheckoutPresentation.SAFARI_VC -> "safariVc"
    UserOffer.CheckoutPresentation.SAFARI -> "safari"
}

/**
 * Remaps the backend snake_case subscription type string to the camelCase wire
 * string that Dart's `UserOfferSubscription.fromMap` expects.
 *
 * The Kotlin model stores the raw backend value verbatim (`"active_web"`,
 * `"active_storekit"`, etc.); the Dart decoder was written against the iOS
 * wire which emits camelCase. Unknown values pass through unchanged so forward
 * compatibility is preserved.
 */
private fun subscriptionTypeToWireString(raw: String): String = when (raw) {
    "none" -> "none"
    "active_web" -> "activeWeb"
    "active_storekit" -> "activeStorekit"
    "migration_trial" -> "migrationTrial"
    "cancelled_active" -> "cancelledActive"
    else -> raw // forward-compat: unknown values pass through
}

/**
 * Encodes `UserOffer.OfferDisplay` for the `fetchUserOffer()` wire — distinct
 * from [UserOffer.OfferDisplay.toFlutterMap] which targets the old iOS-legacy
 * Offer wire. Keys match `UserOfferDisplay.fromMap` in `user_offer.dart`.
 */
private fun UserOffer.OfferDisplay.toUserOfferWireMap(): Map<String, Any?> = mapOf(
    "title" to title,
    "body" to body,
    "ctaText" to ctaText,
    "dismissText" to dismissText,
    "acceptedTitle" to acceptedTitle,
    "acceptedBody" to acceptedBody,
    "completedTitle" to completedTitle,
    "completedBody" to completedBody,
    "appleCancelInstructions" to appleCancelInstructions,
)

/**
 * Encodes `UserOffer.OfferProration` for the `fetchUserOffer()` wire. Keys
 * match `UserOfferProration.fromMap` in `user_offer.dart`.
 */
private fun UserOffer.OfferProration.toUserOfferWireMap(): Map<String, Any?> {
    val map = mutableMapOf<String, Any?>(
        "amountCents" to amountCents,
        "currency" to currency,
    )
    nextBillingDate?.let { map["nextBillingDate"] = it }
    return map
}

/**
 * Encodes `UserOffer.AppleSubscriptionSummary` for the `fetchUserOffer()` wire.
 * Keys match `UserOfferAppleSubscription.fromMap` in `user_offer.dart`.
 */
private fun UserOffer.AppleSubscriptionSummary.toUserOfferWireMap(): Map<String, Any?> {
    val map = mutableMapOf<String, Any?>(
        "isActive" to isActive,
        "statusCode" to statusCode,
        "autoRenewEnabled" to autoRenewEnabled,
    )
    expiresAt?.let { map["expiresAt"] = it }
    return map
}

/**
 * Encodes `UserOffer.OfferData` for the `fetchUserOffer()` wire shape that Dart's
 * `UserOfferData.fromMap` consumes. This is NOT the iOS-legacy Offer wire —
 * see the existing `UserOffer.OfferData.toFlutterMap()` for that path.
 */
private fun UserOffer.OfferData.toUserOfferWireMap(): Map<String, Any?> {
    val map = mutableMapOf<String, Any?>(
        "actionType" to actionType.toUserOfferWireString(),
        "isEligible" to isEligible,
        "checkoutProductId" to checkoutProductId,
        "savingsPercent" to savingsPercent,
        "freeTrialDays" to freeTrialDays,
        "minSubscriptionDays" to minSubscriptionDays,
        "rolloutPercent" to rolloutPercent,
        "requiresAppleCancel" to requiresAppleCancel,
    )
    fromProductId?.let { map["fromProductId"] = it }
    maxSubscriptionDays?.let { map["maxSubscriptionDays"] = it }
    display?.let { map["display"] = it.toUserOfferWireMap() }
    proration?.let { map["proration"] = it.toUserOfferWireMap() }
    appleSubscription?.let { map["appleSubscription"] = it.toUserOfferWireMap() }
    checkoutPresentation?.let { map["checkoutPresentation"] = it.toUserOfferWireString() }
    // experimentVariantId: Int? → String? (Dart model decodes as String?)
    experimentVariantId?.let { map["experimentVariantId"] = it.toString() }
    source?.let { map["source"] = it.toUserOfferWireString() }
    return map
}

/**
 * Encodes the top-level `UserOffer.Response` for the `fetchUserOffer()` wire.
 * Keys match `UserOfferResponse.fromMap` in `lib/models/user_offer.dart`.
 *
 * Type coercions:
 *   - `appId: Int` → `String` (Dart `UserOfferResponse.fromMap` reads `String?`)
 *   - Subscription `type` snake_case → camelCase
 */
fun UserOffer.Response.toFlutterUserOfferMap(): Map<String, Any?> {
    val subMap = mutableMapOf<String, Any?>(
        "type" to subscriptionTypeToWireString(subscription.type),
    )
    subscription.productId?.let { subMap["productId"] = it }

    return mapOf(
        "userId" to userId,
        // appId is Int in the Kotlin model; Dart expects String.
        "appId" to appId.toString(),
        "isSandbox" to isSandbox,
        "serverTime" to serverTime,
        "subscription" to subMap,
        "offer" to offer.toUserOfferWireMap(),
    )
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

// ---------------------------------------------------------------------------
// OfferManager composite state snapshot (per-handle state-channel wire shape)
// ---------------------------------------------------------------------------
//
// Composite snapshot emitted on the per-handle `zerosettle/offer_manager_<id>_state`
// EventChannel by [com.zerosettle.flutter.offermanager.OfferManagerHandleBridge].
// Read by Dart's `OfferManagerState.fromMap` at
// `lib/models/offer.dart:416-426`. iOS publishes the same shape via
// `ZSOfferManager.toFlutterStateMap` at `ZeroSettlePlugin.swift:2007-2022`.
//
// **iOS wire contract (pinned):**
//   Required:
//     - `state`            : String, lowercase enum name
//                            ("loading" | "ineligible" | "eligible" |
//                             "presented" | "accepted" | "completed" |
//                             "dismissed")
//     - `isLoading`        : Boolean
//     - `storekitCancelRequired` : Boolean
//   Optional (omitted when null):
//     - `offerData`           : Map (via UserOffer.OfferData.toFlutterMap)
//     - `checkoutErrorMessage`: **String** (NOT a Map — iOS emits
//                                error.localizedDescription)
//
// **Android-specific divergences (handled here, not the wire):**
//
//   - **`OfferState.ERROR`** is a Kotlin-SDK-only variant — Dart's `OfferState`
//     has no `error` value and `fromRawValue` falls back to `loading` on
//     unknowns. Mapping ERROR -> "loading" is misleading (the manager is not
//     loading; it's stuck after a failed evaluate). We map ERROR -> "ineligible"
//     (closest user-facing semantic: "no offer to present") and surface the
//     underlying error string via `checkoutErrorMessage`. `OfferManager.evaluate`
//     always sets `_checkoutError.value` when transitioning to ERROR
//     (`OfferManager.kt:100-102`), so the message is reliably populated.
//
//   - **`storekitCancelRequired`** is an iOS-only `@Published Bool` derived from
//     the migration flow. Android has no equivalent field, but the underlying
//     semantic (the user must cancel their existing store subscription manually
//     once the web checkout succeeds) is carried by
//     `UserOffer.OfferData.needsStoreCancel`. We mirror iOS's wire field by
//     reading the current offer's `needsStoreCancel` flag — `false` when there
//     is no offer.
//
//   - **`pendingCheckoutUrl`** is an Android-SDK StateFlow (no iOS analogue and
//     no Dart parser key). NOT emitted on the wire — would be invented data
//     versus the iOS contract. We still subscribe to it for change detection
//     (see `OfferManagerHandleBridge.start()`) so a checkout-URL transition can
//     trigger a re-emit if it correlates with a state change the host needs.

/**
 * Maps the Kotlin SDK's [OfferManager.OfferState] enum to the lowercase wire
 * strings Dart's `OfferState.fromRawValue` accepts. The `ERROR` variant is
 * mapped to `"ineligible"` rather than the Dart parser's default `"loading"`
 * fallback — see file-level comment for the rationale.
 */
fun OfferManager.OfferState.toWireString(): String = when (this) {
    OfferManager.OfferState.LOADING -> "loading"
    OfferManager.OfferState.INELIGIBLE -> "ineligible"
    OfferManager.OfferState.ELIGIBLE -> "eligible"
    OfferManager.OfferState.PRESENTED -> "presented"
    OfferManager.OfferState.ACCEPTED -> "accepted"
    OfferManager.OfferState.COMPLETED -> "completed"
    OfferManager.OfferState.DISMISSED -> "dismissed"
    OfferManager.OfferState.ERROR -> "ineligible"
}

/**
 * Composite state snapshot for the per-handle OfferManager state channel.
 *
 * Required keys always emit: `state`, `isLoading`, `storekitCancelRequired`.
 * Optional keys omit when their source value is null: `offerData`,
 * `checkoutErrorMessage` (mirrors iOS's `if let ... { map[...] = ... }`).
 *
 * Reads the current value of each StateFlow at call time — designed to be
 * called from a flow-collection `combine` that fires whenever any source
 * StateFlow updates (see `OfferManagerHandleBridge.start`).
 *
 * The `actionType == NO_ACTION` guard on `OfferData.toFlutterMap` is honoured
 * defensively: a `NO_ACTION` offer should never reach state PRESENTED on the
 * SDK side, but if it somehow does we omit `offerData` rather than throwing.
 */
fun OfferManager.toCompositeStateMap(): Map<String, Any?> {
    val map = mutableMapOf<String, Any?>(
        "state" to state.value.toWireString(),
        "isLoading" to isLoading.value,
        "storekitCancelRequired" to (offerData.value?.needsStoreCancel ?: false),
    )
    val offer = offerData.value
    if (offer != null && offer.actionType != UserOffer.ActionType.NO_ACTION) {
        map["offerData"] = offer.toFlutterMap()
    }
    checkoutError.value?.let { err ->
        map["checkoutErrorMessage"] = err.message ?: err::class.simpleName ?: "unknown error"
    }
    return map
}

/**
 * Encode the Android [UpgradeOffer.Config] for the Flutter wire.
 *
 * **Shape divergence from iOS.** The Android SDK's `UpgradeOffer.Config` is
 * the chunk-4 placeholder (`fromProductId` / `toProductId` /
 * `savingsPercent` / `display{ offer_* / accepted_* / completed_* }`); the
 * iOS plugin emits the chunk-5 wire shape (`available`, `currentProduct`,
 * `targetProduct`, `proration`, `display{title, body, ctaText, ...}`,
 * `variantId`, …). The Android `UpgradeOffer.kt` file carries a
 * `TODO(chunk-5)` to align with the real `GET /v1/iap/upgrade-offer/`
 * response — that alignment is **out of F13 scope**.
 *
 * Until chunk-5 lands, this encoder reflects the *Android-side* placeholder
 * shape as-is: Dart code that consumes this map must know it's looking at
 * the Android shape. Cross-platform Dart parsers will see different keys on
 * each platform. This is a known gap recorded in the plan at row 238.
 *
 * **Runtime risk.** kotlinx-serialization's decode of the backend response
 * into `UpgradeOffer.Config` may fail with `MissingFieldException` if the
 * server emits the chunk-5 shape (which lacks `from_product_id` /
 * `to_product_id` as top-level keys). The handler surfaces decode failure
 * as `sdk_error` via the shared `sendError` extension — the encoder itself
 * is never reached in that path.
 *
 * **Wire keys are camelCase** to match the rest of the encoders in this
 * file. The `@SerialName` snake_case annotations on the model are for the
 * backend boundary only.
 */
fun UpgradeOffer.Config.toFlutterMap(): Map<String, Any?> = mapOf(
    "fromProductId" to fromProductId,
    "toProductId" to toProductId,
    "savingsPercent" to savingsPercent,
    "display" to display.toFlutterMap(),
)

/**
 * Encode the legacy [UpgradeOffer.Display] block. Keys mirror the
 * `@SerialName` snake_case wire (e.g. `offerTitle`, `acceptedMessage`) in
 * camelCase form to match the Flutter wire convention; see encoder above
 * for the chunk-5 alignment caveat.
 */
fun UpgradeOffer.Display.toFlutterMap(): Map<String, Any?> = mapOf(
    "offerTitle" to offerTitle,
    "offerMessage" to offerMessage,
    "offerCta" to offerCta,
    "acceptedTitle" to acceptedTitle,
    "acceptedMessage" to acceptedMessage,
    "acceptedCta" to acceptedCta,
    "completedTitle" to completedTitle,
    "completedMessage" to completedMessage,
)
