package com.zerosettle.flutter.handlers

import java.util.concurrent.atomic.AtomicReference

/**
 * Process-level slot for the pending `baseUrlOverride` value.
 *
 * The Dart SDK exposes `setBaseUrlOverride(url)` + `configure(...)` as
 * separate calls. On iOS the override is a `#if DEBUG`-gated mutable
 * static (`ZeroSettle.baseURLOverride`); on Android `ZeroSettleConfig`
 * is immutable and only consulted inside `configure(...)`. This store
 * bridges that gap: [MiscHandler] writes the override before configure
 * runs; [IdentityHandler] reads it when building `ZeroSettleConfig`.
 *
 * The example app's documented pattern is:
 *
 *     await ZeroSettle.instance.setBaseUrlOverride(env.baseUrlOverride);
 *     await ZeroSettle.instance.configure(publishableKey: env.key);
 *
 * `pending` is consumed (cleared) inside configure so a later
 * `setBaseUrlOverride` followed by another configure picks up the new
 * value cleanly, matching the iOS reconfigure story.
 */
internal object BaseUrlOverrideStore {
    private val ref = AtomicReference<String?>(null)

    fun set(url: String?) {
        ref.set(url?.takeIf { it.isNotBlank() })
    }

    fun consume(): String? = ref.getAndSet(null)
}
