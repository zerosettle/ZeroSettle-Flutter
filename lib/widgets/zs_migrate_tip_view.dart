import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Embeds the native iOS migration tip view (`MigrationTipView` from
/// ZeroSettleKit) inside a Flutter app.
///
/// The native SwiftUI view is intrinsically self-sizing — its height changes
/// based on event state (CTA swap when Apple Pay needs setup, dismissal,
/// loading state, etc.). A fixed `SizedBox` would either clip taller content
/// or reserve dead space when the view collapses.
///
/// This widget subscribes to a per-view MethodChannel that the native
/// container pushes size updates to whenever its `layoutSubviews()` fires.
/// Flutter rebuilds with the new height, so the surrounding layout always
/// matches the actual rendered content.
///
/// Renders nothing on Android.
///
/// Example:
/// ```dart
/// MigrationTipView(
///   userId: 'user123',
///   backgroundColor: Theme.of(context).colorScheme.primary,
/// )
/// ```
class MigrationTipView extends StatefulWidget {
  /// The user ID to pass to the native SDK.
  final String userId;

  /// Used as both the card fill AND the CTA text color on the native view
  /// (the CTA button background is hardcoded white). Pass a saturated brand
  /// color, not a neutral surface — white-on-white text won't render.
  final Color backgroundColor;

  const MigrationTipView({
    super.key,
    required this.userId,
    this.backgroundColor = const Color(0xFF000000),
  });

  @override
  State<MigrationTipView> createState() => _MigrationTipViewState();
}

class _MigrationTipViewState extends State<MigrationTipView> {
  /// Native-reported intrinsic height. Starts at 0 so the widget collapses
  /// cleanly until the native view reports its first size — important when
  /// the migration tip auto-hides (no offer available) and never reports
  /// any height at all.
  double _height = 0;
  MethodChannel? _channel;

  void _onPlatformViewCreated(int viewId) {
    final channel = MethodChannel('zerosettle/migrate_tip_view_$viewId');
    _channel = channel;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'setSize') {
        final args = call.arguments as Map?;
        final h = (args?['height'] as num?)?.toDouble();
        if (h != null && h != _height && mounted) {
          setState(() => _height = h);
        }
      }
      return null;
    });
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: _height,
      child: UiKitView(
        viewType: 'zerosettle/migrate_tip_view',
        creationParams: {
          'backgroundColor': widget.backgroundColor.value,
          'userId': widget.userId,
        },
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      ),
    );
  }
}

/// Backward-compatible typedef. Use [MigrationTipView] instead.
@Deprecated('Use MigrationTipView instead')
typedef ZSMigrateTipView = MigrationTipView;
