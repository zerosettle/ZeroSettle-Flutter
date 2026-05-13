package com.zerosettle.flutter.handlers

import com.zerosettle.flutter.ext.toFlutterMap
import com.zerosettle.sdk.ZeroSettle
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * F11 — pending-claims domain handler.
 *
 * Owns one method Dart calls on the main `zerosettle` channel:
 *   - `getPendingClaims` — synchronous read of
 *     [ZeroSettle.pendingClaims] (a `StateFlow<List<PendingClaim>>`),
 *     mapped to the wire shape via `PendingClaim.toFlutterMap()` from
 *     `ext/ModelToFlutterMap.kt`.
 *
 * Wire-shape mirror: see iOS dispatch at
 * `ios/zerosettle/Sources/zerosettle/ZeroSettlePlugin.swift:892` and the Dart
 * decoder at `lib/zerosettle_method_channel.dart:276` (`PendingClaim.fromMap`
 * via the public surface).
 *
 * ## No coroutine launch
 *
 * Like [CatalogHandler.getProducts] / [CatalogHandler.getEntitlements], this
 * is a snapshot read of an SDK-owned `StateFlow` — `.value` is non-suspending
 * and never throws. We map and reply on the calling thread; nothing needs
 * [HandlerDependencies.scope]. The handler still takes [HandlerDependencies]
 * for allocation-pattern parity with F8/F9/F10 (and so future expansion —
 * e.g., a hypothetical `claimPendingEntitlement` suspend method — has the
 * scope available without changing the constructor).
 *
 * ## "No auto-claim" rule
 *
 * Per the SDK doc on `PendingClaim`: surfacing claims is read-only; resolving
 * them must be an explicit user-initiated `claimEntitlement` call. This
 * handler only exposes the read snapshot — there's no mutation surface here
 * by design.
 */
internal class PendingClaimsHandler(@Suppress("unused") private val deps: HandlerDependencies) {

    /**
     * Dispatch [call] if this handler owns its method. Returns `true` if
     * the call was consumed, `false` if the method is not in this handler's
     * surface so the plugin can fall through.
     */
    fun handle(call: MethodCall, result: MethodChannel.Result): Boolean {
        when (call.method) {
            "getPendingClaims" -> getPendingClaims(result)
            else -> return false
        }
        return true
    }

    // ── getPendingClaims (StateFlow snapshot) ──────────────────────────

    private fun getPendingClaims(result: MethodChannel.Result) {
        result.success(ZeroSettle.pendingClaims.value.map { it.toFlutterMap() })
    }
}
