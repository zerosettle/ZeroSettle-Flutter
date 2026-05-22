package com.zerosettle.flutter.platformviews

import android.app.Activity
import android.content.Context
import androidx.compose.ui.platform.ComposeView
import androidx.test.core.app.ApplicationProvider
import com.google.common.truth.Truth.assertThat
import com.zerosettle.sdk.ZeroSettle
import io.flutter.plugin.common.BinaryMessenger
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkObject
import io.mockk.unmockkObject
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner

/**
 * Unit tests for [MigrateTipViewFactory], [decodeMigrateTipViewParams], and
 * the height-bridge math helpers.
 *
 * The Composable rendering is not exercised here — that's the `:ui`
 * module's job. We verify:
 *   - params decoder forwards `userId`, `stripeCustomerId`, `backgroundColor`
 *     and tolerates missing/mistyped keys
 *   - the height-bridge math (`heightPxToDp`, `shouldReportHeight`) matches
 *     iOS's behaviour (`ZSMigrateTipViewFlutterContainer.swift:126`):
 *     first-emit-always + 0.5dp dead-band on subsequent emits
 *   - the [PlatformView] surface exposes a [ComposeView] and disposes cleanly
 *
 * Channel-name format and channel-dispose behaviour are pinned by
 * constructing the PlatformView directly (a real Robolectric instance, so
 * the [BinaryMessenger] gets the right channel name when it's wired).
 */
@RunWith(RobolectricTestRunner::class)
class MigrateTipViewFactoryTest {

    private val context: Context = ApplicationProvider.getApplicationContext()
    private val messenger: BinaryMessenger = mockk(relaxed = true)

    /** Default provider — no Activity, exercising the Flutter-Context fallback. */
    private val activityProvider: () -> Activity? = { null }

    @Before
    fun setUp() {
        mockkObject(ZeroSettle)
        every { ZeroSettle.offerManager(any()) } answers { mockk(relaxed = true) }
    }

    @After
    fun tearDown() {
        unmockkObject(ZeroSettle)
    }

    // ─── decodeMigrateTipViewParams ────────────────────────────────────

    @Test
    fun `decoder pulls userId, stripeCustomerId, backgroundColor from Map args`() {
        val params = decodeMigrateTipViewParams(
            mapOf(
                "userId" to "user_42",
                "stripeCustomerId" to "cus_abc",
                "backgroundColor" to 0xFF6CA358.toInt(),
            ),
        )
        assertThat(params.userId).isEqualTo("user_42")
        assertThat(params.stripeCustomerId).isEqualTo("cus_abc")
        assertThat(params.backgroundColorArgb).isEqualTo(0xFF6CA358.toInt())
    }

    @Test
    fun `decoder yields nulls when all keys are missing`() {
        val params = decodeMigrateTipViewParams(emptyMap<String, Any?>())
        assertThat(params.userId).isNull()
        assertThat(params.stripeCustomerId).isNull()
        assertThat(params.backgroundColorArgb).isNull()
    }

    @Test
    fun `decoder is tolerant of null args`() {
        val params = decodeMigrateTipViewParams(null)
        assertThat(params.userId).isNull()
        assertThat(params.stripeCustomerId).isNull()
        assertThat(params.backgroundColorArgb).isNull()
    }

    @Test
    fun `decoder is tolerant of non-Map args`() {
        val params = decodeMigrateTipViewParams("not a map")
        assertThat(params.userId).isNull()
    }

    @Test
    fun `decoder accepts backgroundColor sent as Long (Flutter Standard codec quirk)`() {
        // Flutter's StandardMessageCodec promotes integers > 32 bits to Long.
        // We accept any Number for forward-compat (matches iOS, which reads
        // `args["backgroundColor"] as? Int` then bit-shifts — the channel
        // codec gives Swift the right type already).
        val params = decodeMigrateTipViewParams(
            mapOf("backgroundColor" to 0xFF6CA358L),
        )
        assertThat(params.backgroundColorArgb).isEqualTo(0xFF6CA358.toInt())
    }

    @Test
    fun `decoder ignores wrong-typed backgroundColor`() {
        val params = decodeMigrateTipViewParams(
            mapOf("backgroundColor" to "not-a-color"),
        )
        assertThat(params.backgroundColorArgb).isNull()
    }

    // ─── heightPxToDp ──────────────────────────────────────────────────

    @Test
    fun `heightPxToDp converts pixels to dp using density`() {
        // At density=2 (xhdpi), 200px is 100dp.
        assertThat(heightPxToDp(200, 2.0f)).isEqualTo(100.0)
    }

