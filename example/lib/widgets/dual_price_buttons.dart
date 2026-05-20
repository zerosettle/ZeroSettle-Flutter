import 'package:flutter/material.dart';
import 'package:zerosettle/zerosettle.dart';

/// UCB-aware purchase button(s) for a [Product].
///
/// ## Routing rule
///
/// **UCB enabled** (`ucbEnabled == true`):
/// A single `FilledButton` labelled "Buy" is shown. Tapping it calls
/// `ZeroSettle.instance.purchaseViaPlayBilling` — Google's system-level
/// choice screen handles whether the purchase goes through Play Billing or
/// web checkout. The app must NOT show its own web-vs-Play picker when UCB
/// is active.
///
/// **UCB disabled** (`ucbEnabled == false`):
/// - If [Product.webPrice] is non-null: a `FilledButton` "Pay on web" (calls
///   `purchase`) and an `OutlinedButton` "Google Play" (calls
///   `purchaseViaPlayBilling`) are both shown.
/// - If [Product.webPrice] is null: only the `OutlinedButton` "Google Play"
///   is shown.
///
/// ## Flutter vs Android gap
///
/// The Android `DualPriceButtons` Composable reads `product.playStorePrice`
/// to decide whether a Play SKU is available and to compute a savings
/// percentage. Flutter's [Product] model has no `playStorePrice` field —
/// the UCB/non-UCB distinction is therefore driven solely by the `ucbEnabled`
/// parameter, and the "Pay on web" label never includes a savings percentage.
///
/// ## Usage
///
/// The `ucbEnabled` parameter is a plain `bool` so the widget is trivially
/// testable in isolation. Callers that need to react to live UCB state should
/// wrap this widget in a `StreamBuilder` over
/// `ZeroSettle.instance.isUcbEnabledUpdates`:
///
/// ```dart
/// StreamBuilder<bool>(
///   stream: ZeroSettle.instance.isUcbEnabledUpdates,
///   initialData: false,
///   builder: (context, snapshot) => DualPriceButtons(
///     product: product,
///     ucbEnabled: snapshot.requireData,
///     onPurchased: onPurchased,
///   ),
/// )
/// ```
class DualPriceButtons extends StatefulWidget {
  const DualPriceButtons({
    super.key,
    required this.product,
    required this.ucbEnabled,
    required this.onPurchased,
  });

  final Product product;
  final bool ucbEnabled;
  final VoidCallback onPurchased;

  @override
  State<DualPriceButtons> createState() => _DualPriceButtonsState();
}

class _DualPriceButtonsState extends State<DualPriceButtons> {
  bool _busy = false;

  Future<void> _run(Future<dynamic> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      widget.onPurchased();
    } on ZSCancelledException {
      // User cancelled — swallow silently, no SnackBar.
    } on ZeroSettleException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _buyWeb() => _run(
        () => ZeroSettle.instance.purchase(productId: widget.product.id),
      );

  void _buyPlay() => _run(
        () => ZeroSettle.instance
            .purchaseViaPlayBilling(productId: widget.product.id),
      );

  @override
  Widget build(BuildContext context) {
    if (widget.ucbEnabled) {
      return _buildUcbButton();
    }
    return _buildLegacyButtons();
  }

  /// UCB enabled: single "Buy" FilledButton.
  Widget _buildUcbButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _busy ? null : _buyPlay,
        child: _busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Buy'),
      ),
    );
  }

  /// UCB disabled: web + Play buttons (or just Play when no webPrice).
  Widget _buildLegacyButtons() {
    final hasWebPrice = widget.product.webPrice != null;

    if (!hasWebPrice) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: _busy ? null : _buyPlay,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Google Play'),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: _busy ? null : _buyWeb,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Pay on web'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _busy ? null : _buyPlay,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Google Play'),
        ),
      ],
    );
  }
}
