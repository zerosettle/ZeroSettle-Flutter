package com.zerosettle.flutter.platformviews

import android.content.Context
import androidx.compose.ui.platform.ComposeView
import androidx.test.core.app.ApplicationProvider
import com.google.common.truth.Truth.assertThat
import com.zerosettle.sdk.ZeroSettle
import com.zerosettle.sdk.models.PendingAction
import io.mockk.every
import io.mockk.mockkObject
import io.mockk.unmockkObject
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * Unit tests for [PendingActionBannerFactory] and
 * [decodePendingActionBannerParams].
 *
 * `ZeroSettle.pendingActions` is stubbed via `mockkObject` to a fresh
 * [MutableStateFlow] so the factory can subscribe at composition time without
 * the SDK being identified/configured.
 *
 * The actual rendering branches (`MigrationCompletedInfo` vs
 * `ManualPlayCancel`) are exercised in the `:ui` module's
 * `ZeroSettlePendingActionBannerTest`. Here we test only the contract
 * the factory promises: the wire shape decoder, the [PlatformView] surface,
 * and the SDK-state subscription happens via [ZeroSettle.pendingActions]
 * (not via creation params).
 */
@RunWith(RobolectricTestRunner::class)
class PendingActionBannerFactoryTest {

    private val context: Context = ApplicationProvider.getApplicationContext()
    private val pendingActionsFlow = MutableStateFlow<List<PendingAction>>(emptyList())

    @Before
    fun setUp() {
        mockkObject(ZeroSettle)
        every { ZeroSettle.pendingActions } returns pendingActionsFlow
    }

    @After
    fun tearDown() {
        unmockkObject(ZeroSettle)
    }

    // ─── decodePendingActionBannerParams ───────────────────────────────

    @Test
    fun `decoder returns params object for empty map`() {
        val params = decodePendingActionBannerParams(emptyMap<String, Any?>())
        assertThat(params).isEqualTo(PendingActionBannerParams())
    }

    @Test
    fun `decoder is tolerant of null args`() {
        val params = decodePendingActionBannerParams(null)
        assertThat(params).isEqualTo(PendingActionBannerParams())
    }

    @Test
    fun `decoder is tolerant of non-Map args`() {
        val params = decodePendingActionBannerParams("not a map")
        assertThat(params).isEqualTo(PendingActionBannerParams())
    }

    @Test
    fun `decoder is tolerant of extra unknown keys (forward-compat)`() {
        // Future style overrides should not break older banner factories.
        val params = decodePendingActionBannerParams(
            mapOf("future_key" to "future_value", "another" to 42),
        )
        assertThat(params).isEqualTo(PendingActionBannerParams())
    }

    // ─── PendingActionBannerFactory.create() ───────────────────────────

    @Test
    fun `create returns a PlatformView with a non-null view`() {
        val factory = PendingActionBannerFactory()
        val view = factory.create(context, /* viewId = */ 5, emptyMap<String, Any?>())
        assertThat(view.view).isNotNull()
        assertThat(view.view).isInstanceOf(ComposeView::class.java)
    }

    @Test
    fun `create tolerates null args`() {
        val factory = PendingActionBannerFactory()
        val view = factory.create(context, /* viewId = */ 1, null)
        assertThat(view.view).isNotNull()
    }

    @Test
    fun `create succeeds even when pendingActions is empty (banner renders nothing)`() {
        // No PendingAction in the flow → Composable's early `return` branch.
        // Construction must not throw.
        assertThat(pendingActionsFlow.value).isEmpty()
        val factory = PendingActionBannerFactory()
        val view = factory.create(context, /* viewId = */ 1, emptyMap<String, Any?>())
        assertThat(view.view).isNotNull()
    }

    @Test
    fun `create succeeds with a MigrationCompletedInfo action in the flow`() {
        pendingActionsFlow.value = listOf(
            PendingAction.MigrationCompletedInfo(
                transactionId = "txn_1",
                userMessage = "Your Play subscription has been moved.",
                playAccessEndsAtIso = null,
                newSubscriptionPriceCents = null,
                newSubscriptionCurrency = null,
                newSubscriptionInterval = null,
            ),
        )
        val factory = PendingActionBannerFactory()
        val view = factory.create(context, /* viewId = */ 1, emptyMap<String, Any?>())
        assertThat(view.view).isNotNull()
    }

    @Test
    fun `create succeeds with a ManualPlayCancel action in the flow`() {
        pendingActionsFlow.value = listOf(
            PendingAction.ManualPlayCancel(
                transactionId = "txn_2",
                userMessage = "Cancel your old Play subscription.",
                originalPlayPurchaseToken = "tok_x",
                expiresAtIso = null,
                deepLink = "https://play.google.com/store/account/subscriptions",
            ),
        )
        val factory = PendingActionBannerFactory()
        val view = factory.create(context, /* viewId = */ 1, emptyMap<String, Any?>())
        assertThat(view.view).isNotNull()
    }

    @Test
    fun `dispose runs without throwing`() {
        val factory = PendingActionBannerFactory()
        val view = factory.create(context, /* viewId = */ 1, emptyMap<String, Any?>())
        view.dispose()
        view.dispose() // idempotent
    }
}
