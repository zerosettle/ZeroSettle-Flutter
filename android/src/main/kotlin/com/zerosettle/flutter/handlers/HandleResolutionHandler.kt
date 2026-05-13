package com.zerosettle.flutter.handlers

import com.zerosettle.flutter.offermanager.OfferManagerHandleBridge
import com.zerosettle.flutter.offermanager.OfferManagerHandleRegistry
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * F17 — OfferManager / MigrationManager handle resolution.
 *
 * Last per-domain handler in Phase 2. Owns the two Dart `resolveXxxHandle`
 * calls that allocate per-handle channels for the headless manager APIs.
 *
 * | Dart method                        | Android route                                     |
 * | ---------------------------------- | ------------------------------------------------- |
 * | `resolveOfferManagerHandle`        | Allocate via registry, start bridge, return id    |
 * | `resolveMigrationManagerHandle`    | `not_implemented` (see "MigrationManager" below)  |
 *
 * ## `resolveOfferManagerHandle` — allocate + bridge + return handle id
 *
 * Args: `{stripeCustomerId?: String}` — optional, forwarded to
 * `ZeroSettle.offerManager(stripeCustomerId)` at registry-allocate time so the
 * SDK binds the customer once per handle (see [OfferManagerHandleRegistry]).
 *
 * Dispatch:
 *   1. Call `registry.allocate(stripeCustomerId)` → builds the SDK
 *      OfferManager + per-handle method+state channels + supervisor scope.
 *   2. Construct an [OfferManagerHandleBridge] for the new entry and call
 *      `bridge.start()` — this is the wiring step that attaches the
 *      method-channel handler + state-channel stream-handler to the SDK
 *      manager's StateFlows (see F20's bridge KDoc).
 *   3. Return the integer handle id as a String — the Dart wire contract
 *      is `Future<String>` (`lib/zerosettle_method_channel.dart:550-558`),
 *      and Dart's [OfferManager.fromHandleId] / [MigrationManager.fromHandleId]
 *      use the id verbatim to build per-handle channel names
 *      (`zerosettle/offer_manager_<id>` / `..._state`). Returning the id as
 *      a String matches iOS, which returns `UUID().uuidString` from the same
 *      method.
 *
 * Dart never receives the channel names directly — both sides agree on the
 * `zerosettle/offer_manager_<id>` / `zerosettle/offer_manager_<id>_state`
 * pattern. Returning anything other than the bare id would silently break
 * the per-handle wiring; the test suite asserts the wire-contract String
 * shape.
 *
 * Bridge lifecycle: `bridge.start()` attaches handlers but doesn't manage
 * teardown — when Dart calls `disposeHandle` on the per-handle method
 * channel, the bridge's `onDispose` callback fires `registry.dispose(id)`,
 * which cancels the per-handle scope and detaches both channel handlers
 * (see [OfferManagerHandleRegistry.dispose]).
 *
 * ## `resolveMigrationManagerHandle` — `not_implemented` on Android
 *
 * Android SDK has no `MigrationManager` class — migration is folded into
 * `OfferManager` (see `ZeroSettle-Android` SDK 1.3.4+, where `OfferManager`
 * is a strict superset covering migration, StoreKit→web upgrade, and
 * web→web upgrade flows). The Dart wire's `MigrationManager` is annotated
 * `@Deprecated` in 1.4.0 pointing adopters at `OfferManager` via
 * `ZeroSettle.offerManager()`.
 *
 * Why not alias to `OfferManager` (Option B)? Dart's [MigrationManager]
 * hard-codes its per-handle channel-name pattern as
 * `zerosettle/migration_manager_<id>` (see
 * `lib/managers/migration_manager.dart:43-47`) — distinct from
 * OfferManager's `zerosettle/offer_manager_<id>`. Aliasing would require
 * either a parallel `MigrationManagerHandleBridge` that listens on the
 * `migration_manager_*` channel prefix or breaking changes to Dart's
 * MigrationManager. Both are heavier than the value: Dart's MigrationManager
 * is already `@Deprecated` with explicit migration guidance.
 *
 * The plugin scaffold (F7) documents the per-handle migration-manager
 * channels (`zerosettle/migration_manager_<id>`) and the
 * `zerosettle/migration_manager_static` channel as Known gaps that
 * "fall through Flutter's default `notImplemented()` until a future task
 * either wires it or removes the Dart side." F17 follows the same pattern
 * for the resolution call itself: error with a clear pointer to the
 * supported alternative.
 *
 * ## Wire-contract symmetry note
 *
 * iOS returns `UUID().uuidString` (e.g. `"61F5...AB"`); Android returns the
 * integer registry id as a String (e.g. `"1"`, `"2"`, …). Dart treats the
 * value as opaque — both shapes are valid `Future<String>` per
 * `lib/zerosettle_platform_interface.dart:363-367`. The only contract the
 * id must honour is uniqueness within the plugin instance, which the
 * registry's `AtomicInteger` already provides.
 */
