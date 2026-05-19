import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/pending_action.dart';

/// Embeds the native `ZeroSettlePendingActionBanner` Composable inside a
/// Flutter widget tree via `AndroidView(viewType:
/// "com.zerosettle/pending_action_banner")`.
///
/// **Android-only.** The native view subscribes to
/// `ZeroSettle.pendingActions` (a Kotlin StateFlow) internally — it renders
/// the first pending action automatically and collapses when the list is
/// empty. No Dart-side state polling is needed; drop this widget into the
/// tree and it reacts to backend-driven action updates on its own.
///
/// The [action] parameter is accepted for forward-compatibility and API
/// symmetry with other ZeroSettle widgets, but the Android factory does not
/// read `creationParams` — it resolves the action from the SDK's shared
/// `pendingActions` StateFlow. This is intentional: driving the view from a
/// Dart-side snapshot would force callers to keep the two sides in sync,
/// which is exactly what the unified-flow architecture avoids.
///
/// iOS renders `SizedBox.shrink()`. The pending-actions feature is
/// Android-only; no iOS PlatformView factory exists.
///
/// Example:
/// ```dart
/// // In your widget tree, after ZeroSettle.instance.identify() completes:
/// StreamBuilder<List<PendingAction>>(
///   stream: ZeroSettle.instance.pendingActionsUpdates,
///   builder: (context, snapshot) {
///     final actions = snapshot.data ?? [];
///     if (actions.isEmpty) return const SizedBox.shrink();
///     return ZeroSettlePendingActionBanner(action: actions.first);
///   },
/// )
/// ```
class ZeroSettlePendingActionBanner extends StatefulWidget {
  /// The pending action to display. The Android factory resolves the action
  /// from the SDK's shared `pendingActions` StateFlow, so this field is
  /// accepted for API completeness only and is not encoded into
  /// `creationParams`.
  final PendingAction action;

  const ZeroSettlePendingActionBanner({
    super.key,
    required this.action,
  });

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
