package com.zerosettle.flutter.handlers

import com.zerosettle.flutter.ext.sendError
import com.zerosettle.sdk.ZeroSettle
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * F15 — iOS Apple-Pay stubs handler.
 *
 * Owns four iOS-specific methods Dart calls on the main `zerosettle`
 * channel. Apple Pay (and StoreKit) have no Android analogue; each method
 * returns the closest "feature not present" answer the Dart wire contract
 * tolerates without crashing the caller.
 *
 * | Dart method                  | Android return                                    | Wire shape   |
 * | ---------------------------- | ------------------------------------------------- | ------------ |
 * | `recommendedAppAccountToken` | `ZeroSettle.recommendedAppAccountToken().toString()` | `String`     |
 * | `presentApplePaySetup`       | `error("not_implemented", ...)`                   | error        |
 * | `getIsApplePayOnly`          | `success(false)`                                  | `Boolean`    |
 * | `getApplePayState`           | `success("unavailable")`                          | `String`     |
 *
 * Wire shapes were cross-checked against `lib/zerosettle_method_channel.dart`
 * and `ios/zerosettle/Sources/zerosettle/ZeroSettlePlugin.swift`.
 *
 * ## `recommendedAppAccountToken` — typed UUID pass-through
 *
 * The Android SDK exposes `ZeroSettle.recommendedAppAccountToken(): UUID`
 * (see `core/src/main/kotlin/com/zerosettle/sdk/ZeroSettle.kt`) which
 * derives a deterministic UUID from `(userId, packageName)`. iOS Kit's
 * equivalent returns the same value as a String for the StoreKit
 * `appAccountToken` API; on Android there's no Apple Pay flow, but the
 * UUID is still useful for cross-platform analytics correlation and as a
 * stable per-(user, app) token. The Dart facade docstring already says
 * "on Android, derives the same UUID from (userId, packageName) — useful
 * for analytics correlation", so this is exactly in-contract.
 *
 * Throws `UserNotIdentified` / `NotConfigured` when called before
 * `identify(...)` / `configure(...)`; the `runCatching` + `sendError`
 * pattern surfaces those as typed `PlatformException`s on the Dart side.
 *
 * The other three methods are null-tolerant on the Dart side
 * (`result ?? 'unavailable'` for `getApplePayState`, `result ?? false` for
 * `getIsApplePayOnly`, `Future<void>` for `presentApplePaySetup`) so they
 * follow the plan as written.
 *
 * ## Why `getApplePayState` returns the string `"unavailable"`, not an error
 *
 * The plugin header doc on [com.zerosettle.flutter.ZeroSettlePlugin] (the
 * "Known gaps" section) pins the Android contract to the literal string
 * `"unavailable"`. Returning `not_implemented` would break any adopter that
 * switches on the Dart-side `ApplePayAvailabilityState` enum (`"ready"` /
 * `"setupRequired"` / `"unavailable"`).
 *
 * ## Why `getIsApplePayOnly` returns `false`, not an error
 *
 * It's a Boolean predicate the Dart side uses for branching — "is the
 * merchant Apple-Pay-only?". Android is never Apple-Pay-only, so the
 * answer is simply `false`. The Dart caller treats it as a value, not a
 * capability check, so an error here would force Apple-Pay-only branches
 * onto adopters who didn't gate by platform.
 *
 * ## `HandlerDependencies` constructor arg
 *
 * Threaded in for consistency with every other F8–F13 handler even though
 * F15 doesn't use scope, activity, or context. Keeps the per-domain
 * handler constructor surface uniform; if a future task adds (e.g.) a
 * native Apple-Pay availability sniffer it can read deps without a
 * constructor refactor.
 */
internal class ApplePayStubsHandler(@Suppress("unused") private val deps: HandlerDependencies) {

    /**
     * Dispatch [call] if this handler owns its method. Returns `true` if
     * the call was consumed (a [result] callback has been issued), `false`
     * if the method is not in this handler's surface so the plugin can fall
     * through to the next handler / WIP-error dispatch.
     */
    fun handle(call: MethodCall, result: MethodChannel.Result): Boolean {
        when (call.method) {
            "recommendedAppAccountToken" ->
                runCatching { ZeroSettle.recommendedAppAccountToken().toString() }
                    .fold(
                        onSuccess = { result.success(it) },
                        onFailure = { result.sendError(it) },
                    )
            "presentApplePaySetup" ->
                result.error(
                    "not_implemented",
                    "presentApplePaySetup is iOS-only (Apple Wallet); no Android analogue. " +
                        "Gate the call with Platform.isIOS.",
                    null,
                )
            "getIsApplePayOnly" -> result.success(false)
            "getApplePayState" -> result.success("unavailable")
            else -> return false
        }
        return true
    }
}
