import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A widget that displays the ZeroSettle migration tip view.
///
/// This widget embeds a native iOS SwiftUI view that encourages users with
/// active StoreKit subscriptions to migrate to web billing for savings.
///
/// The view is self-contained and autonomous:
/// - Automatically shows/hides based on user's entitlement state
/// - Manages its own checkout flow
/// - Handles its own expansion/collapse animations
/// - Dismisses itself when complete or cancelled
///
/// On Android, this widget renders an empty view (iOS-only feature).
///
/// Example:
/// ```dart
/// MigrationTipView(
///   userId: 'user123',
///   backgroundColor: Color(0xFF000000),
/// )
/// ```
class MigrationTipView extends StatelessWidget {
  /// The user ID to pass to the native SDK.
  final String userId;

  /// The background color for the tip view. Defaults to black.
  final Color backgroundColor;

  const MigrationTipView({
    super.key,
    required this.userId,
    this.backgroundColor = const Color(0xFF000000),
  });

  @override
  Widget build(BuildContext context) {
    // Only render on iOS
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 80,
      child: UiKitView(
        viewType: 'zerosettle/migrate_tip_view',
        creationParams: {
          'backgroundColor': backgroundColor.value,
          'userId': userId,
        },
        creationParamsCodec: const StandardMessageCodec(),
      ),
    );
  }
}

/// Backward-compatible typedef. Use [MigrationTipView] instead.
@Deprecated('Use MigrationTipView instead')
typedef ZSMigrateTipView = MigrationTipView;
