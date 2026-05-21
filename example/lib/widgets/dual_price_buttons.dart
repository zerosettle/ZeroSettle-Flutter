import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:zerosettle/zerosettle.dart';

/// Platform-adaptive purchase button(s) for a [Product].
///
/// **Android** — a single "Buy" [FilledButton]. The purchase is initiated via
/// `purchaseViaPlayBilling`; Google's User Choice Billing screen presents the
/// Play-vs-web choice, so the app must never hand-roll its own picker. A
/// two-button web-vs-store layout does not make sense here.
///
/// **iOS** — there is no User Choice Billing, so the app surfaces the choice
/// itself:
/// - [Product.webPrice] non-null → a "Pay on web" [FilledButton] (web checkout
///   via `purchase`) plus an "App Store" [OutlinedButton] (`purchaseViaStoreKit`).
/// - [Product.webPrice] null → only the "App Store" button.
class DualPriceButtons extends StatefulWidget {
  const DualPriceButtons({
    super.key,
    required this.product,
    required this.onPurchased,
  });

  final Product product;
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

  void _buyStoreKit() => _run(
        () => ZeroSettle.instance.purchaseViaStoreKit(productId: widget.product.id),
      );

  void _buyPlayBilling() => _run(
        () => ZeroSettle.instance
            .purchaseViaPlayBilling(productId: widget.product.id),
      );

  @override
  Widget build(BuildContext context) {
    // The web-vs-store picker only makes sense on iOS, where there is no
    // User Choice Billing. On Android, Google's UCB screen presents the
    // billing choice — the app shows a single "Buy" button.
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _buildAndroidButton();
    }
    return _buildIosButtons();
  }

  /// Android: a single "Buy" button. `purchaseViaPlayBilling` triggers
  /// Google's User Choice Billing screen, which routes Play-vs-web.
  Widget _buildAndroidButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _busy ? null : _buyPlayBilling,
        child: _busy ? const _ButtonSpinner() : const Text('Buy'),
      ),
    );
  }

  /// iOS: no UCB, so the app surfaces the choice — "Pay on web" + "App Store"
  /// (or just "App Store" when the product has no web price).
  Widget _buildIosButtons() {
    if (widget.product.webPrice == null) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: _busy ? null : _buyStoreKit,
          child: _busy ? const _ButtonSpinner() : const Text('App Store'),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: _busy ? null : _buyWeb,
          child: _busy ? const _ButtonSpinner() : const Text('Pay on web'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _busy ? null : _buyStoreKit,
          child: _busy ? const _ButtonSpinner() : const Text('App Store'),
        ),
      ],
    );
  }
}

/// Shared 16×16 progress spinner sized to sit inside a button.
class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
