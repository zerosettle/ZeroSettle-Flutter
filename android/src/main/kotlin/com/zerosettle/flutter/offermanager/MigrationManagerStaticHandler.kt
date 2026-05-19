package com.zerosettle.flutter.offermanager

import com.zerosettle.flutter.ext.sendError
import com.zerosettle.sdk.ZeroSettle
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/**
 * `MethodCallHandler` for the headless `zerosettle/migration_manager_static`
 * channel. Routes Dart `ZeroSettleMigrationManagerStatics` calls (see
 * `lib/managers/migration_manager.dart:163–185`) to the SDK's offer
 * dismissal store.
 *
 * ## Android vs iOS mapping
 *
 * On iOS, `ZSMigrationManager` and `ZSOfferManager` have **distinct**
 * UserDefaults stores (keys `com.zerosettle.migrateTipDismissed` vs
 * `com.zerosettle.offerTipDismissed`). On Android, the SDK has a single
 * `OfferDismissalStore` backing both. Because the two stores are the same
 * object on Android, `isPermanentlyDismissed` and `setDismissed` forward
 * to `ZeroSettle.isOfferPermanentlyDismissed` / `setOfferDismissed`.
 *
 * ## `resetDismissedState` — deliberate no-op
 *
 * Calling `ZeroSettle.resetOfferDismissedState()` here would reset *both*
 * migration-tip and offer-tip dismissals simultaneously, conflating two iOS
 * surfaces that have independent stores. A no-op is the honest behaviour;
 * the offer-static channel's `resetDismissedState` handles the canonical
 * reset. When the Android SDK adds a migration-specific dismissal store,
 * this handler can be updated to call it. Mirrors the rationale documented
 * in `MiscHandler.kt:108–118` for the `resetMigrateTipState` method call.
 *
 * **Error-code convention:** uppercase `INVALID_ARGUMENTS` matches iOS
 * (`ZeroSettlePlugin.swift:356, 363`) and [OfferManagerStaticHandler].
 */
class MigrationManagerStaticHandler(private val scope: CoroutineScope) : MethodChannel.MethodCallHandler {

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
                        result.sendError(e)
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
                        result.sendError(e)
                    }
                }
            }
            "resetDismissedState" -> {
                // No-op: Android has a single OfferDismissalStore; calling
                // resetOfferDismissedState() here would conflate the iOS-distinct
                // migration-tip and offer-tip dismissal stores. The offer_manager_static
                // channel's resetDismissedState handles the canonical full reset.
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}