    @Test
    fun `heightPxToDp handles density=1 (mdpi)`() {
        // 1:1 mapping on baseline density.
        assertThat(heightPxToDp(73, 1.0f)).isEqualTo(73.0)
    }

    // ─── shouldReportHeight ────────────────────────────────────────────

    @Test
    fun `shouldReportHeight is true for the very first measurement (sentinel)`() {
        // -1 sentinel means "never reported"; any value should fire.
        assertThat(shouldReportHeight(-1.0, 100.0)).isTrue()
        assertThat(shouldReportHeight(-1.0, 0.0)).isTrue()
    }

    @Test
    fun `shouldReportHeight suppresses no-op updates within 0_5dp band`() {
        assertThat(shouldReportHeight(lastHeightDp = 120.0, newHeightDp = 120.0)).isFalse()
        assertThat(shouldReportHeight(lastHeightDp = 120.0, newHeightDp = 120.3)).isFalse()
        assertThat(shouldReportHeight(lastHeightDp = 120.0, newHeightDp = 119.7)).isFalse()
    }

    @Test
    fun `shouldReportHeight emits when delta exceeds the dead-band`() {
        assertThat(shouldReportHeight(lastHeightDp = 120.0, newHeightDp = 121.0)).isTrue()
        assertThat(shouldReportHeight(lastHeightDp = 120.0, newHeightDp = 118.0)).isTrue()
    }

    @Test
    fun `shouldReportHeight respects custom tolerance`() {
        // 2dp tolerance — 1dp shifts coalesce.
        assertThat(
            shouldReportHeight(lastHeightDp = 100.0, newHeightDp = 101.0, tolerance = 2.0),
        ).isFalse()
        assertThat(
            shouldReportHeight(lastHeightDp = 100.0, newHeightDp = 103.0, tolerance = 2.0),
        ).isTrue()
    }

    // ─── MigrateTipViewFactory.create() ────────────────────────────────

    @Test
    fun `create returns a PlatformView with a ComposeView`() {
        val factory = MigrateTipViewFactory(messenger, activityProvider)
        val view = factory.create(
            context,
            /* viewId = */ 9,
            mapOf(
                "userId" to "u1",
                "stripeCustomerId" to "cus_z",
            ),
        )
        assertThat(view.view).isNotNull()
        assertThat(view.view).isInstanceOf(ComposeView::class.java)
    }

    @Test
    fun `create tolerates null args`() {
        val factory = MigrateTipViewFactory(messenger, activityProvider)
        val view = factory.create(context, /* viewId = */ 1, null)
        assertThat(view.view).isNotNull()
    }

    @Test
    fun `dispose runs without throwing and is idempotent`() {
        val factory = MigrateTipViewFactory(messenger, activityProvider)
        val view = factory.create(context, /* viewId = */ 1, emptyMap<String, Any?>())
        view.dispose()
        view.dispose()
    }

    @Test
    fun `each viewId allocates a distinct PlatformView instance`() {
        // Sanity check that the factory doesn't memoize across viewIds —
        // each call must produce a fresh PlatformView so the per-view
        // channel name `zerosettle/migrate_tip_view_<viewId>` is unique.
        val factory = MigrateTipViewFactory(messenger, activityProvider)
        val a = factory.create(context, /* viewId = */ 1, emptyMap<String, Any?>())
        val b = factory.create(context, /* viewId = */ 2, emptyMap<String, Any?>())
        assertThat(a).isNotSameInstanceAs(b)
        assertThat(a.view).isNotSameInstanceAs(b.view)
    }

    // ─── host-Activity context selection ───────────────────────────────

    @Test
    fun `create builds the ComposeView against the Activity from activityProvider`() {
        // The SDK's ZeroSettleOfferTip resolves the Switch & Save checkout
        // Activity from the ComposeView's context via findActivity(), so the
        // factory must build the view against the host Activity — not the
        // (non-Activity) Context Flutter hands the PlatformView.
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        val factory = MigrateTipViewFactory(messenger) { activity }
        val view = factory.create(context, /* viewId = */ 5, null)
        assertThat(view.view!!.context).isSameInstanceAs(activity)
    }

    @Test
    fun `create falls back to the Flutter Context when no Activity is attached`() {
        // No Activity yet — the tip still renders; only the CTA needs one.
        val factory = MigrateTipViewFactory(messenger) { null }
        val view = factory.create(context, /* viewId = */ 6, null)
        assertThat(view.view!!.context).isSameInstanceAs(context)
    }
}
