package com.zerosettle.flutter.offermanager

import com.zerosettle.flutter.ext.toCompositeStateMap
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.launch

/**
 * Wires a single [OfferManagerHandleRegistry.Entry]'s method + state channels
 * to the SDK's [com.zerosettle.sdk.offers.OfferManager] instance. Constructed
 * once per `allocate`; lifetime tied to the entry's `scope` (cancelled in
 * `registry.dispose(id)`).
 *
 * Mirrors iOS's per-handle handler at `ZeroSettlePlugin.swift:1165-1235` and
 * the `OfferStateStreamHandler` at `ZeroSettlePlugin.swift:1934-2003`.
 *
 * **Method-channel handler** dispatches Dart calls (see Dart wire-contract
 * names in `lib/managers/offer_manager.dart:60-159`) to the SDK manager.
 * Wire-contract → SDK mapping:
 *
 *   - `getState`            -> emit current `toCompositeStateMap()` snapshot
 *   - `present`             -> no-op (Android SDK has no `present()` —
 *                              `OfferManager.kt:32-46` documents auto-bookkeeping;
 *                              the Dart-side method is `@Deprecated`)
 *   - `dismiss`             -> suspend `manager.dismiss()`
 *   - `startCheckout`       -> suspend `manager.checkoutUrl()`; ignores
 *                              `stripeCustomerId` (Android binds it at
 *                              `ZeroSettle.offerManager(stripeCustomerId)` —
 *                              registry allocation)
 *   - `preloadCheckout`     -> returns `null` (iOS-only optimization; honest
 *                              no-op beats faking — the Dart docstring at
 *                              `lib/managers/offer_manager.dart:108-118` says
 *                              "or preloading failed", which we honour)
 *   - `markCheckoutSucceeded` -> suspend `manager.onWebCheckoutSucceeded(transactionId)`
 *                                (A6 overload — `OfferManager.kt:183-186`)
 *   - `showAppleSubscriptionManagement` -> `not_implemented` error
 *                                          (iOS-only; Android genuinely can't —
 *                                          no Play analogue, no parity to fake)
 *   - `disposeHandle`       -> invokes [onDispose] (registry tears down channels)
 *
 * **State-channel stream-handler** subscribes to all five relevant SDK
 * StateFlows (`state`, `offerData`, `isLoading`, `checkoutError`,
 * `pendingCheckoutUrl`) via `combine`, re-emitting a fresh
 * `toCompositeStateMap()` on every change. An immediate first-listen snapshot
 * is pushed so Dart has a value to render before any flow updates fire —
 * matches iOS at `ZeroSettlePlugin.swift:1955`.
 *
 * `pendingCheckoutUrl` does NOT appear in the emitted Map (the Dart parser
 * doesn't read it), but we still include it in the `combine` so a checkout-URL
 * transition contributes to the re-emit signal — matches iOS, which subscribes
 * to all 5 published properties.
 */
class OfferManagerHandleBridge(
    private val entry: OfferManagerHandleRegistry.Entry,
    private val onDispose: () -> Unit,
) {

    fun start() {
        entry.methodChannel.setMethodCallHandler { call, result ->
            onMethodCall(call, result)
        }
        entry.stateChannel.setStreamHandler(object : EventChannel.StreamHandler {
            private var collectionJob: Job? = null

            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                if (events == null) return
                // Immediate snapshot so the Dart side has a value to render
                // before any flow updates fire (matches iOS at
                // ZeroSettlePlugin.swift:1955).
                events.success(entry.manager.toCompositeStateMap())
                // Re-emit on any source-flow change. `combine` only fires once
                // every source has a value — all five are MutableStateFlows on
                // the SDK side so each has an initial value at construction.
                collectionJob = combine(
                    entry.manager.state,
                    entry.manager.offerData,
                    entry.manager.isLoading,
                    entry.manager.checkoutError,
                    entry.manager.pendingCheckoutUrl,
                ) { _, _, _, _, _ -> entry.manager.toCompositeStateMap() }
                    .onEach { events.success(it) }
                    .launchIn(entry.scope)
            }

            override fun onCancel(arguments: Any?) {
                collectionJob?.cancel()
                collectionJob = null
            }
        })
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getState" -> {
                result.success(entry.manager.toCompositeStateMap())
            }
            "present" -> {
                // No-op: Android's OfferManager has no `present()` — the modern
                // bookkeeping path runs internally (OfferManager.kt:16-19). The
                // Dart-side method is `@Deprecated` (offer_manager.dart:68).
                // Returning success matches the Dart contract so legacy callers
                // don't see a spurious failure.
                result.success(null)
            }
            "dismiss" -> {
                entry.scope.launch {
                    try {
                        entry.manager.dismiss()
                        result.success(null)
                    } catch (e: Throwable) {
                        result.error("offer_error", e.message ?: e::class.simpleName, null)
                    }
                }
            }
            "startCheckout" -> {
                // Dart sends an optional `stripeCustomerId` arg; Android binds
                // the customer at `ZeroSettle.offerManager(stripeCustomerId)`
                // (registry allocate time) so it is intentionally unused here.
                @Suppress("UNUSED_VARIABLE")
                val stripeCustomerId = call.argument<String>("stripeCustomerId")
                entry.scope.launch {
                    val r = entry.manager.checkoutUrl()
                    r.fold(
                        onSuccess = { url -> result.success(url) },
                        onFailure = { err ->
                            result.error(
                                "offer_error",
                                err.message ?: err::class.simpleName,
                                null,
                            )
                        },
                    )
                }
            }
            "preloadCheckout" -> {
                // iOS-only optimization. The Dart docstring tolerates null
                // ("or preloading failed", offer_manager.dart:108-118).
                result.success(null)
            }
            "markCheckoutSucceeded" -> {
                val transactionId = call.argument<String>("transactionId")
                entry.scope.launch {
                    try {
                        entry.manager.onWebCheckoutSucceeded(transactionId)
                        result.success(null)
                    } catch (e: Throwable) {
                        result.error("offer_error", e.message ?: e::class.simpleName, null)
                    }
                }
            }
            "showAppleSubscriptionManagement" -> {
                // Genuinely iOS-only. Use a tagged error (not notImplemented)
                // so adopter logs distinguish "known but inapplicable" from
                // "unknown method".
                result.error(
                    "not_implemented",
                    "showAppleSubscriptionManagement is iOS-only; Android has no analogue",
                    null,
                )
            }
            "disposeHandle" -> {
                onDispose()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}
