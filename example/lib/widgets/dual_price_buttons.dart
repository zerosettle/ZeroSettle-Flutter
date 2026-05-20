import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:zerosettle/zerosettle.dart';

/// UCB-aware, platform-aware purchase button(s) for a [Product].
///
/// ## Store routing
///
/// The "store-native" purchase targets whichever store the app runs on:
/// StoreKit / the App Store on iOS, Google Play Billing on Android. Both the
/// button label and the purchase API are selected from [defaultTargetPlatform]
/// — there is a single shared code path, not a per-platform widget.
///
/// ## Routing rule
///
/// **UCB enabled** (`ucbEnabled == true` — Android only; iOS always reports
/// `false`):
/// A single `FilledButton` labelled "Buy" is shown. Tapping it routes through
/// Google's system-level billing choice screen, which decides between Play
/// Billing and web checkout. The app must NOT show its own web-vs-store
/// picker when UCB is active.
///
/// **UCB disabled** (`ucbEnabled == false`):
/// - If [Product.webPrice] is non-null: a `FilledButton` "Pay on web" (calls
///   `purchase`) and an `OutlinedButton` for the store-native purchase
///   (labelled "App Store" / "Google Play") are both shown.
/// - If [Product.webPrice] is null: only the store-native `OutlinedButton`
///   is shown.
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

  /// Whether the host platform's native store is the Apple App Store.
  /// Drives both the store-native button label and the purchase API.
  bool get _isAppleStore => defaultTargetPlatform == TargetPlatform.iOS;

  /// User-facing name of the host platform's native store.
  String get _storeName => _isAppleStore ? 'App Store' : 'Google Play';

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

  /// Store-native purchase: StoreKit on iOS, Play Billing on Android.
  void _buyNative() => _run(
        () => _isAppleStore
            ? ZeroSettle.instance
                .purchaseViaStoreKit(productId: widget.product.id)
            : ZeroSettle.instance
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
        onPressed: _busy ? null : _buyNative,
        child: _busy ? const _ButtonSpinner() : const Text('Buy'),
      ),
    );
  }

  /// UCB disabled: web + store-native buttons (or just store-native when
  /// there is no webPrice).
  Widget _buildLegacyButtons() {
    final hasWebPrice = widget.product.webPrice != null;

    if (!hasWebPrice) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: _busy ? null : _buyNative,
          child: _busy ? const _ButtonSpinner() : Text(_storeName),
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
          onPressed: _busy ? null : _buyNative,
          child: _busy ? const _ButtonSpinner() : Text(_storeName),
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
