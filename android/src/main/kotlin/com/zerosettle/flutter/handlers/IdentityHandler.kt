package com.zerosettle.flutter.handlers

import android.util.Log
import com.zerosettle.flutter.ext.sendError
import com.zerosettle.flutter.ext.toFlutterMap
import com.zerosettle.sdk.Identity
import com.zerosettle.sdk.ZeroSettle
import com.zerosettle.sdk.ZeroSettleConfig
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
 * ## Platform-specific configure args
 *
 * Dart's `configure({...})` carries several iOS-only knobs:
 * `syncStoreKitTransactions`, `appleMerchantId`, `maxPreloadedWebViews`,
 * `applePaySetupBehavior`. These are silently dropped on Android with a
 * single info-level log — there's no Android equivalent (Apple Pay setup
 * sheet, StoreKit sync flag, iOS WebView preloading). The plan's spec
 * (`docs/superpowers/plans/2026-05-12-...md:1988-1991`) is the source for
 * this behaviour.
 *
 * Symmetrically, Dart also carries three Android-only knobs that map to
 * [ZeroSettleConfig]: `playLicenseKey` (Play Billing signature
 * verification), `syncPlayPurchases` (Play Billing purchase listener
 * toggle), `strictAck` (block ack until backend sync confirms). These
 * are dropped on iOS with a comment; on Android they forward through.
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
 * ## transferStoreKitOwnershipToCurrentUser / transferPlayOwnershipToCurrentUser
 *
 * Each Dart wire method targets one platform's store. iOS receives
 * `transferStoreKitOwnershipToCurrentUser({productId})`; Android receives
 * `transferPlayOwnershipToCurrentUser({productId, originalTransactionId})`.
 * The Android-side StoreKit method returns `not_implemented`; the iOS-side
 * Play method returns `not_implemented` symmetrically. Plan F10 + D2
 * confirm this is the intended Android behaviour — the Android Play
 * analogue needs `originalTransactionId` (the Play purchase token) in
 * addition to `productId`, so cross-routing the StoreKit signature would
 * silently drop a required arg.
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
            "transferPlayOwnershipToCurrentUser" ->
                transferPlayOwnershipToCurrentUser(call, result)
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
        // Android-specific Play knobs (mirrored on the Dart side; iOS drops
        // them). All three have sensible defaults baked into
        // [ZeroSettleConfig] so missing args fall through to the SDK
        // defaults rather than overwriting with `null`/`false`.
        val playLicenseKey = call.argument<String>("playLicenseKey")
        val syncPlayPurchases = call.argument<Boolean>("syncPlayPurchases") ?: true
        val strictAck = call.argument<Boolean>("strictAck") ?: false
        // Pick up the pending baseUrlOverride that the Dart side staged via
        // setBaseUrlOverride(...) before this configure call. Required for
        // staging / ngrok dev wiring — Android's ZeroSettleConfig is
        // immutable, so we consume the override here. See BaseUrlOverrideStore.
        val baseUrlOverride = BaseUrlOverrideStore.consume()
        if (baseUrlOverride != null) {
            Log.i("ZeroSettle", "configure: applying baseUrlOverride=$baseUrlOverride")
        }
        try {
            ZeroSettle.configure(
                context = context,
                config = ZeroSettleConfig(
                    publishableKey = publishableKey,
                    preloadCheckout = preloadCheckout,
                    baseUrlOverride = baseUrlOverride,
                    playLicenseKey = playLicenseKey,
                    syncPlayPurchases = syncPlayPurchases,
                    strictAck = strictAck,
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
        // (`Identity → claim a Storekit purchase`). On Android the peer
        // wire method is `transferPlayOwnershipToCurrentUser` (below),
        // which carries the additional `originalTransactionId` arg the
        // Play API requires. Return a tagged error so Dart's `_wrap`
        // surfaces a PlatformException callers can match on.
        result.error(
            "not_implemented",
            "transferStoreKitOwnershipToCurrentUser is iOS-only. " +
                "On Android, use transferPlayOwnershipToCurrentUser(productId, originalTransactionId).",
            null,
        )
    }

    // ── transferPlayOwnershipToCurrentUser ─────────────────────────────

    private fun transferPlayOwnershipToCurrentUser(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val productId = call.argument<String>("productId")
        val originalTransactionId = call.argument<String>("originalTransactionId")
        if (productId == null) {
            result.error("INVALID_ARGUMENTS", "productId is required", null)
            return
        }
        if (originalTransactionId == null) {
            result.error("INVALID_ARGUMENTS", "originalTransactionId is required", null)
            return
        }
        // Suspending SDK call — `ZeroSettle.transferPlayOwnershipToCurrentUser`
        // hits the backend's claim-entitlement endpoint. Launch on the
        // shared plugin scope so we don't stall the Flutter platform
        // thread; the result is folded back through the standard wire
        // contract (success(null) or sendError(typed code)).
        deps.scope.launch {
            val sdkResult = runCatching {
                ZeroSettle.transferPlayOwnershipToCurrentUser(productId, originalTransactionId)
            }
            sdkResult.fold(
                onSuccess = { res ->
                    res.fold(
                        onSuccess = { result.success(null) },
                        onFailure = { err -> result.sendError(err) },
                    )
                },
                onFailure = { err -> result.sendError(err) },
            )
        }
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
