package com.zerosettle.flutter.platformviews

import android.app.Activity
import android.content.Context
import android.util.Log
import android.view.View
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.ViewCompositionStrategy
import com.zerosettle.ui.ZeroSettleOfferTip
import com.zerosettle.ui.theme.ZeroSettleTheme
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import kotlin.math.abs

/**
 * Inline UI factory that embeds the `:ui` [ZeroSettleOfferTip] Composable
 * into a Flutter widget tree via
 * `AndroidView(viewType: "com.zerosettle/migrate_tip_view")`.
 *
 * It opens a **per-view height-bridge** [MethodChannel] at
 * `zerosettle/migrate_tip_view_<viewId>`; the Dart-side `OfferTipView`
 * widget (`lib/widgets/zs_offer_tip_view.dart`) subscribes to this channel
 * for `setSize { height }` callbacks so the surrounding `SizedBox` resizes
 * to the rendered content.
 *
 * **iOS parity:**
 *   - iOS factory: `ZSMigrateTipViewFactory` registered as
 *     `zerosettle/migrate_tip_view` at `ZeroSettlePlugin.swift:188`.
 *   - iOS per-view channel: `zerosettle/migrate_tip_view_<viewId>`
 *     (`ZSMigrateTipViewFlutterContainer.swift:40`).
 *   - iOS method name + payload: `invokeMethod("setSize", ["height": Double])`
 *     (`ZSMigrateTipViewFlutterContainer.swift:129`).
 *
 * **Creation params** (Standard codec `Map<String, Any?>`):
 *   - `userId: String?` — present on iOS for parity but unused on Android;
 *     the Composable binds to the SDK's currently-identified user via
 *     [ZeroSettle.offerManager]. (We accept and ignore it; explicit
 *     parity-but-unused beats failing if Dart sends it.)
 *   - `stripeCustomerId: String?` — optional, forwarded to
 *     [ZeroSettle.offerManager] (subscription-group routing key).
 *   - `backgroundColor: Int?` — ARGB int from `Color.toARGB32()` on the Dart
 *     side. iOS converts and applies this to the SwiftUI card; the Android
 *     `:ui` [ZeroSettleOfferTip] takes its `backgroundColor` as a Compose
 *     `Color` (optional). We forward the decoded value through.
 *
 * **Height-bridge:** the [Box] wrapping the Composable observes its rendered
 * size via [onSizeChanged] and pushes pixel→dp converted height through the
 * per-view channel. A `0.5dp` dead-band coalesces near-duplicate updates
 * (matches iOS at `ZSMigrateTipViewFlutterContainer.swift:126`). Width is
 * fixed by Flutter's parent; only height is reported.
 *
 * **Host Activity:** the [ComposeView] is built against the host [Activity]
 * (resolved via `activityProvider`), not the [Context] Flutter hands the
 * PlatformView. The `:ui` `ZeroSettleOfferTip` resolves the Switch & Save
 * checkout Activity from `LocalContext` via `findActivity()`; Flutter's
 * PlatformView Context is not an Activity and its wrapper chain never
 * reaches one, so the CTA would silently no-op without this.
 */
class MigrateTipViewFactory(
    private val messenger: BinaryMessenger,
    private val activityProvider: () -> Activity?,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = decodeMigrateTipViewParams(args)
        // Build the ComposeView against the host Activity so the SDK's
        // ZeroSettleOfferTip can resolve it for the Switch & Save checkout.
        // Falls back to the Flutter PlatformView Context when no Activity is
        // attached — the tip still renders; only the CTA needs the Activity.
        val viewContext: Context = activityProvider() ?: context
        return MigrateTipViewPlatformView(viewContext, viewId, params, messenger)
    }
}

/**
 * Decoded params for [MigrateTipViewFactory]. `backgroundColor` is the raw
 * ARGB int (`null` if not supplied or wrong type) so the decoder can stay
 * out of Compose.
 */
internal data class MigrateTipViewParams(
    val userId: String?,
    val stripeCustomerId: String?,
    val backgroundColorArgb: Int?,
)

/** Tolerant decoder — non-Map args yield an empty params object. */
internal fun decodeMigrateTipViewParams(args: Any?): MigrateTipViewParams {
    @Suppress("UNCHECKED_CAST")
    val map = (args as? Map<String, Any?>) ?: emptyMap()
    return MigrateTipViewParams(
        userId = map["userId"] as? String,
        stripeCustomerId = map["stripeCustomerId"] as? String,
        backgroundColorArgb = (map["backgroundColor"] as? Number)?.toInt(),
    )
}

