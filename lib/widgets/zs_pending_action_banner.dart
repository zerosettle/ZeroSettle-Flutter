import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A zero-config mount point for the native ZeroSettle pending-action banner.
///
/// **Android-only.** Embeds the native `ZeroSettlePendingActionBanner`
/// Composable via `AndroidView(viewType:
/// "com.zerosettle/pending_action_banner")`. The native view subscribes to
/// the SDK's `ZeroSettle.pendingActions` stream (a Kotlin StateFlow)
/// internally: it renders the current top pending action automatically and
/// self-manages visibility — collapsing to nothing when there are no
/// pending actions. No Dart-side state, parameters, or polling are needed;
/// the widget takes no arguments because the native side is the single
/// source of truth.
///
/// Mount it once near the app root (e.g. wrapped around your home scaffold's
/// body). It stays invisible until the backend surfaces a pending action,
/// then appears in place; when the action is dismissed or resolved it
/// collapses again.
///
/// iOS (and every other non-Android platform) renders `SizedBox.shrink()` —
/// the pending-actions feature is Android-only and no iOS PlatformView
/// factory exists.
///
/// Example:
/// ```dart
/// Column(
///   children: [
///     const ZeroSettlePendingActionBanner(),
///     Expanded(child: MyAppContent()),
///   ],
/// )
/// ```
class ZeroSettlePendingActionBanner extends StatefulWidget {
  const ZeroSettlePendingActionBanner({super.key});

  @override
  State<ZeroSettlePendingActionBanner> createState() =>
      _ZeroSettlePendingActionBannerState();
}

class _ZeroSettlePendingActionBannerState
    extends State<ZeroSettlePendingActionBanner> {
  @override
  Widget build(BuildContext context) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // The Android factory (`PendingActionBannerFactory`) subscribes to
        // `ZeroSettle.pendingActions` internally — no creation params are
        // read. Pass an empty map for forward-compat (the factory is tolerant
        // of any Map shape). No per-view setSize MethodChannel is wired on
        // the Android side, so the widget does not install one; the native
        // Composable collapses itself when there are no pending actions.
        return AndroidView(
          viewType: 'com.zerosettle/pending_action_banner',
          creationParams: const <String, Object?>{},
          creationParamsCodec: const StandardMessageCodec(),
        );
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        // Pending actions are Android-only. iOS always returns an empty list
        // from the bridge and has no PlatformView factory for this view type.
        return const SizedBox.shrink();
    }
  }
}
