import 'package:flutter/material.dart';
import 'package:zerosettle/zerosettle.dart';
import '../app_state.dart';

/// Lists the full transaction history for the currently identified user.
///
/// Demonstrates the 1.3.0 [ZeroSettle.fetchTransactionHistory] API. Unlike
/// `restoreEntitlements`, this returns *all* transactions — including consumed
/// consumables, expired subscriptions, refunds, and failed payments.
class TransactionsScreen extends StatefulWidget {
  final AppState appState;

  const TransactionsScreen({super.key, required this.appState});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  bool _isLoading = false;
  String? _error;
  List<CheckoutTransaction> _transactions = const [];
  DateTime? _lastRefresh;

  AppState get _appState => widget.appState;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (_appState.currentIdentity is IdentityDeferred ||
        _appState.currentIdentity == null) {
      setState(() {
        _transactions = const [];
        _error = 'Identify (sign in or continue as guest) to load transactions.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final txns = await ZeroSettle.instance.fetchTransactionHistory();
      if (!mounted) return;
      setState(() {
        _transactions = txns;
        _lastRefresh = DateTime.now();
      });
    } on ZeroSettleException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _appState,
      builder: (context, _) {
        return Scaffold(
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar.large(
                  title: const Text('Transactions'),
                  actions: [
                    IconButton(
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      onPressed: _isLoading ? null : _refresh,
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
                if (_lastRefresh != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Text(
                        'Last refreshed ${_formatTime(_lastRefresh!)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                  ),
                if (_error != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Card(
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onErrorContainer),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                else if (_transactions.isEmpty && !_isLoading)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmpty(context),
                  )
                else
                  SliverList.builder(
                    itemCount: _transactions.length,
                    itemBuilder: (context, index) =>
                        _buildTransactionTile(context, _transactions[index]),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No transactions yet',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Pull down to refresh.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(BuildContext context, CheckoutTransaction txn) {
    final cs = Theme.of(context).colorScheme;
    final amount = _formatAmount(txn.amountCents, txn.currency);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 40,
              decoration: BoxDecoration(
                color: _statusColor(txn.status),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    txn.productName ?? txn.productId,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _Chip(
                        label: _sourceLabel(txn.source),
                        color: _sourceColor(txn.source),
                      ),
                      const SizedBox(width: 6),
                      _Chip(
                        label: txn.status.rawValue,
                        color: _statusColor(txn.status),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDateTime(txn.purchasedAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              amount,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatAmount(int? cents, String? currency) {
    if (cents == null) return '—';
    final value = cents / 100.0;
    final symbol = switch ((currency ?? 'USD').toUpperCase()) {
      'USD' || 'CAD' || 'AUD' => '\$',
      'EUR' => '€',
      'GBP' => '£',
      _ => '',
    };
    return '$symbol${value.toStringAsFixed(2)}';
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _sourceLabel(EntitlementSource source) {
    return switch (source) {
      EntitlementSource.storeKit => 'StoreKit',
      EntitlementSource.playStore => 'Play Store',
      EntitlementSource.webCheckout => 'Web',
    };
  }

  Color _sourceColor(EntitlementSource source) {
    return switch (source) {
      EntitlementSource.storeKit => Colors.blue,
      EntitlementSource.playStore => Colors.teal,
      EntitlementSource.webCheckout => Colors.green,
    };
  }

  Color _statusColor(TransactionStatus status) {
    return switch (status) {
      TransactionStatus.completed => Colors.green,
      TransactionStatus.pending => Colors.orange,
      TransactionStatus.processing => Colors.orange,
      TransactionStatus.failed => Colors.red,
      TransactionStatus.refunded => Colors.grey,
    };
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: color),
      ),
    );
  }
}
