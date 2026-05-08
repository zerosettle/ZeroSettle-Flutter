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
    setState(() => _accepting = true);
    try {
      final url = await widget.manager.startCheckout();
      if (url == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not start checkout. Try again later.'),
          ),
        );
      }
      // Real checkout would happen via in-app browser / payment sheet here;
      // SDK's startCheckout already handles presentation in iOS Kit.
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }
}
