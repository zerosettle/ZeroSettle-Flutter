package com.zerosettle.flutter.platformviews

import android.content.Context
import android.view.View
import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.remember
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
 * The Composable is the same one mounted by [OfferTipFactory]; the
 * difference is the **per-view height-bridge** [MethodChannel] this factory
 * opens at `zerosettle/migrate_tip_view_<viewId>`. The Dart-side
 * `MigrationTipView` widget (`lib/widgets/zs_migrate_tip_view.dart`)
 * subscribes to this channel for `setSize { height }` callbacks so the
 * surrounding `SizedBox` resizes to the rendered content.
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
 */
class MigrateTipViewFactory(private val messenger: BinaryMessenger) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = decodeMigrateTipViewParams(args)
        return MigrateTipViewPlatformView(context, viewId, params, messenger)
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
                    )
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
