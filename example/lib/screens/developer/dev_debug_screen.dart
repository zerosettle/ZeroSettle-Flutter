import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zerosettle/zerosettle.dart';

/// Developer inspector for raw SDK state and the live event log.
///
/// - Action buttons invoke headless SDK calls and render results inline.
/// - The "SDK events" section accumulates all [ZeroSettleEvent]s emitted since
///   the screen was opened, newest first, with a HH:mm:ss timestamp prefix.
///
/// Mirrors [DebugScreen.kt] from the JustOne Android sample.
class DevDebugScreen extends StatefulWidget {
  const DevDebugScreen({super.key});

  @override
  State<DevDebugScreen> createState() => _DevDebugScreenState();
}

class _DevDebugScreenState extends State<DevDebugScreen> {
  // -- Event log --
  final List<String> _events = [];
  StreamSubscription<ZeroSettleEvent>? _eventSub;

  // -- Action busy guards --
  bool _txnBusy = false;
  bool _productsBusy = false;
  bool _restoreBusy = false;
  bool _versionBusy = false;
  bool _ucbBusy = false;

  // -- Action results --
  List<CheckoutTransaction>? _txnHistory;
  List<Product>? _products;
  List<Entitlement>? _entitlements;
  String? _sdkVersion;
  bool? _ucbEnabled;
  String? _actionError;

  @override
  void initState() {
    super.initState();
    _eventSub = ZeroSettle.instance.events.listen((event) {
      if (!mounted) return;
      final now = DateTime.now();
      final ts =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      setState(() => _events.insert(0, '[$ts] ${_describeEvent(event)}'));
    });
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }

  // -- Event description --

  String _describeEvent(ZeroSettleEvent event) => switch (event) {
        ZSEventOfferShown e => 'offerShown productId=${e.productId}',
        ZSEventOfferAccepted e => 'offerAccepted productId=${e.productId}',
        ZSEventOfferDismissed e => 'offerDismissed productId=${e.productId}',
        ZSEventOfferEvaluationFailed e =>
          'offerEvaluationFailed reason=${e.reason}',
        ZSEventPurchaseSucceeded e =>
          'purchaseSucceeded productId=${e.productId} txnId=${e.transactionId}',
        ZSEventPurchaseFailed e =>
          'purchaseFailed productId=${e.productId} reason=${e.reason}',
        ZSEventMigrationCompleted e =>
          'migrationCompleted productId=${e.productId}',
        ZSEventSyncFailed e =>
          'syncFailed token=${e.purchaseToken} attempts=${e.attempts} terminal=${e.terminal}',
        ZSEventEntitlementsRefreshed e =>
          'entitlementsRefreshed count=${e.count}',
        ZSEventPendingActionShown e =>
          'pendingActionShown actionType=${e.actionType}',
        ZSEventUnknown e => 'unknown type=${e.type}',
      };

  // -- Actions --

  Future<void> _fetchTxnHistory(BuildContext ctx) async {
    if (_txnBusy) return;
    setState(() {
      _txnBusy = true;
      _txnHistory = null;
      _actionError = null;
    });
    try {
      final list = await ZeroSettle.instance.fetchTransactionHistory();
      if (!ctx.mounted) return;
      setState(() => _txnHistory = list);
    } catch (e) {
      if (!ctx.mounted) return;
      setState(() => _actionError = 'txn history: $e');
    } finally {
      if (mounted) setState(() => _txnBusy = false);
    }
  }

  Future<void> _fetchProducts(BuildContext ctx) async {
    if (_productsBusy) return;
    setState(() {
      _productsBusy = true;
      _products = null;
      _actionError = null;
    });
    try {
      final list = await ZeroSettle.instance.getProducts();
      if (!ctx.mounted) return;
      setState(() => _products = list);
    } catch (e) {
      if (!ctx.mounted) return;
      setState(() => _actionError = 'products: $e');
    } finally {
      if (mounted) setState(() => _productsBusy = false);
    }
  }

  Future<void> _restoreEntitlements(BuildContext ctx) async {
    if (_restoreBusy) return;
    setState(() {
      _restoreBusy = true;
      _entitlements = null;
      _actionError = null;
    });
    try {
      final list = await ZeroSettle.instance.restoreEntitlements();
      if (!ctx.mounted) return;
      setState(() => _entitlements = list);
    } catch (e) {
      if (!ctx.mounted) return;
      setState(() => _actionError = 'restore: $e');
    } finally {
      if (mounted) setState(() => _restoreBusy = false);
    }
  }

