import 'package:flutter/material.dart';
import 'package:zerosettle/zerosettle.dart';

import '../../widgets/migration_tip_card.dart';

/// Developer inspector for the user-offer API.
///
/// A "Fetch user offer" button calls [ZeroSettle.instance.fetchUserOffer] and
/// renders the resulting [UserOfferResponse] as labeled key/value rows.
/// Also embeds [MigrationTipCard], the cross-platform migration tip view
/// (renders on both iOS and Android).
///
/// Mirrors [OffersScreen.kt] from the JustOne Android sample.
class DevOffersScreen extends StatefulWidget {
  const DevOffersScreen({super.key});

  @override
  State<DevOffersScreen> createState() => _DevOffersScreenState();
}

class _DevOffersScreenState extends State<DevOffersScreen> {
  bool _busy = false;
  UserOfferResponse? _result;
  String? _error;

  Future<void> _fetch(BuildContext ctx) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _result = null;
      _error = null;
    });
    try {
      final response = await ZeroSettle.instance.fetchUserOffer();
      if (!ctx.mounted) return;
      setState(() => _result = response);
    } catch (e) {
      if (!ctx.mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('Offers')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Cross-platform migration tip view (renders on iOS and Android).
          const MigrationTipCard(),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _busy ? null : () => _fetch(context),
            child: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Fetch user offer'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _row(context, 'error', _error!),
          ],
          if (result != null) ...[
            const SizedBox(height: 16),
            Text('Response', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            _row(context, 'userId', result.userId),
            _row(context, 'appId', result.appId),
            _row(context, 'isSandbox', '${result.isSandbox}'),
            _row(context, 'serverTime', result.serverTime),
            const SizedBox(height: 12),
            Text('Subscription', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            _row(context, 'type', result.subscription.type),
            _row(context, 'productId', result.subscription.productId ?? 'n/a'),
            const SizedBox(height: 12),
            Text('Offer', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            _row(context, 'actionType', result.offer.actionType.name),
            _row(context, 'isEligible', '${result.offer.isEligible}'),
            _row(context, 'savingsPercent', '${result.offer.savingsPercent}%'),
            _row(context, 'checkoutProductId', result.offer.checkoutProductId ?? 'n/a'),
            _row(context, 'fromProductId', result.offer.fromProductId ?? 'n/a'),
            _row(context, 'freeTrialDays', '${result.offer.freeTrialDays}'),
            _row(context, 'source', result.offer.source?.name ?? 'n/a'),
            _row(context, 'requiresAppleCancel', '${result.offer.requiresAppleCancel}'),
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final baseStyle = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: RichText(
        text: TextSpan(
          style: baseStyle,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
