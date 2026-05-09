import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zerosettle/zerosettle.dart';

/// Adopter-style custom migration offer card. Subscribes to a
/// [MigrationManager.stateUpdates] stream and renders a Material 3 card
/// when the state is `eligible` / `presented`. Demonstrates the headless
/// path; the drop-in `MigrationTipView` widget is the alternative.
class MigrationOfferCard extends StatefulWidget {
  final MigrationManager manager;

  const MigrationOfferCard({super.key, required this.manager});

  @override
  State<MigrationOfferCard> createState() => _MigrationOfferCardState();
}

class _MigrationOfferCardState extends State<MigrationOfferCard> {
  StreamSubscription<MigrationManagerState>? _stateSub;
  MigrationManagerState? _state;
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
        s.state == MigrationOfferState.loading ||
        s.state == MigrationOfferState.ineligible ||
        s.state == MigrationOfferState.dismissed ||
        s.state == MigrationOfferState.completed ||
        s.offerData == null) {
      return const SizedBox.shrink();
    }
    final cs = Theme.of(context).colorScheme;
    final prompt = s.offerData!.prompt;
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
                    prompt.title,
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
              prompt.message,
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
                  : Text(prompt.ctaText),
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
      // 1. Transition the manager state machine to .presented. This also
      //    arms the SDK so the next CheckoutSheet creates a
      //    migration-discounted PaymentIntent.
      await widget.manager.present();

      // 2. Drive the SDK's existing CheckoutSheet — same machinery JustOne's
      //    `.checkoutSheet(item:)` SwiftUI modifier uses. This respects the
      //    dashboard's `CheckoutType` setting (webview / safariVC / safari)
      //    via RemoteConfig, so adopters get the in-app WebView, system
      //    SFSafariViewController, or external Safari per their tenant
      //    configuration. We do NOT use `manager.startCheckout()` —
      //    that's only the URL-only escape hatch for adopters who need raw
      //    transport control.
      final txn = await ZeroSettle.instance.presentPaymentSheet(
        productId: offerData.prompt.productId,
      );

      // 3. Tell the manager the checkout completed. State transitions to
      //    .accepted; the rebuild via `stateUpdates` flips the card into
      //    its accepted-confirmation copy.
      await widget.manager.markCheckoutSucceeded(transactionId: txn.id);
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
