package com.zerosettle.flutter.handlers

import com.zerosettle.flutter.ext.toFlutterMap
import com.zerosettle.sdk.ZeroSettle
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.launch

/**
 * Task 5 — pending-actions domain handler.
 *
 * Owns two methods Dart calls on the main `zerosettle` channel:
 *   - `getPendingActions` — synchronous read of
 *     [ZeroSettle.pendingActions] (a `StateFlow<List<PendingAction>>`),
 *     mapped to the wire shape via `PendingAction.toFlutterMap()` from
 *     `ext/ModelToFlutterMap.kt`.
 *   - `dismissPendingAction` — suspending SDK call that removes an action
 *     by transaction ID. Uses [HandlerDependencies.scope] for the coroutine.
 *
 * Wire shape for `getPendingActions` reply: `List<Map<String, Any?>>`, each
 * map has a `"type"` discriminator (`"migrationCompletedInfo"` /
 * `"manualPlayCancel"`) matching the Dart `PendingAction.fromMap` switch.
 *
 * Wire shape for `dismissPendingAction` args: `{"transactionId": String}`.
 * Uses [ZeroSettle.dismissPendingAction(transactionId)] directly (the
 * overload confirmed at ZeroSettle.kt:1250 — no need to resolve the action
 * object first).
 *
 * ## "Android only" note
 *
 * Pending actions are an Android/Play concept — iOS always returns an empty
 * list from `getPendingActions` and no-ops `dismissPendingAction`. The
 * EventChannel (`zerosettle/pending_actions_updates`) follows the same
 * pattern as the UCB channel: iOS registers a `OneShotEmptyListStreamHandler`
 * that emits `[]` once on subscribe.
 */
internal class PendingActionsHandler(private val deps: HandlerDependencies) {

    /**
     * Dispatch [call] if this handler owns its method. Returns `true` if
     * the call was consumed, `false` if the method is not in this handler's
     * surface so the plugin can fall through.
     */
    fun handle(call: MethodCall, result: MethodChannel.Result): Boolean {
        when (call.method) {
            "getPendingActions" -> getPendingActions(result)
            "dismissPendingAction" -> dismissPendingAction(call, result)
            else -> return false
        }
        return true
    }

    // ── getPendingActions (StateFlow snapshot) ─────────────────────────────

    private fun getPendingActions(result: MethodChannel.Result) {
        result.success(ZeroSettle.pendingActions.value.map { it.toFlutterMap() })
    }

    // ── dismissPendingAction (suspend) ─────────────────────────────────────

    private fun dismissPendingAction(call: MethodCall, result: MethodChannel.Result) {
        val transactionId = call.argument<String>("transactionId")
        if (transactionId == null) {
            result.error("invalid_args", "dismissPendingAction requires a transactionId", null)
            return
        }
        deps.scope.launch {
            val outcome = ZeroSettle.dismissPendingAction(transactionId)
            outcome.fold(
                onSuccess = { result.success(null) },
                onFailure = { err ->
                    result.error(
                        "sdk_error",
                        err.message ?: "dismissPendingAction failed",
                        null,
                    )
                },
            )
        }
    }
}