/**
 * Convert a measured pixel height to dp using the supplied density. Factored
 * out so the dead-band coalescing math (in [MigrateTipViewPlatformView]) can
 * be exercised by a plain unit test without standing up a [ComposeView].
 */
internal fun heightPxToDp(heightPx: Int, density: Float): Double =
    (heightPx / density).toDouble()

/**
 * Returns true iff [newHeightDp] is more than [tolerance]dp different from
 * [lastHeightDp]; the platform-view uses this to suppress no-op updates.
 * The default `0.5dp` band matches iOS at
 * `ZSMigrateTipViewFlutterContainer.swift:126`.
 */
internal fun shouldReportHeight(
    lastHeightDp: Double,
    newHeightDp: Double,
    tolerance: Double = 0.5,
): Boolean = lastHeightDp < 0 || abs(newHeightDp - lastHeightDp) > tolerance

internal class MigrateTipViewPlatformView(
    private val context: Context,
    viewId: Int,
    private val params: MigrateTipViewParams,
    messenger: BinaryMessenger,
) : PlatformView {

    private val channelName = "zerosettle/migrate_tip_view_$viewId"
    internal val channel: MethodChannel = MethodChannel(messenger, channelName)
    private val density: Float = context.resources.displayMetrics.density

    // Sentinel value < 0 so the first measurement always emits.
    private var lastReportedHeightDp: Double = -1.0

    private val composeView: ComposeView = ComposeView(context).apply {
        setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnDetachedFromWindow)
        setContent {
            val offerManager = rememberEvaluatedOfferManager(params.stripeCustomerId)
            // Forward the ARGB int from the Dart side as a Compose Color. iOS
            // applies the same value to the SwiftUI card's surface; on Android
            // the `:ui` Composable exposes it through its `backgroundColor`
            // parameter. Null falls through to the `ZeroSettleTheme` default
            // surface — matches the iOS default-fill behaviour when the
            // adopter passes no color.
            val composeBackgroundColor = remember(params.backgroundColorArgb) {
                params.backgroundColorArgb?.let { Color(it) }
            }
            ZeroSettleTheme {
                // Flutter force-measures the embedding ComposeView at the
                // AndroidView's current height (1px during the Dart-side
                // bootstrap). A plain `onSizeChanged` would therefore observe
                // that 1px constraint, not the tip's real height — so the
                // SizedBox could never grow past the bootstrap. The outer
                // `wrapContentHeight(unbounded = true)` re-measures its child
                // with an *unbounded* height constraint; the inner Box then
                // lays out at the tip's intrinsic height, and that is the
                // value `onSizeChanged` observes and bridges back to Dart.
                // Dart resizes the SizedBox, the next measure pass hands the
                // ComposeView the real height, and the dead-band coalescing
                // settles the loop.
                Box(
                    modifier = Modifier.wrapContentHeight(
                        align = Alignment.Top,
                        unbounded = true,
                    )
                ) {
                    Box(
                        modifier = Modifier.onSizeChanged { size ->
                            val heightDp = heightPxToDp(size.height, density)
                            if (shouldReportHeight(lastReportedHeightDp, heightDp)) {
                                lastReportedHeightDp = heightDp
                                channel.invokeMethod(
                                    "setSize",
                                    mapOf("height" to heightDp),
                                )
                            }
                        }
                    ) {
                        ZeroSettleOfferTip(
                            offerManager = offerManager,
                            backgroundColor = composeBackgroundColor,
                            onError = { error ->
                                // The SDK surfaces CTA/checkout failures
                                // here (e.g. no host Activity). The default
                                // handler is a no-op — log so this class of
                                // failure is never silent again.
                                Log.w("ZeroSettle", "OfferTip error", error)
                            },
                        )
                    }
                }
            }
        }
    }

    override fun getView(): View = composeView

    override fun dispose() {
        // The `setSize` direction is platform→Dart (`invokeMethod`); what
        // actually stops further measurement callbacks is
        // `DisposeOnDetachedFromWindow` tearing down composition (which
        // unsubscribes the `onSizeChanged` modifier). We still clear the
        // method-call handler defensively — the per-view channel never has
        // one wired today, but a future addition (e.g. Dart→native
        // commands) shouldn't be left dangling after the PlatformView is
        // gone. Parity with the plan's `MigrateTipViewPlatformView`.
        channel.setMethodCallHandler(null)
    }
}
