package com.zerosettle.flutter.handlers

import android.util.Log
import com.zerosettle.flutter.ext.toFlutterMap
import com.zerosettle.sdk.Identity
import com.zerosettle.sdk.ZeroSettle
import com.zerosettle.sdk.ZeroSettleConfig
import com.zerosettle.sdk.models.ZeroSettleError
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.launch

/**
 * F8 — identity / lifecycle method-channel handler.
 *
 * Owns the nine lifecycle methods Dart calls on the main `zerosettle`
 * channel: `configure`, `bootstrap`, `identify`, `logout`, `setCustomer`,
 * `transferStoreKitOwnershipToCurrentUser`, `getCurrentUserId`,
 * `getIsBootstrapped`, `getIsConfigured`.
 *
 * Wire shapes are mirrored from
 * `ios/zerosettle/Sources/zerosettle/ZeroSettlePlugin.swift` — return
 * types, arg names, and error codes match exactly so the Dart parser
 * sees one contract regardless of platform.
 *
 * ## iOS-only configure args
 *
 * Dart's `configure({...})` carries several iOS-only knobs:
 * `syncStoreKitTransactions`, `appleMerchantId`, `maxPreloadedWebViews`,
 * `applePaySetupBehavior`. These are silently dropped on Android with a
 * single info-level log — there's no Android equivalent (Apple Pay setup
 * sheet, StoreKit sync flag, iOS WebView preloading). The plan's spec
 * (`docs/superpowers/plans/2026-05-12-...md:1988-1991`) is the source for
 * this behaviour.
 *
 * `preloadCheckout` maps directly to [ZeroSettleConfig.preloadCheckout].
 *
 * ## bootstrap → identify(User) shim
 *
 * Dart still ships a 1.2.x-compatible `bootstrap({userId})` call. The
 * Android SDK does not expose a public `bootstrap()` — the post-A1 surface
 * folds bootstrap into `identify(Identity.User)`. We route the legacy call
 * to `identify(.user)` so adopters on the old contract keep working until
 * they migrate to `identify()` at the Dart layer.
 *
 * ## transferStoreKitOwnershipToCurrentUser
 *
 * iOS-only on the wire. The Android Play analogue
 * (`transferPlayOwnershipToCurrentUser`) takes `(productId,
 * originalTransactionId)` — Dart's signature only sends `productId`, so
 * cross-routing would silently drop the required second arg. Return a
 * tagged `not_implemented` error so Dart's `_wrap` surfaces a
 * `PlatformException` callers can pattern-match. Plan F10 confirms this
 * is the intended Android behaviour.
 *
 * ## suspend dispatch
 *
 * `identify` (and the legacy `bootstrap` shim) suspend on the SDK side;
 * they launch on [HandlerDependencies.scope] and resolve the `Result` from
 * inside the coroutine. `logout` and `setCustomer` are technically
 * synchronous on the SDK, but their internals `runBlocking` against
 * DataStore — launching on the scope avoids stalling Flutter's platform
 * thread while DataStore flushes. State queries
 * (`getCurrentUserId`/`getIsBootstrapped`/`getIsConfigured`) read
 * StateFlow `.value` synchronously.
 */
internal class IdentityHandler(private val deps: HandlerDependencies) {

    /**
     * Dispatch [call] if this handler owns its method. Returns `true` if
     * the call was consumed (a [result] callback has been issued or is
     * pending from a launched coroutine), `false` if the method is not in
     * this handler's surface so the plugin can fall through to the next
     * domain handler / final `notImplemented()`.
     */
    fun handle(call: MethodCall, result: MethodChannel.Result): Boolean {
        when (call.method) {
            "configure" -> configure(call, result)
            "bootstrap" -> bootstrap(call, result)
            "identify" -> identify(call, result)
            "logout" -> logout(result)
            "setCustomer" -> setCustomer(call, result)
            "transferStoreKitOwnershipToCurrentUser" ->
                transferStoreKitOwnershipToCurrentUser(result)
            "getCurrentUserId" -> getCurrentUserId(result)
            "getIsBootstrapped" -> getIsBootstrapped(result)
            "getIsConfigured" -> getIsConfigured(result)
            else -> return false
        }
        return true
    }

    // ── configure ──────────────────────────────────────────────────────

    private fun configure(call: MethodCall, result: MethodChannel.Result) {
        val publishableKey = call.argument<String>("publishableKey")
        if (publishableKey == null) {
            result.error("INVALID_ARGUMENTS", "publishableKey is required", null)
            return
        }
        val context = deps.applicationContextProvider()
        if (context == null) {
            result.error(
                "plugin_not_attached",
                "configure() called before plugin attached to engine",
                null,
            )
            return
        }
        // iOS-only knobs Dart still sends — log once and drop. preloadCheckout
        // is the only knob with a real Android counterpart on ZeroSettleConfig.
        //
        // `syncStoreKitTransactions` is excluded from the watch list because
        // Dart's `configure({...})` always sends it (default `true`, not
        // null-gated like `appleMerchantId`). Logging on every call would be
        // noisy and uninformative — the wire shape includes it by design.
        val droppedArgs = listOf(
            "appleMerchantId",
            "maxPreloadedWebViews",
            "applePaySetupBehavior",
        ).filter { call.argument<Any?>(it) != null }
        if (droppedArgs.isNotEmpty()) {
            Log.i(
                "ZeroSettle",
                "configure: iOS-only args dropped on Android: $droppedArgs",
            )
        }
        val preloadCheckout = call.argument<Boolean>("preloadCheckout") ?: false
        try {
            ZeroSettle.configure(
                context = context,
                config = ZeroSettleConfig(
                    publishableKey = publishableKey,
                    preloadCheckout = preloadCheckout,
                ),
            )
            result.success(null)
        } catch (e: Throwable) {
            result.sendError(e)
        }
    }

