import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Embeds the native ZeroSettle offer tip inside a Flutter app:
/// SwiftUI `OfferTipView` on iOS (from ZeroSettleKit), Compose
/// `ZeroSettleOfferTip` on Android (from ZeroSettle-Android `:ui`).
///
/// The unified offer tip — it covers migration, upgrade, and web-to-web
/// flows, with server-configurable copy. Both natives are
/// `ZSOfferManager`-backed and identify-first: they resolve the active user
/// from `identify(_:)`, so call `ZeroSettle.instance.identify(...)` once
/// before this widget mounts.
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
/// factory registration (`ZSMigrateTipViewFactory.swift` /
/// `MigrateTipViewFactory.kt`). The `migrate_tip_view` wire string is a
/// historical internal name; the public widget is the generic [OfferTipView].
///
/// Renders an empty `SizedBox.shrink()` on platforms other than iOS and
/// Android (e.g. desktop, web).
///
/// Example:
/// ```dart
/// OfferTipView(
///   backgroundColor: Theme.of(context).colorScheme.primary,
/// )
/// ```
class OfferTipView extends StatefulWidget {
  /// (Deprecated) Legacy user identifier. The native offer tip is
  /// identify-first — it resolves the active user from
  /// `ZeroSettle.instance.identify(...)` — so this value is ignored on both
  /// platforms. Retained for source compatibility; removed in zerosettle 2.0.
  final String userId;

  /// Used as both the card fill AND the CTA text color on the native view
  /// (the CTA button background is hardcoded white). Pass a saturated brand
  /// color, not a neutral surface — white-on-white text won't render.
  final Color backgroundColor;

  const OfferTipView({
    super.key,
    @Deprecated(
      'Identify-first: the offer tip resolves the user from identify(_:). '
      'This parameter is ignored; will be removed in zerosettle 2.0.',
    )
    this.userId = '',
    this.backgroundColor = const Color(0xFF000000),
  });

  @override
  State<OfferTipView> createState() => _OfferTipViewState();
}

class _OfferTipViewState extends State<OfferTipView> {
  /// Native-reported intrinsic height. Starts at 0 so the widget collapses
  /// cleanly until the native view reports its first size — important when
  /// the offer tip auto-hides (no offer available) and never reports
  /// any height at all.
  double _height = 0;

  /// Whether the native view has reported a real height yet. Until it has,
  /// the Android `AndroidView` is held at a 1px height: Flutter never
  /// instantiates a platform view for a zero-area `AndroidView`, so the
  /// native factory would never run. 1px gives it non-zero area to create
  /// the view; the first `setSize` then drives the real height.
  bool _gotNativeSize = false;
  MethodChannel? _channel;

  void _onPlatformViewCreated(int viewId) {
    final channel = MethodChannel('zerosettle/migrate_tip_view_$viewId');
    _channel = channel;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'setSize') {
        final args = call.arguments as Map?;
        final h = (args?['height'] as num?)?.toDouble();
        if (h != null && mounted && (h != _height || !_gotNativeSize)) {
          setState(() {
            _height = h;
            _gotNativeSize = true;
          });
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
        // The Android factory is registered under `com.zerosettle/...`
        // (Android convention prefixes with the org id); the per-view
        // height-bridge channel name format matches iOS exactly so
        // _onPlatformViewCreated is unchanged.
        // 1px until the native view reports a real height — a zero-area
        // `AndroidView` is never instantiated by Flutter, so the factory
        // (and its `ComposeView`) would never run. Once `setSize` arrives,
        // `_gotNativeSize` flips and the box tracks the real height (which
        // collapses back to 0 when there is no offer to show).
        return SizedBox(
          height: _gotNativeSize ? _height : 1.0,
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

/// Deprecated alias for [OfferTipView] — the iOS SDK renamed
/// `MigrationTipView` to `OfferTipView` once the tip became the unified
/// surface for migration, upgrade, and web-to-web offers.
@Deprecated('Use OfferTipView instead')
typedef MigrationTipView = OfferTipView;

/// Deprecated alias for [OfferTipView].
@Deprecated('Use OfferTipView instead')
typedef ZSMigrateTipView = OfferTipView;
