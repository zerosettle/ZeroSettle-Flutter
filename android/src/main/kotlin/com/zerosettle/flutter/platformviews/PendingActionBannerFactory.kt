package com.zerosettle.flutter.platformviews

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.ViewCompositionStrategy
import com.zerosettle.sdk.ZeroSettle
import com.zerosettle.sdk.models.PendingAction
import com.zerosettle.ui.ZeroSettlePendingActionBanner
import com.zerosettle.ui.theme.ZeroSettleTheme
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import kotlinx.coroutines.launch

/**
 * Inline UI factory that embeds the `:ui` [ZeroSettlePendingActionBanner]
 * Composable into a Flutter widget tree via
 * `AndroidView(viewType: "com.zerosettle/pending_action_banner")`.
 *
 * **Source-of-truth:** the Composable subscribes to
 * [com.zerosettle.sdk.ZeroSettle.pendingActions] directly — the banner renders
 * the first pending action (matches the SDK doc on
 * [com.zerosettle.ui.ZeroSettlePendingActionBanner]: "render the first one
 * (`ZeroSettle.pendingActions.firstOrNull()`)"). No snapshot is decoded from
 * creation params — that would force the adopter to keep the Dart side and
 * native state in sync, which is exactly what the unified flow avoids. The
 * spec is explicit at design doc line 262 ("the `PendingActionBanner`
 * PlatformView ... subscribes to the SDK state internally").
 *
 * **Creation params:** none required today. The factory still uses the
 * Standard codec to accept future optional knobs (e.g. style overrides)
 * without breaking the wire shape.
 *
 * **Callback wiring:**
 *   - `onDeepLink(url)` → fires an `ACTION_VIEW` intent on the factory's
 *     [Context]. Used by the `ManualPlayCancel` variant to launch the Play
 *     Store subscriptions page. `Intent.FLAG_ACTIVITY_NEW_TASK` is required
 *     when starting from a non-Activity context (a PlatformView's context is
 *     the Flutter view context, which may not always be an Activity).
 *   - `onDismiss(action)` → suspend-launches [ZeroSettle.dismissPendingAction]
 *     (the A5 overload). The SDK removes the action from
 *     [com.zerosettle.sdk.ZeroSettle.pendingActions] on success; the banner
 *     hides via state-flow update.
 *
 * No event channel: matches the spec's "callbacks land in the SDK directly"
 * model — there is no observable from the Dart side, the adopter's app just
 * drops the widget into its tree.
 *
 * Registered as `com.zerosettle/pending_action_banner` (lands with F7).
 */
class PendingActionBannerFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = decodePendingActionBannerParams(args)
        return PendingActionBannerPlatformView(context, params)
    }
}

/**
 * Decoded params. No required fields today — placeholder for future style
 * overrides. Extracted so the (trivial) decoder is unit-testable without
 * a [ComposeView].
 */
internal data class PendingActionBannerParams(
    val placeholder: Unit = Unit,
)

/**
 * Tolerant decoder — non-Map args yield an empty params object. Today this
 * decoder reads no keys; it exists so the wire shape is unit-testable and so
 * future style overrides slot in without churning the [PlatformView] surface.
 */
internal fun decodePendingActionBannerParams(args: Any?): PendingActionBannerParams {
    // Coerce to a Map for forward-compat (so a non-Map adopter doesn't crash).
    // The cast is intentional even though we don't read keys yet.
    @Suppress("UNCHECKED_CAST")
    val ignored = (args as? Map<String, Any?>) ?: emptyMap()
    // Silence "unused" without an @Suppress: a reference is enough.
    ignored.size
    return PendingActionBannerParams()
}

/**
 * The [PlatformView] that hosts a [ComposeView] for the banner.
 *
 * Renders nothing when there are no pending actions (the Composable returns
 * early on a null `action`). The Flutter parent should still allocate a
 * (collapsible) slot for it since the banner can appear and disappear over
 * time as RTDN-driven `pending_actions[]` updates arrive.
 *
 * `DisposeOnDetachedFromWindow` lets the composition tear down whenever
 * Android detaches the view — important because the StateFlow collector
 * (`collectAsState`) is rooted in the composition, so reattachment recreates
 * the subscription cleanly.
 */
internal class PendingActionBannerPlatformView(
    private val context: Context,
    @Suppress("UNUSED_PARAMETER") params: PendingActionBannerParams = PendingActionBannerParams(),
) : PlatformView {

    private val composeView: ComposeView = ComposeView(context).apply {
        setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnDetachedFromWindow)
        setContent {
            val actions by ZeroSettle.pendingActions.collectAsState()
            val first = actions.firstOrNull()
            val scope = rememberCoroutineScope()

            if (first != null) {
                ZeroSettleTheme {
                    ZeroSettlePendingActionBanner(
                        action = first,
                        onDeepLink = { url -> openDeepLink(url) },
                        onDismiss = { action ->
                            scope.launch { ZeroSettle.dismissPendingAction(action) }
                        },
                    )
                }
            }
        }
    }

    /**
     * Fire a `VIEW` intent for [url]. The Composable is responsible for
     * passing a well-formed `https://play.google.com/store/account/subscriptions...`
     * URL (provided by the backend in
     * [PendingAction.ManualPlayCancel.deepLink]); we just hand it to the
     * system. `FLAG_ACTIVITY_NEW_TASK` covers the case where [context] is
     * not an Activity (Flutter PlatformView contexts can be plain
     * application/view contexts depending on the host).
     */
    private fun openDeepLink(url: String) {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }

    override fun getView(): View = composeView

    override fun dispose() {
        // ComposeView's DisposeOnDetachedFromWindow strategy handles
        // composition teardown when the framework detaches the view; the
        // `collectAsState` subscription is rooted in composition and goes
        // with it.
    }
}
