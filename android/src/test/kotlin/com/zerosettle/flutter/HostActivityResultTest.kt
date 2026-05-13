package com.zerosettle.flutter

import android.app.Activity
import android.app.Application
import android.content.Intent
import androidx.test.core.app.ApplicationProvider
import com.google.common.truth.Truth.assertThat
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class HostActivityResultTest {

    private val context: Application = ApplicationProvider.getApplicationContext()

    @Test
    fun `contract encodes Mode in launch intent`() {
        val intent = ZeroSettleHostContract().createIntent(
            context,
            ZeroSettleHostContract.Input(
                mode = ZeroSettleHostActivity.Mode.CancelFlow,
                productId = null,
            )
        )
        assertThat(intent.getStringExtra("mode")).isEqualTo("CancelFlow")
        assertThat(intent.hasExtra("productId")).isFalse()
    }

    @Test
    fun `contract encodes productId for UpgradeOffer mode`() {
        val intent = ZeroSettleHostContract().createIntent(
            context,
            ZeroSettleHostContract.Input(
                mode = ZeroSettleHostActivity.Mode.UpgradeOffer,
                productId = "com.app.pro_yearly",
            )
        )
        assertThat(intent.getStringExtra("mode")).isEqualTo("UpgradeOffer")
        assertThat(intent.getStringExtra("productId")).isEqualTo("com.app.pro_yearly")
    }

    @Test
    fun `parseResult decodes Success outcome from RESULT_OK intent`() {
        val resultIntent = Intent().apply {
            putExtra("outcome", "success")
            putExtra("transactionId", "txn_42")
        }
        val outcome = ZeroSettleHostContract().parseResult(Activity.RESULT_OK, resultIntent)
        assertThat(outcome).isInstanceOf(ZeroSettleHostContract.Outcome.Success::class.java)
        assertThat((outcome as ZeroSettleHostContract.Outcome.Success).transactionId).isEqualTo("txn_42")
    }

    @Test
    fun `parseResult decodes Success with null transactionId`() {
        val resultIntent = Intent().apply { putExtra("outcome", "success") }
        val outcome = ZeroSettleHostContract().parseResult(Activity.RESULT_OK, resultIntent)
        assertThat((outcome as ZeroSettleHostContract.Outcome.Success).transactionId).isNull()
    }

    @Test
    fun `parseResult decodes Cancelled from RESULT_CANCELED`() {
        val outcome = ZeroSettleHostContract().parseResult(Activity.RESULT_CANCELED, null)
        assertThat(outcome).isInstanceOf(ZeroSettleHostContract.Outcome.Cancelled::class.java)
    }

    @Test
    fun `parseResult decodes Cancelled from RESULT_OK with unknown outcome`() {
        // Defensive — RESULT_OK without a recognized outcome extra
        val outcome = ZeroSettleHostContract().parseResult(Activity.RESULT_OK, Intent())
        assertThat(outcome).isInstanceOf(ZeroSettleHostContract.Outcome.Cancelled::class.java)
    }

    @Test
    fun `parseResult decodes Failed outcome with error message`() {
        val resultIntent = Intent().apply {
            putExtra("outcome", "failed")
            putExtra("errorMessage", "network error")
        }
        val outcome = ZeroSettleHostContract().parseResult(Activity.RESULT_OK, resultIntent)
        assertThat(outcome).isInstanceOf(ZeroSettleHostContract.Outcome.Failed::class.java)
        assertThat((outcome as ZeroSettleHostContract.Outcome.Failed).message).isEqualTo("network error")
    }

    @Test
    fun `Outcome Success toFlutterMap shape`() {
        val map = ZeroSettleHostContract.Outcome.Success("txn_99").toFlutterMap()
        assertThat(map["outcome"]).isEqualTo("success")
        assertThat(map["transactionId"]).isEqualTo("txn_99")
    }

    @Test
    fun `Outcome Cancelled toFlutterMap shape`() {
        val map = ZeroSettleHostContract.Outcome.Cancelled.toFlutterMap()
        assertThat(map["outcome"]).isEqualTo("cancelled")
        assertThat(map).hasSize(1)
    }

    @Test
    fun `Outcome Failed toFlutterMap shape`() {
        val map = ZeroSettleHostContract.Outcome.Failed("uh oh").toFlutterMap()
        assertThat(map["outcome"]).isEqualTo("failed")
        assertThat(map["errorMessage"]).isEqualTo("uh oh")
    }
}
