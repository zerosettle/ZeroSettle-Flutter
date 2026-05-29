import 'package:flutter/widgets.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../zerosettle.dart';

/// Wrap a custom offer banner to auto-report an on-screen impression when it is
/// >=50% visible, once per appearance. Auto-resolves the active offer (override
/// with productId/variantId/flowType). The SDK's own OfferTipView already tracks
/// itself natively and should NOT be wrapped.
class OfferImpression extends StatefulWidget {
  const OfferImpression({super.key, required this.child, this.productId, this.variantId, this.flowType});
  final Widget child;
  final String? productId;
  final int? variantId;
  final String? flowType;
  @override
  State<OfferImpression> createState() => _OfferImpressionState();
}

class _OfferImpressionState extends State<OfferImpression> {
  bool _reported = false;
  late final Key _key = ValueKey('zs-offer-impression-${identityHashCode(this)}');

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: _key,
      onVisibilityChanged: (info) {
        if (_reported || info.visibleFraction < 0.5) return;
        _reported = true;
        ZeroSettle.reportOfferViewed(
          productId: widget.productId, variantId: widget.variantId, flowType: widget.flowType);
      },
      child: widget.child,
    );
  }
}
