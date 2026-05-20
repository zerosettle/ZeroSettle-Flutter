package com.zerosettle.flutter.platformviews

import android.content.Context
import android.view.View
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.ViewCompositionStrategy
import com.zerosettle.ui.ZeroSettleOfferTip
import com.zerosettle.ui.theme.ZeroSettleTheme
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Inline UI factory that embeds the `:ui` [ZeroSettleOfferTip] Composable into a
 * Flutter widget tree via `AndroidView(viewType: "com.zerosettle/offer_tip")`.
 *
 * **iOS parity:** there is no iOS-side `OfferTipFactory` yet — adopters consume
 * the SDK's `ZSMigrateTipView` (renders the same OfferManager-driven content
 * via the migrate-tip path) — but the Android Composable is the canonical
 * unified surface, so we expose it directly here. The Android PlatformView is
 * the contract; iOS will mirror it later.
 *
 * **Creation params** (Standard codec `Map<String, Any?>`):
 *   - `stripeCustomerId: String?` — optional, forwarded to
 *     [ZeroSettle.offerManager] (subscription-group routing key, see
 *     ZSOfferManager Dart docstring + the `:core` `OfferManager` ctor).
 *
 * No event channel: the Composable observes the [OfferManager] StateFlows and
 * drives transitions internally (dismissals call
 * [com.zerosettle.sdk.offers.OfferManager.dismiss], acceptance calls
 * [com.zerosettle.sdk.offers.OfferManager.acceptOffer]). No callbacks need
 * surfacing to Dart — consumers read state via the StateFlow accessor or the
 * PlatformView, which subscribes to SDK state internally.
 *
 * Eligibility evaluation is triggered by [rememberEvaluatedOfferManager] — the
 * Composable itself does NOT auto-evaluate, and the Android SDK's OfferManager
 * is caller-driven, so the factory must kick it off.
 *
 * The factory is registered in `ZeroSettlePlugin.onAttachedToEngine` (lands
 * with F7) as `com.zerosettle/offer_tip`.
 */
class OfferTipFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = decodeOfferTipParams(args)
        return OfferTipPlatformView(context, params)
    }
}

/**
 * Decoded shape for [OfferTipFactory]. `stripeCustomerId` is nullable —
 * matches the Dart wire ("optional"). Extracted so the decoder is unit-testable
 * without instantiating a [ComposeView].
 */
internal data class OfferTipParams(
    val stripeCustomerId: String?,
)

/** Tolerant decoder — non-Map args yield an empty params object. */
internal fun decodeOfferTipParams(args: Any?): OfferTipParams {
    @Suppress("UNCHECKED_CAST")
    val map = (args as? Map<String, Any?>) ?: emptyMap()
    return OfferTipParams(
        stripeCustomerId = map["stripeCustomerId"] as? String,
    )
}

/**
 * The Android [PlatformView] that hosts a [ComposeView] for [ZeroSettleOfferTip].
 *
 * `DisposeOnDetachedFromWindow` is the right strategy here: this PlatformView's
 * lifetime is shorter than the Activity (Flutter creates and disposes it as the
 * widget mounts/unmounts), so we want the composition to tear down whenever
 * Android detaches the view from the window.
 *
 * The `OfferManager` is fetched inside `setContent { remember { ... } }` so
 * a single SDK instance survives recomposition. Without `remember`, every
 * recomposition would allocate a new manager and lose state-flow continuity.
 *
 * If `ZeroSettle.offerManager(...)` throws (e.g. `UserNotIdentified` — the
 * adopter must call `identify()` before mounting the tip), the exception
 * propagates out of composition. Adopters are documented to identify before
 * rendering the tip; failing loudly is the correct contract.
 */
internal class OfferTipPlatformView(
    context: Context,
    params: OfferTipParams,
) : PlatformView {

    private val composeView: ComposeView = ComposeView(context).apply {
        setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnDetachedFromWindow)
        setContent {
            val offerManager = rememberEvaluatedOfferManager(params.stripeCustomerId)
            ZeroSettleTheme {
                ZeroSettleOfferTip(offerManager = offerManager)
            }
        }
    }

    override fun getView(): View = composeView

    override fun dispose() {
        // ComposeView's DisposeOnDetachedFromWindow strategy handles
        // composition teardown when the framework detaches the view; nothing
        // else owns resources tied to this PlatformView.
    }
}
