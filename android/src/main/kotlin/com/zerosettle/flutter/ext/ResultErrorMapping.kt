package com.zerosettle.flutter.ext

import com.zerosettle.sdk.models.ZeroSettleError
import io.flutter.plugin.common.MethodChannel

/**
 * Map a [Throwable] from an SDK boundary to a Flutter `result.error`.
 *
 * The error-code wire contract mirrors the plan's spec
 * (`docs/superpowers/plans/2026-05-12-...md:2058-2069`); SDKs and
 * adopters can pattern-match these. Unknown exception types fall through
 * to `sdk_error`.
 *
 * This is the canonical `MethodChannel.Result` failure mapper for the
 * plugin — used by every per-domain handler (Identity, Catalog, Purchase,
 * Subscription, Entitlement, Modals, Diagnostics) and by the OfferManager
 * surfaces (`OfferManagerHandleBridge`, `OfferManagerStaticHandler`).
 */
internal fun MethodChannel.Result.sendError(throwable: Throwable) {
    val code = when (throwable) {
        is ZeroSettleError.NotConfigured -> "not_configured"
        is ZeroSettleError.UserNotIdentified -> "user_not_identified"
        is ZeroSettleError.UserIdRequired -> "user_id_required"
        is ZeroSettleError.InvalidUserId -> "invalid_user_id"
        is ZeroSettleError.ProductNotFound -> "product_not_found"
        is ZeroSettleError.NotFound -> "not_found"
        is ZeroSettleError.CheckoutFailed -> "checkout_failed"
        is ZeroSettleError.PurchaseCancelled -> "cancelled"
        is ZeroSettleError.CheckoutInFlight -> "checkout_in_flight"
        is ZeroSettleError.OfferIneligible -> "offer_ineligible"
        is ZeroSettleError.NotBootstrapped -> "not_bootstrapped"
        is ZeroSettleError.NoActiveSubscription -> "no_active_subscription"
        is ZeroSettleError.AlreadyMigrated -> "already_migrated"
        is ZeroSettleError.MerchantNotOnboarded -> "merchant_not_onboarded"
        is ZeroSettleError.JurisdictionBlocked -> "jurisdiction_blocked"
        is ZeroSettleError.BackendError -> "backend_error"
        is ZeroSettleError.NetworkError -> "network_error"
        is ZeroSettleError.PlayApiUnreachable -> "play_api_unreachable"
        is ZeroSettleError.PlayBillingError -> "play_billing_error"
        is ZeroSettleError.PurchasePending -> "purchase_pending"
        else -> "sdk_error"
    }
    error(code, throwable.message ?: throwable::class.simpleName, null)
}
