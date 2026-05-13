import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Embeds the native migration tip view inside a Flutter app:
/// SwiftUI `MigrationTipView` on iOS (from ZeroSettleKit), Compose
/// `ZeroSettleOfferTip` on Android (from ZeroSettle-Android `:ui`).
///
/// The native view is intrinsically self-sizing — its height changes based
/// on event state (CTA swap when Apple Pay needs setup, dismissal, loading
/// state, etc.). A fixed `SizedBox` would either clip taller content or
/// reserve dead space when the view collapses.
///
/// This widget subscribes to a per-view MethodChannel that the native
/// container pushes size updates to whenever its layout fires. The wire
/// shape (`setSize` with `{height: Double}`) and channel name format
/// (`zerosettle/migrate_tip_view_<viewId>`) are identical on both
/// platforms, so the height-bridge code is platform-agnostic. Flutter
/// rebuilds with the new height, so the surrounding layout always
/// matches the actual rendered content.
///
/// The PlatformView `viewType` differs by platform (iOS uses
/// `zerosettle/migrate_tip_view`, Android uses
/// `com.zerosettle/migrate_tip_view`) — this matches each platform's
/// factory registration (`ZSMigrateTipViewFactory.swift:188` /
/// `MigrateTipViewFactory.kt`).
///
/// Renders an empty `SizedBox.shrink()` on platforms other than iOS and
/// Android (e.g. desktop, web).
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
    // Creation params are shared between iOS and Android — both decoders
    // accept the same key set (`userId`, `backgroundColor` ARGB int).
    // Android's MigrateTipViewFactory also accepts an optional
    // `stripeCustomerId` we don't expose here for parity with iOS.
    final creationParams = <String, Object?>{
      'backgroundColor': widget.backgroundColor.toARGB32(),
      'userId': widget.userId,
    };
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return SizedBox(
          height: _height,
          child: UiKitView(
            viewType: 'zerosettle/migrate_tip_view',
            creationParams: creationParams,
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _onPlatformViewCreated,
          ),
        );
      case TargetPlatform.android:
        // F24 registers the Android factory under `com.zerosettle/...`
        // (Android convention prefixes with the org id); the per-view
        // height-bridge channel name format matches iOS exactly so
        // _onPlatformViewCreated is unchanged.
        return SizedBox(
          height: _height,
          child: AndroidView(
            viewType: 'com.zerosettle/migrate_tip_view',
            creationParams: creationParams,
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _onPlatformViewCreated,
          ),
        );
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return const SizedBox.shrink();
    }
  }
}

/// Backward-compatible typedef. Use [MigrationTipView] instead.
@Deprecated('Use MigrationTipView instead')
typedef ZSMigrateTipView = MigrationTipView;
