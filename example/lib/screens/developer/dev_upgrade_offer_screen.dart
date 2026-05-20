import 'package:flutter/material.dart';
import 'package:zerosettle/zerosettle.dart';

/// Developer inspector for the upgrade-offer API.
///
/// "Fetch config" calls [ZeroSettle.instance.fetchUpgradeOfferConfig] and
/// renders the config. "Present upgrade offer" calls
/// [ZeroSettle.instance.presentUpgradeOffer] and surfaces the
/// [UpgradeOfferResult] variant in a [SnackBar].
///
/// Mirrors [UpgradeOfferScreen.kt] from the JustOne Android sample.
class DevUpgradeOfferScreen extends StatefulWidget {
  const DevUpgradeOfferScreen({super.key});

  @override
  State<DevUpgradeOfferScreen> createState() => _DevUpgradeOfferScreenState();
}

class _DevUpgradeOfferScreenState extends State<DevUpgradeOfferScreen> {
  bool _fetchBusy = false;
  bool _presentBusy = false;

  UpgradeOfferConfig? _config;
  String? _fetchError;

  Future<void> _fetchConfig(BuildContext ctx) async {
    if (_fetchBusy) return;
    setState(() {
      _fetchBusy = true;
      _config = null;
      _fetchError = null;
    });
    try {
      final config = await ZeroSettle.instance.fetchUpgradeOfferConfig();
      if (!ctx.mounted) return;
      setState(() => _config = config);
    } catch (e) {
      if (!ctx.mounted) return;
      setState(() => _fetchError = e.toString());
    } finally {
      if (mounted) setState(() => _fetchBusy = false);
    }
  }

  Future<void> _presentOffer(BuildContext ctx) async {
    if (_presentBusy) return;
    setState(() => _presentBusy = true);
    try {
      final result = await ZeroSettle.instance.presentUpgradeOffer();
      if (!ctx.mounted) return;
      final label = switch (result) {
        UpgradeOfferUpgraded() => 'Upgraded',
        UpgradeOfferDeclined() => 'Declined',
        UpgradeOfferDismissed() => 'Dismissed',
      };
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('Upgrade offer result: $label')),
      );
    } catch (e) {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('Present failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _presentBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;

    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade offer')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // -- Config fetch --
          ElevatedButton(
            onPressed: _fetchBusy ? null : () => _fetchConfig(context),
            child: _fetchBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Fetch config'),
          ),
          if (_fetchError != null) ...[
            const SizedBox(height: 8),
            _row(context, 'error', _fetchError!),
          ],
          if (config != null) ...[
            const SizedBox(height: 16),
            Text('Config', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            _row(context, 'available', '${config.available}'),
            _row(context, 'reason', config.reason ?? 'n/a'),
            _row(context, 'upgradeType', config.upgradeType ?? 'n/a'),
            _row(context, 'savingsPercent', config.savingsPercent != null ? '${config.savingsPercent}%' : 'n/a'),
            _row(context, 'currentProduct', config.currentProduct?.name ?? 'n/a'),
            _row(context, 'targetProduct', config.targetProduct?.name ?? 'n/a'),
            _row(context, 'display.title', config.display?.title ?? 'n/a'),
          ],
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // -- Present offer --
          ElevatedButton(
            onPressed: _presentBusy ? null : () => _presentOffer(context),
            child: _presentBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Present upgrade offer'),
          ),
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
