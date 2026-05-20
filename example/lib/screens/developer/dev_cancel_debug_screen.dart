import 'package:flutter/material.dart';
import 'package:zerosettle/zerosettle.dart';

/// Developer inspector for the cancel flow API.
///
/// "Fetch config" calls [ZeroSettle.instance.fetchCancelFlowConfig] and
/// renders the config summary. Raw action buttons (cancel, pause, resume) use
/// a product-ID [TextField] and the matching headless SDK calls, surfacing
/// results in a [SnackBar].
///
/// Mirrors [CancelDebugScreen.kt] from the JustOne Android sample.
class DevCancelDebugScreen extends StatefulWidget {
  const DevCancelDebugScreen({super.key});

  @override
  State<DevCancelDebugScreen> createState() => _DevCancelDebugScreenState();
}

class _DevCancelDebugScreenState extends State<DevCancelDebugScreen> {
  final _productIdController = TextEditingController();

  bool _fetchBusy = false;
  bool _cancelBusy = false;
  bool _pauseBusy = false;
  bool _resumeBusy = false;

  CancelFlowConfig? _config;
  String? _fetchError;

  @override
  void dispose() {
    _productIdController.dispose();
    super.dispose();
  }

  Future<void> _fetchConfig(BuildContext ctx) async {
    if (_fetchBusy) return;
    setState(() {
      _fetchBusy = true;
      _config = null;
      _fetchError = null;
    });
    try {
      final config = await ZeroSettle.instance.fetchCancelFlowConfig();
      if (!ctx.mounted) return;
      setState(() => _config = config);
    } catch (e) {
      if (!ctx.mounted) return;
      setState(() => _fetchError = e.toString());
    } finally {
      if (mounted) setState(() => _fetchBusy = false);
    }
  }

  Future<void> _cancelSubscription(BuildContext ctx) async {
    if (_cancelBusy) return;
    final productId = _productIdController.text.trim();
    setState(() => _cancelBusy = true);
    try {
      await ZeroSettle.instance.cancelSubscription(productId: productId);
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('Cancelled: $productId')),
      );
    } catch (e) {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('Cancel failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _cancelBusy = false);
    }
  }

  Future<void> _pauseSubscription(BuildContext ctx) async {
    if (_pauseBusy) return;
    final productId = _productIdController.text.trim();
    setState(() => _pauseBusy = true);
    try {
      final resumeDate = await ZeroSettle.instance.pauseSubscription(
        productId: productId,
        pauseDurationDays: 30,
      );
      if (!ctx.mounted) return;
      final msg = resumeDate != null
          ? 'Paused: $productId — resumes $resumeDate'
          : 'Paused: $productId (no resume date)';
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('Pause failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _pauseBusy = false);
    }
  }

  Future<void> _resumeSubscription(BuildContext ctx) async {
    if (_resumeBusy) return;
    final productId = _productIdController.text.trim();
    setState(() => _resumeBusy = true);
    try {
      await ZeroSettle.instance.resumeSubscription(productId: productId);
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('Resumed: $productId')),
      );
    } catch (e) {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('Resume failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _resumeBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    final anyBusy = _cancelBusy || _pauseBusy || _resumeBusy;

    return Scaffold(
      appBar: AppBar(title: const Text('Cancel flow (debug)')),
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
            _row(context, 'enabled', '${config.enabled}'),
            _row(context, 'questions', '${config.questions.length}'),
            _row(context, 'offer.enabled', config.offer != null ? '${config.offer!.enabled}' : 'n/a'),
            _row(context, 'pause.enabled', config.pause != null ? '${config.pause!.enabled}' : 'n/a'),
          ],
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // -- Product ID input --
          Text('Headless actions', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _productIdController,
            decoration: const InputDecoration(
              labelText: 'Product ID',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),

          // -- Action buttons --
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: anyBusy ? null : () => _cancelSubscription(context),
                  child: _cancelBusy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: anyBusy ? null : () => _pauseSubscription(context),
                  child: _pauseBusy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Pause (30d)'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: anyBusy ? null : () => _resumeSubscription(context),
                  child: _resumeBusy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Resume'),
                ),
              ),
            ],
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
