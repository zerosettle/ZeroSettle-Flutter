import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Embeds the native ZeroSettle offer tip view into a Flutter app.
///
/// **Android-only.** Mounts the `:ui` `ZeroSettleOfferTip` Composable via
/// `AndroidView(viewType: "com.zerosettle/offer_tip")`. The native view
/// resolves its own `OfferManager` from the SDK's internal state by calling
/// `ZeroSettle.offerManager(stripeCustomerId)` — no Dart-side handle is
/// needed. The Composable drives every state transition internally (offer
/// loading, CTA swap, dismissal) and self-manages visibility: it renders
/// nothing when no offer is available.
///
/// The [stripeCustomerId] is forwarded to the native `OfferManager` resolver.
/// Pass the same value you would pass to
/// `ZeroSettle.instance.offerManager(stripeCustomerId: ...)`. Omit it when
/// the current user has no Stripe customer (e.g., new users on their first
/// offer check).
///
/// iOS (and every other non-Android platform) renders `SizedBox.shrink()` —
/// the native `ZeroSettleOfferTip` Composable has no iOS equivalent at this
/// time.
///
/// Example:
/// ```dart
/// ZeroSettleOfferTip(stripeCustomerId: currentUser.stripeCustomerId)
/// ```
class ZeroSettleOfferTip extends StatefulWidget {
  /// Optional Stripe customer ID forwarded to the Android SDK's
  /// `ZeroSettle.offerManager(stripeCustomerId)` resolver. Omit for users
  /// who don't yet have a Stripe customer.
  final String? stripeCustomerId;

  const ZeroSettleOfferTip({super.key, this.stripeCustomerId});

  @override
  State<ZeroSettleOfferTip> createState() => _ZeroSettleOfferTipState();
}

class _ZeroSettleOfferTipState extends State<ZeroSettleOfferTip> {
  @override
  Widget build(BuildContext context) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // The Android factory (`OfferTipFactory`) resolves its own OfferManager
        // via `ZeroSettle.offerManager(stripeCustomerId)` internally — no
        // per-view MethodChannel or handle ID is needed from the Dart side.
        // The decoder is tolerant: a null or missing `stripeCustomerId` key
        // yields a null stripeCustomerId and the SDK falls back to the default
        // offer manager.
        return AndroidView(
          viewType: 'com.zerosettle/offer_tip',
          creationParams: <String, Object?>{
            'stripeCustomerId': widget.stripeCustomerId,
          },
          creationParamsCodec: const StandardMessageCodec(),
        );
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        // iOS has no OfferTipFactory equivalent yet. Every non-Android
        // platform renders nothing.
        return const SizedBox.shrink();
    }
  }
}