internal class HandleResolutionHandler(
    @Suppress("unused") private val deps: HandlerDependencies,
    private val registry: OfferManagerHandleRegistry,
) {

    /**
     * Dispatch [call] if this handler owns its method. Returns `true` if
     * the call was consumed, `false` if the method is not in this handler's
     * surface so the plugin can fall through.
     */
    fun handle(call: MethodCall, result: MethodChannel.Result): Boolean {
        when (call.method) {
            "resolveOfferManagerHandle" -> resolveOfferManagerHandle(call, result)
            "resolveMigrationManagerHandle" -> resolveMigrationManagerHandle(result)
            else -> return false
        }
        return true
    }

    // ── resolveOfferManagerHandle — allocate + bridge.start + return id ──

    private fun resolveOfferManagerHandle(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        // Dart's wire shape: `{stripeCustomerId?: String}` — optional.
        // The registry's `allocate(stripeCustomerId: String?)` accepts null
        // and forwards as-is to `ZeroSettle.offerManager(stripeCustomerId)`.
        val stripeCustomerId = call.argument<String>("stripeCustomerId")

        try {
            val entry = registry.allocate(stripeCustomerId)
                ?: return result.error(
                    "sdk_error",
                    "OfferManagerHandleRegistry refused to allocate a handle " +
                        "(registry already disposed?).",
                    null,
                )

            // F20's bridge wires the method + state channels owned by the
            // registry entry. `onDispose` is invoked by the per-handle
            // `disposeHandle` Dart call and tears down the channels +
            // supervisor scope via the registry.
            val bridge = OfferManagerHandleBridge(
                entry = entry,
                onDispose = { registry.dispose(entry.id) },
            )
            try {
                bridge.start()
            } catch (e: Throwable) {
                // bridge.start() shouldn't realistically throw — it just
                // installs MethodChannel + EventChannel handlers — but if it
                // does, we'd leak a registry entry. Dispose to keep the
                // registry consistent before propagating the failure.
                registry.dispose(entry.id)
                throw e
            }

            // Wire contract: `Future<String>` matching iOS's
            // `UUID().uuidString`. Stringify the integer id; Dart treats it
            // as opaque (used verbatim in channel-name construction —
            // `lib/managers/offer_manager.dart:37-39`).
            result.success(entry.id.toString())
        } catch (e: Throwable) {
            result.sendError(e)
        }
    }

    // ── resolveMigrationManagerHandle — Android has no MigrationManager ──

    private fun resolveMigrationManagerHandle(result: MethodChannel.Result) {
        result.error(
            "not_implemented",
            "MigrationManager is iOS-only on Android — the Android SDK folds " +
                "migration into OfferManager (a strict superset covering " +
                "migration, StoreKit→web upgrade, and web→web upgrade flows). " +
                "Dart's MigrationManager is @Deprecated in 1.4.0; call " +
                "`ZeroSettle.instance.offerManager()` instead.",
            null,
        )
    }
}
