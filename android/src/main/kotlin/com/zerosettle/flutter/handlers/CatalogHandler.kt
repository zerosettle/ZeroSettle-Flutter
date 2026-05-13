package com.zerosettle.flutter.handlers

import com.zerosettle.flutter.ext.sendError
import com.zerosettle.flutter.ext.toFlutterMap
import com.zerosettle.sdk.ZeroSettle
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.launch

/**
 * F9 — catalog + entitlements method-channel handler.
 *
 * Owns six methods Dart calls on the main `zerosettle` channel:
 *   - `fetchProducts` — network refetch of the canonical catalog
 *   - `getProducts` — synchronous read of the cached catalog
 *   - `product` — single-product lookup by id (returns `null` if absent)
 *   - `hasActiveEntitlement` — synchronous boolean per product id
 *   - `getEntitlements` — synchronous read of the cached entitlement list
 *   - `restoreEntitlements` — network refresh of entitlements
 *
 * Wire shapes mirror `ios/zerosettle/Sources/zerosettle/ZeroSettlePlugin.swift`
 * (cases at lines 427-460, 575-592) — Dart's parsers in
 * `lib/zerosettle_method_channel.dart` (lines 100-129, 190-207) see one
 * contract regardless of platform.
 *
 * ## userId arg deviation from iOS
 *
 * Dart sends `userId` on `fetchProducts` and `restoreEntitlements` for
 * platform parity with iOS, whose SDK exposes `fetchProducts(userId:)` and
 * `restoreEntitlements(userId:)` overloads. The Android SDK
 * (`ZeroSettle.fetchProducts()` and `ZeroSettle.restoreEntitlements()`)
 * does NOT take a userId — it reads `currentUserIdOrNull()` internally. We
 * drop the Dart-side `userId` arg with no warning: it's purely a wire-shape
 * artifact for cross-platform code reuse. Callers who haven't called
 * `identify()` first will see `user_not_identified` from the SDK's
 * `Result.failure(ZeroSettleError.UserNotIdentified)` — the right behavior,
 * since `identify()` is Android's canonical way to set the active user
 * (see F8's `bootstrap → identify(.user)` shim for the same pattern).
 *
 * ## Cache reads are always non-null
 *
 * `ZeroSettle.products` and `ZeroSettle.entitlements` are
 * `StateFlow<List<...>>` initialized to `emptyList()` — never null. We map
 * `.value` to a wire-encoded list directly. iOS does the same
 * (`products.map { $0.toFlutterMap() }`).
 *
 * ## product() not-found → null
 *
 * Matches iOS Optional semantics. Dart's `product()` parser
 * (`lib/zerosettle_method_channel.dart:108-113`) treats a null Map as
 * "no such product" rather than throwing.
 *
 * ## hasActiveEntitlement is synchronous
 *
 * The SDK helper at `ZeroSettle.kt:294` is a synchronous filter over the
 * materialized entitlements list — no `scope.launch`. Same for `product`,
 * `getProducts`, `getEntitlements`.
 */
internal class CatalogHandler(private val deps: HandlerDependencies) {

    /**
     * Dispatch [call] if this handler owns its method. Returns `true` if
     * the call was consumed, `false` so the plugin can fall through.
     */
    fun handle(call: MethodCall, result: MethodChannel.Result): Boolean {
        when (call.method) {
            "fetchProducts" -> fetchProducts(result)
            "getProducts" -> getProducts(result)
            "product" -> product(call, result)
            "hasActiveEntitlement" -> hasActiveEntitlement(call, result)
            "getEntitlements" -> getEntitlements(result)
            "restoreEntitlements" -> restoreEntitlements(result)
            else -> return false
        }
        return true
    }

    // ── fetchProducts (network refetch) ─────────────────────────────────

    private fun fetchProducts(result: MethodChannel.Result) {
        // Dart sends `userId` but the Android SDK reads it from
        // `currentUserIdOrNull()` internally — see class doc. No arg parsing.
        deps.scope.launch {
            val sdkResult = runCatching { ZeroSettle.fetchProducts() }
            sdkResult.fold(
                onSuccess = { res ->
                    res.fold(
                        onSuccess = { catalog -> result.success(catalog.toFlutterMap()) },
                        onFailure = { result.sendError(it) },
                    )
                },
                onFailure = { result.sendError(it) },
            )
        }
    }

    // ── getProducts (cache read) ────────────────────────────────────────

    private fun getProducts(result: MethodChannel.Result) {
        // iOS publishes `products.map { $0.toFlutterMap() }` — a List, not the
        // ProductCatalog wrapper. Dart's `getProducts()` parser expects
        // `invokeMethod<List>(...)` — see lib/zerosettle_method_channel.dart:127.
        result.success(ZeroSettle.products.value.map { it.toFlutterMap() })
    }

    // ── product (single lookup) ─────────────────────────────────────────

    private fun product(call: MethodCall, result: MethodChannel.Result) {
        val productId = call.argument<String>("productId")
        if (productId == null) {
            result.error("INVALID_ARGUMENTS", "productId is required", null)
            return
        }
        // ZeroSettle.product(referenceId) is a synchronous convenience
        // accessor — returns null when no cached product matches.
        result.success(ZeroSettle.product(productId)?.toFlutterMap())
    }

    // ── hasActiveEntitlement (cache read, boolean) ──────────────────────

    private fun hasActiveEntitlement(call: MethodCall, result: MethodChannel.Result) {
        val productId = call.argument<String>("productId")
        if (productId == null) {
            result.error("INVALID_ARGUMENTS", "productId is required", null)
            return
        }
        result.success(ZeroSettle.hasActiveEntitlement(productId))
    }

    // ── getEntitlements (cache read) ────────────────────────────────────

    private fun getEntitlements(result: MethodChannel.Result) {
        result.success(ZeroSettle.entitlements.value.map { it.toFlutterMap() })
    }

    // ── restoreEntitlements (network refresh) ───────────────────────────

    private fun restoreEntitlements(result: MethodChannel.Result) {
        // Dart's two parsers (`restoreEntitlements({userId})` and
        // `restoreEntitlementsForCurrentUser()`) both invoke the same
        // platform method — only the args map differs. The Android SDK has
        // a single overload that reads the user from currentUserIdOrNull(),
        // so we ignore the userId arg here just like fetchProducts. The
        // SDK's returned list is the active entitlement set; iOS emits
        // exactly that shape (line 584).
        deps.scope.launch {
            val sdkResult = runCatching { ZeroSettle.restoreEntitlements() }
            sdkResult.fold(
                onSuccess = { res ->
                    res.fold(
                        onSuccess = { entitlements ->
                            result.success(entitlements.map { it.toFlutterMap() })
                        },
                        onFailure = { result.sendError(it) },
                    )
                },
                onFailure = { result.sendError(it) },
            )
        }
    }
}