  Future<void> _getSdkVersion(BuildContext ctx) async {
    if (_versionBusy) return;
    setState(() {
      _versionBusy = true;
      _sdkVersion = null;
      _actionError = null;
    });
    try {
      final v = await ZeroSettle.instance.getSdkVersion();
      if (!ctx.mounted) return;
      setState(() => _sdkVersion = v);
    } catch (e) {
      if (!ctx.mounted) return;
      setState(() => _actionError = 'sdkVersion: $e');
    } finally {
      if (mounted) setState(() => _versionBusy = false);
    }
  }

  Future<void> _getUcbEnabled(BuildContext ctx) async {
    if (_ucbBusy) return;
    setState(() {
      _ucbBusy = true;
      _ucbEnabled = null;
      _actionError = null;
    });
    try {
      final enabled = await ZeroSettle.instance.getIsUcbEnabled();
      if (!ctx.mounted) return;
      setState(() => _ucbEnabled = enabled);
    } catch (e) {
      if (!ctx.mounted) return;
      setState(() => _actionError = 'ucbEnabled: $e');
    } finally {
      if (mounted) setState(() => _ucbBusy = false);
    }
  }

  // -- Row helper (mirrors sibling dev screens) --

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

  // -- Build --

  @override
  Widget build(BuildContext context) {
    final anyBusy = _txnBusy || _productsBusy || _restoreBusy || _versionBusy || _ucbBusy;
    final txnHistory = _txnHistory;
    final products = _products;
    final entitlements = _entitlements;

    return Scaffold(
      appBar: AppBar(title: const Text('Debug')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ----------------------------------------------------------------
          // Action buttons
          // ----------------------------------------------------------------
          Text('Actions', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),

          ElevatedButton(
            onPressed: anyBusy ? null : () => _fetchTxnHistory(context),
            child: _txnBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Fetch transaction history'),
          ),
          const SizedBox(height: 8),

          ElevatedButton(
            onPressed: anyBusy ? null : () => _fetchProducts(context),
            child: _productsBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Fetch products'),
          ),
          const SizedBox(height: 8),

          ElevatedButton(
            onPressed: anyBusy ? null : () => _restoreEntitlements(context),
            child: _restoreBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Restore entitlements'),
          ),
          const SizedBox(height: 8),

          ElevatedButton(
            onPressed: anyBusy ? null : () => _getSdkVersion(context),
            child: _versionBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Get SDK version'),
          ),
          const SizedBox(height: 8),

          ElevatedButton(
            onPressed: anyBusy ? null : () => _getUcbEnabled(context),
            child: _ucbBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('UCB enabled?'),
          ),

          // ----------------------------------------------------------------
          // Action results
          // ----------------------------------------------------------------
          if (_actionError != null) ...[
            const SizedBox(height: 12),
            _row(context, 'error', _actionError!),
          ],

          if (_sdkVersion != null) ...[
            const SizedBox(height: 12),
            _row(context, 'sdkVersion', _sdkVersion!),
          ],

          if (_ucbEnabled != null) ...[
            const SizedBox(height: 12),
            _row(context, 'ucbEnabled', '$_ucbEnabled'),
          ],

          if (products != null) ...[
            const SizedBox(height: 16),
            Text(
              'Products (${products.length})',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            for (final p in products) _row(context, p.id, p.type.rawValue),
          ],

          if (entitlements != null) ...[
            const SizedBox(height: 16),
            Text(
              'Entitlements (${entitlements.length})',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            for (final e in entitlements)
              _row(context, e.productId,
                  '${e.source.rawValue} active=${e.isActive}'),
          ],

          if (txnHistory != null) ...[
            const SizedBox(height: 16),
            Text(
              'Transaction history (${txnHistory.length})',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            for (final t in txnHistory)
              _row(
                context,
                t.id,
                '${t.productId} ${t.status.rawValue} ${t.amountCents != null ? '${t.amountCents}¢' : '—'}',
              ),
          ],

          // ----------------------------------------------------------------
          // SDK event log
          // ----------------------------------------------------------------
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SDK events',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (_events.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _events.clear()),
                  child: const Text('Clear'),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (_events.isEmpty)
            Text(
              'No events yet',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final e in _events)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        e,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
