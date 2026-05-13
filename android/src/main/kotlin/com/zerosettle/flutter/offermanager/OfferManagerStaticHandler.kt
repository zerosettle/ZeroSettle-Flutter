package com.zerosettle.flutter.offermanager

import com.zerosettle.sdk.ZeroSettle
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/**
 * `MethodCallHandler` for the headless `zerosettle/offer_manager_static`
 * channel. Routes Dart `ZeroSettleOfferManagerStatics` calls (see
 * `lib/managers/offer_manager.dart:198-201`) to the SDK's static dismissal
 * helpers added in Phase 1 Task A4 — `ZeroSettle.isOfferPermanentlyDismissed`,
 * `setOfferDismissed`, `resetOfferDismissedState` (see
 * `ZeroSettle-Android/core/src/main/kotlin/com/zerosettle/sdk/ZeroSettle.kt:671-700`).
 *
 * The channel is shared across the whole plugin (one channel, no per-handle
 * id) — `ZeroSettleOfferManagerStatics` is class-level on the Dart side.
 * Mirrors iOS's handler at `ZeroSettlePlugin.swift:228-258`.
 *
 * The SDK helpers are `suspend` (they read/write `OfferDismissalStore`, which
 * uses DataStore). The handler launches on the [scope] injected by the plugin
 * core so the result is delivered after the suspend call returns; the captured
 * `result` reference is fulfilled from the coroutine.
 *
 * **Error-code convention:** uppercase `INVALID_ARGUMENTS` matches iOS
 * (`ZeroSettlePlugin.swift:237, 245`) and is the wire contract Dart can
 * pattern-match against if needed. `sdk_error` is the catch-all for SDK
 * throws (most likely `ZeroSettleError.NotConfigured` if the host app forgot
 * `configure(...)`).
 */
class OfferManagerStaticHandler(private val scope: CoroutineScope) : MethodChannel.MethodCallHandler {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isPermanentlyDismissed" -> {
                val userId = call.argument<String>("userId")
                if (userId == null) {
                    result.error("INVALID_ARGUMENTS", "userId required", null)
                    return
                }
                scope.launch {
                    try {
                        result.success(ZeroSettle.isOfferPermanentlyDismissed(userId))
                    } catch (e: Throwable) {
                        result.error("sdk_error", e.message ?: e::class.simpleName, null)
                    }
                }
            }
            "setDismissed" -> {
                val userId = call.argument<String>("userId")
                val dismissed = call.argument<Boolean>("dismissed")
                if (userId == null || dismissed == null) {
                    result.error("INVALID_ARGUMENTS", "userId + dismissed required", null)
                    return
                }
                scope.launch {
                    try {
                        ZeroSettle.setOfferDismissed(userId, dismissed)
                        result.success(null)
                    } catch (e: Throwable) {
                        result.error("sdk_error", e.message ?: e::class.simpleName, null)
                    }
                }
            }
            "resetDismissedState" -> {
                scope.launch {
                    try {
                        ZeroSettle.resetOfferDismissedState()
                        result.success(null)
                    } catch (e: Throwable) {
                        result.error("sdk_error", e.message ?: e::class.simpleName, null)
                    }
                }
            }
            else -> result.notImplemented()
        }
    }
}
