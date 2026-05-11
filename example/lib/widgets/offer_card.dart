import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zerosettle/zerosettle.dart';

/// Adopter-style headless offer card. Subscribes to an
/// [OfferManager.stateUpdates] stream and renders a Material 3 card when
/// state is `eligible` or `presented`. Demonstrates the canonical 1-call
/// checkout: `ZeroSettle.instance.presentPaymentSheet(...)` handles the
/// offer state machine automatically — no manual `present()` or
/// `markCheckoutSucceeded()` required.
///
/// Works for both migration (StoreKit → web) and upgrade
/// (storekit_to_web, web_to_web) flows — the server picks which to render.
/// The drop-in alternative is the SwiftUI-backed `MigrationTipView`.
class OfferCard extends StatefulWidget {
  final OfferManager manager;

  const OfferCard({super.key, required this.manager});

  @override
  State<OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends State<OfferCard> {
  StreamSubscription<OfferManagerState>? _stateSub;
  OfferManagerState? _state;
  bool _accepting = false;

  @override
  void initState() {
    super.initState();
    _stateSub = widget.manager.stateUpdates.listen((s) {
      if (mounted) setState(() => _state = s);
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _state;
    if (s == null ||
        s.state == OfferState.loading ||
        s.state == OfferState.ineligible ||
        s.state == OfferState.dismissed ||
        s.state == OfferState.completed ||
        s.offerData == null) {
      return const SizedBox.shrink();
    }
    final cs = Theme.of(context).colorScheme;
    final display = s.offerData!.display;
    return Card(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.card_giftcard, color: cs.onPrimaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    display.offerTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  color: cs.onPrimaryContainer,
                  tooltip: 'Dismiss',
                  onPressed: widget.manager.dismiss,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              display.offerMessage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onPrimaryContainer,
                  ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _accepting ? null : _accept,
              child: _accepting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(display.offerCta),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _accept() async {
    final s = _state;
    final offerData = s?.offerData;
    if (offerData == null) return;

    setState(() => _accepting = true);
    try {
      // Single canonical call. The SDK detects this product as the active
      // offer's checkoutProductId, runs the offer state machine through
      // its transitions (`.presented` → `.accepted`/`.completed`), and
      // surfaces them via the stateUpdates stream. No manual `present()`
      // or `markCheckoutSucceeded()` needed.
      await ZeroSettle.instance.presentPaymentSheet(
        productId: offerData.checkoutProductId,
      );
    } on ZSCancelledException {
      // User dismissed checkout — state stays .presented; retry is possible
      // by tapping the CTA again. No snackbar; cancellation isn't an error.
    } on ZeroSettleException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Checkout failed: ${e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }
}
