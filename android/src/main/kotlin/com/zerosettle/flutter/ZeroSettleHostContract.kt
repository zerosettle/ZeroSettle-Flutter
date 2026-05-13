package com.zerosettle.flutter

import android.app.Activity
import android.content.Context
import android.content.Intent
import androidx.activity.result.contract.ActivityResultContract

/**
 * Round-trips between Flutter `MethodCall` args and `ZeroSettleHostActivity` launches.
 * Outcome is a sealed class returned to the plugin's method handler, then encoded
 * to a Flutter-friendly Map via [toFlutterMap].
 *
 * Mode dispatch lives on the Activity side (see F6). This contract only carries
 * the Mode through intent extras and decodes the result extras back into Outcome.
 */
class ZeroSettleHostContract : ActivityResultContract<ZeroSettleHostContract.Input, ZeroSettleHostContract.Outcome>() {

    /**
     * Launch input. `mode` is required; `productId` is required for the
     * PaymentSheet and UpgradeOffer modes (CancelFlow doesn't need one — it
     * acts on the current subscription).
     */
    data class Input(
        val mode: ZeroSettleHostActivity.Mode,
        val productId: String? = null,
    )

    /** Result of a host activity round-trip. */
    sealed class Outcome {
        /** Activity completed successfully. `transactionId` may be null for flows that don't produce one (e.g., cancel flow outcomes other than a successful save). */
        data class Success(val transactionId: String?) : Outcome()
        /** Activity dismissed without producing a successful outcome (drag-down, system back, X button). */
        data object Cancelled : Outcome()
        /** Activity completed with an error. `message` is the error text for adopter display / logging. */
        data class Failed(val message: String) : Outcome()
    }

    override fun createIntent(context: Context, input: Input): Intent {
        return Intent(context, ZeroSettleHostActivity::class.java).apply {
            putExtra("mode", input.mode.name)
            input.productId?.let { putExtra("productId", it) }
        }
    }

    override fun parseResult(resultCode: Int, intent: Intent?): Outcome {
        // System-back / drag-dismiss => Activity.RESULT_CANCELED, intent may be null
        if (resultCode != Activity.RESULT_OK) return Outcome.Cancelled

        return when (intent?.getStringExtra("outcome")) {
            "success" -> Outcome.Success(intent.getStringExtra("transactionId"))
            "failed" -> Outcome.Failed(intent.getStringExtra("errorMessage") ?: "unknown")
            // RESULT_OK with no/unknown outcome extra — treat as cancelled.
            // This shouldn't happen if the Activity sets the extras correctly,
            // but defensive parsing protects against future Activity changes.
            else -> Outcome.Cancelled
        }
    }
}

/**
 * Flutter-friendly Map encoding. The plugin's method handler returns this map
 * via `MethodChannel.Result.success(...)`.
 */
fun ZeroSettleHostContract.Outcome.toFlutterMap(): Map<String, Any?> = when (this) {
    is ZeroSettleHostContract.Outcome.Success -> mapOf(
        "outcome" to "success",
        "transactionId" to transactionId,
    )
    ZeroSettleHostContract.Outcome.Cancelled -> mapOf("outcome" to "cancelled")
    is ZeroSettleHostContract.Outcome.Failed -> mapOf(
        "outcome" to "failed",
        "errorMessage" to message,
    )
}
