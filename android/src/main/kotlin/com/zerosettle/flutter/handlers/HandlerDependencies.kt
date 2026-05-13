package com.zerosettle.flutter.handlers

import android.app.Activity
import android.content.Context
import kotlinx.coroutines.CoroutineScope

/**
 * Shared deps threaded into each per-domain `MethodCallHandler`.
 *
 * F7's scaffold owns the plugin-wide [CoroutineScope], the tracked
 * [Activity] (via [activityProvider] so callers always see the current one
 * after config-change reattach), and the cached application [Context] (via
 * [applicationContextProvider] because the plugin lifecycle clears it on
 * detach).
 *
 * F25 added [checkoutEventEmitter] — the seam through which [PurchaseHandler]
 * pushes fabricated `checkoutDid{Begin,Complete,Cancel,Fail}` events onto
 * the `zerosettle/checkout_events` EventChannel. The plugin wires this to
 * the buffered stream handler's `emit(...)`; tests pass a capturing lambda.
 * The default no-op keeps handlers that don't use it (everyone except
 * PurchaseHandler) free of the dependency.
 *
 * F8 is the first consumer; F9-F17 follow the same pattern. Anything a
 * per-domain handler needs beyond this set should be passed as a
 * constructor argument to the handler itself rather than threaded through
 * here — keeps the data class tight and the dependency surface explicit
 * per domain.
 */
internal data class HandlerDependencies(
    val scope: CoroutineScope,
    val activityProvider: () -> Activity?,
    val applicationContextProvider: () -> Context?,
    val checkoutEventEmitter: (Map<String, Any?>) -> Unit = {},
)