    // ── bootstrap (legacy 1.2.x shim → identify(.user)) ────────────────

    private fun bootstrap(call: MethodCall, result: MethodChannel.Result) {
        val userId = call.argument<String>("userId")
        if (userId == null) {
            result.error(
                "INVALID_ARGUMENTS",
                "userId is required for legacy bootstrap()",
                null,
            )
            return
        }
        deps.scope.launch {
            val sdkResult = runCatching {
                ZeroSettle.identify(Identity.User(id = userId, name = null, email = null))
            }
            sdkResult.fold(
                onSuccess = { res ->
                    res.fold(
                        onSuccess = { catalog ->
                            // The Dart `bootstrap()` parser expects a non-null
                            // Map. `identify(.user)` always returns a catalog
                            // on success, so an empty fallback only fires if
                            // the SDK contract changes.
                            result.success(catalog?.toFlutterMap() ?: emptyMap<String, Any?>())
                        },
                        onFailure = { result.sendError(it) },
                    )
                },
                onFailure = { result.sendError(it) },
            )
        }
    }

    // ── identify ───────────────────────────────────────────────────────

    private fun identify(call: MethodCall, result: MethodChannel.Result) {
        val type = call.argument<String>("type")
        if (type == null) {
            result.error("INVALID_ARGUMENTS", "type is required", null)
            return
        }
        val identity: Identity = when (type) {
            "user" -> {
                val id = call.argument<String>("id")
                if (id == null) {
                    result.error(
                        "INVALID_ARGUMENTS",
                        "id is required for user identity",
                        null,
                    )
                    return
                }
                Identity.User(
                    id = id,
                    name = call.argument("name"),
                    email = call.argument("email"),
                )
            }
            "anonymous" -> Identity.Anonymous
            "deferred" -> Identity.Deferred
            else -> {
                result.error(
                    "INVALID_ARGUMENTS",
                    "unknown identity type: $type",
                    null,
                )
                return
            }
        }
        deps.scope.launch {
            val sdkResult = runCatching { ZeroSettle.identify(identity) }
            sdkResult.fold(
                onSuccess = { res ->
                    res.fold(
                        // Deferred returns Result.success(null) — Dart's
                        // parser expects a nullable Map and tolerates this.
                        onSuccess = { catalog -> result.success(catalog?.toFlutterMap()) },
                        onFailure = { result.sendError(it) },
                    )
                },
                onFailure = { result.sendError(it) },
            )
        }
    }

    // ── logout ─────────────────────────────────────────────────────────

    private fun logout(result: MethodChannel.Result) {
        // `ZeroSettle.logout()` is synchronous from a Kotlin signature
        // perspective but internally `runBlocking`s against IdentityStore
        // (DataStore). Launch on the plugin scope so we don't stall the
        // Flutter platform thread.
        deps.scope.launch {
            try {
                ZeroSettle.logout()
                result.success(null)
            } catch (e: Throwable) {
                result.sendError(e)
            }
        }
    }

    // ── setCustomer ────────────────────────────────────────────────────

    private fun setCustomer(call: MethodCall, result: MethodChannel.Result) {
        val name = call.argument<String>("name")
        val email = call.argument<String>("email")
        // Same DataStore runBlocking note as logout — launch to keep the
        // platform thread responsive.
        deps.scope.launch {
            try {
                ZeroSettle.setCustomer(name = name, email = email)
                result.success(null)
            } catch (e: Throwable) {
                result.sendError(e)
            }
        }
    }

    // ── transferStoreKitOwnershipToCurrentUser (iOS-only) ──────────────

    private fun transferStoreKitOwnershipToCurrentUser(result: MethodChannel.Result) {
        // The Dart method targets the iOS StoreKit ownership-transfer flow
        // (`Identity → claim a Storekit purchase`). The Android Play
        // analogue `transferPlayOwnershipToCurrentUser` takes
        // `(productId, originalTransactionId)` — Dart's signature only
        // carries `productId`, so cross-routing would silently drop the
        // required second arg. The right Android API is `claimEntitlement`
        // via the pending-claims surface (F11). Return a tagged error so
        // Dart's `_wrap` surfaces a PlatformException callers can match on.
        result.error(
            "not_implemented",
            "transferStoreKitOwnershipToCurrentUser is iOS-only on Android. " +
                "Use the pending-claims flow (claim_entitlement) instead.",
            null,
        )
    }

    // ── State queries (synchronous StateFlow reads) ────────────────────

    private fun getCurrentUserId(result: MethodChannel.Result) {
        result.success(ZeroSettle.currentUserId.value)
    }

    private fun getIsBootstrapped(result: MethodChannel.Result) {
        result.success(ZeroSettle.isBootstrapped.value)
    }

    private fun getIsConfigured(result: MethodChannel.Result) {
        result.success(ZeroSettle.isConfigured.value)
    }
}

/**
 * Map a [Throwable] from an SDK boundary to a Flutter `result.error`.
 *
 * The error-code wire contract mirrors the plan's spec
 * (`docs/superpowers/plans/2026-05-12-...md:2058-2069`); SDKs and
 * adopters can pattern-match these. Unknown exception types fall through
 * to `sdk_error`.
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
