package com.zerosettle.flutter

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Modifier
import com.zerosettle.ui.theme.ZeroSettleTheme

/**
 * Transparent activity hosting Compose modal sheets for `presentPaymentSheet`,
 * `presentCancelFlow`, and `presentUpgradeOffer` Dart calls.
 *
 * One activity, multiple modes via the `"mode"` intent extra. Result handed
 * back via setResult + finish, decoded by [ZeroSettleHostContract.parseResult].
 *
 * Mode dispatch is intentionally a placeholder in F5 (finishes immediately
 * with Cancelled). F6 wires the `:ui` Composables (`ZeroSettleCheckoutSheet`,
 * `ZeroSettleCancelFlow`, `ZeroSettleUpgradeOffer`) into the `when` arms.
 */
class ZeroSettleHostActivity : ComponentActivity() {

    enum class Mode { PaymentSheet, CancelFlow, UpgradeOffer }
    // `Mode.SaveTheSale` deliberately absent — no `ZeroSettleSaveTheSale`
    // Composable exists in `:ui` 1.0.0. `presentSaveTheSaleSheet` throws
    // `not_implemented` at the plugin layer (see Task F13).

    @OptIn(ExperimentalMaterial3Api::class)
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val modeName = intent.getStringExtra("mode") ?: run {
            finishWithFailure("missing mode extra")
            return
        }
        val mode = runCatching { Mode.valueOf(modeName) }.getOrElse {
            finishWithFailure("unknown mode: $modeName")
            return
        }
        val productId = intent.getStringExtra("productId")
        // `productId` is unused in F5's placeholder. F6 will read it when
        // mounting the Composables that need it (PaymentSheet, UpgradeOffer).
        @Suppress("UNUSED_VARIABLE") val pid = productId

        setContent {
            ZeroSettleTheme {
                val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

                ModalBottomSheet(
                    onDismissRequest = { finishWithResult(ZeroSettleHostContract.Outcome.Cancelled) },
                    sheetState = sheetState,
                    modifier = Modifier.fillMaxSize(),
                ) {
                    // F5 placeholder: dispatch lands in F6.
                    // Immediately finishes with Cancelled so the activity is
                    // testable in isolation before the :ui Composables are wired.
                    LaunchedEffect(Unit) {
                        finishWithResult(ZeroSettleHostContract.Outcome.Cancelled)
                    }
                }
            }
        }
    }

    private fun finishWithResult(outcome: ZeroSettleHostContract.Outcome) {
        val resultIntent = Intent().apply {
            when (outcome) {
                is ZeroSettleHostContract.Outcome.Success -> {
                    putExtra("outcome", "success")
                    outcome.transactionId?.let { putExtra("transactionId", it) }
                }
                ZeroSettleHostContract.Outcome.Cancelled -> {
                    putExtra("outcome", "cancelled")
                }
                is ZeroSettleHostContract.Outcome.Failed -> {
                    putExtra("outcome", "failed")
                    putExtra("errorMessage", outcome.message)
                }
            }
        }
        setResult(Activity.RESULT_OK, resultIntent)
        finish()
    }

    private fun finishWithFailure(message: String) {
        finishWithResult(ZeroSettleHostContract.Outcome.Failed(message))
    }
}
