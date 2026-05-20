package com.zerosettle.flutter.platformviews

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import com.zerosettle.sdk.ZeroSettle
import com.zerosettle.sdk.offers.OfferManager

/**
 * Resolves the SDK [OfferManager] for [stripeCustomerId] and triggers
 * eligibility evaluation once per resolved manager instance.
 *
 * The Android SDK's `OfferManager` is **caller-driven** — unlike iOS's
 * `ZSOfferManager` (which auto-evaluates in `init`), it does nothing until
 * `evaluate()` is called. Without the [LaunchedEffect] below, every
 * `ZeroSettleOfferTip` PlatformView mounts a manager stuck in `LOADING` with
 * `offerData == null` and renders nothing forever.
 *
 * Shared by [OfferTipFactory] and [MigrateTipViewFactory] so both tip-view
 * surfaces resolve and evaluate the manager identically. `remember` keyed on
 * [stripeCustomerId] keeps a single manager instance across recomposition;
 * the `LaunchedEffect` keyed on that manager evaluates once per instance.
 *
 * If `ZeroSettle.offerManager(...)` throws (e.g. `UserNotIdentified` — the
 * adopter must `identify()` before mounting a tip), the exception propagates
 * out of composition, which is the intended loud-failure contract.
 */
@Composable
internal fun rememberEvaluatedOfferManager(stripeCustomerId: String?): OfferManager {
    val manager = remember(stripeCustomerId) {
        ZeroSettle.offerManager(stripeCustomerId)
    }
    LaunchedEffect(manager) {
        manager.evaluate()
    }
    return manager
}
