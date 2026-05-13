package com.zerosettle.flutter.platformviews

import android.content.Context
import androidx.compose.ui.platform.ComposeView
import androidx.test.core.app.ApplicationProvider
import com.google.common.truth.Truth.assertThat
import com.zerosettle.sdk.ZeroSettle
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkObject
import io.mockk.unmockkObject
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * Unit tests for [OfferTipFactory] and [decodeOfferTipParams].
 *
 * `ZeroSettle.offerManager(...)` is stubbed via `mockkObject` for the same
 * reason as in `OfferManagerHandleRegistryTest`: the real implementation
 * throws `UserNotIdentified` unless `identify(...)` ran with a backend
 * bootstrap. `setContent { ... }` is a Compose-runtime call that doesn't
 * actually trigger composition until the view attaches to a window, so the
 * mock is mostly defensive — but if Compose ever changes to eagerly compose
 * inside `setContent`, the mock keeps these tests honest.
 */
@RunWith(RobolectricTestRunner::class)
class OfferTipFactoryTest {

    private val context: Context = ApplicationProvider.getApplicationContext()

    @Before
    fun setUp() {
        mockkObject(ZeroSettle)
        every { ZeroSettle.offerManager(any()) } answers { mockk(relaxed = true) }
    }

    @After
    fun tearDown() {
        unmockkObject(ZeroSettle)
    }

    // ─── decodeOfferTipParams ───────────────────────────────────────────

    @Test
    fun `decoder pulls stripeCustomerId from Map args`() {
        val params = decodeOfferTipParams(mapOf("stripeCustomerId" to "cus_abc"))
        assertThat(params.stripeCustomerId).isEqualTo("cus_abc")
    }

    @Test
    fun `decoder yields null stripeCustomerId when key missing`() {
        val params = decodeOfferTipParams(emptyMap<String, Any?>())
        assertThat(params.stripeCustomerId).isNull()
    }

    @Test
    fun `decoder is tolerant of null args`() {
        val params = decodeOfferTipParams(null)
        assertThat(params.stripeCustomerId).isNull()
    }

    @Test
    fun `decoder is tolerant of non-Map args`() {
        val params = decodeOfferTipParams("not a map")
        assertThat(params.stripeCustomerId).isNull()
    }

    @Test
    fun `decoder ignores wrong-typed stripeCustomerId value`() {
        val params = decodeOfferTipParams(mapOf("stripeCustomerId" to 42))
        assertThat(params.stripeCustomerId).isNull()
    }

    // ─── OfferTipFactory.create() ──────────────────────────────────────

    @Test
    fun `create returns a PlatformView with a non-null view`() {
        val factory = OfferTipFactory()
        val view = factory.create(
            context,
            /* viewId = */ 7,
            mapOf("stripeCustomerId" to "cus_xyz"),
        )
        assertThat(view.view).isNotNull()
        assertThat(view.view).isInstanceOf(ComposeView::class.java)
    }

    @Test
    fun `create tolerates null args (treats as empty params)`() {
        val factory = OfferTipFactory()
        val view = factory.create(context, /* viewId = */ 1, null)
        assertThat(view.view).isNotNull()
    }

    @Test
    fun `dispose runs without throwing`() {
        val factory = OfferTipFactory()
        val view = factory.create(context, /* viewId = */ 1, emptyMap<String, Any?>())
        // Idempotent + side-effect free.
        view.dispose()
        view.dispose()
    }
}
