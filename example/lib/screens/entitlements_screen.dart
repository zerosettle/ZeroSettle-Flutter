import 'package:flutter/material.dart';
import 'package:zerosettle/zerosettle.dart';
import '../app_state.dart';

class EntitlementsScreen extends StatefulWidget {
  final AppState appState;

  const EntitlementsScreen({super.key, required this.appState});

  @override
  State<EntitlementsScreen> createState() => _EntitlementsScreenState();
}

class _EntitlementsScreenState extends State<EntitlementsScreen> {
  bool _isLoading = false;
  bool _isCancelling = false;
  DateTime? _lastRefresh;
  final Set<String> _expandedIds = {};

  AppState get _appState => widget.appState;

  List<Entitlement> get _entitlements => _appState.entitlements;

  int get _activeCount => _entitlements.where((e) => e.isActive).length;
  int get _expiredCount => _entitlements.where((e) => !e.isActive).length;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _appState,
      builder: (context, _) {
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar.large(title: const Text('Entitlements')),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList.list(
                  children: [
                    // Summary card
                    _buildSummary(context),
                    const SizedBox(height: 16),

                    // Refresh button
                    FilledButton.icon(
                      onPressed: _isLoading ? null : _refresh,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.refresh),
                      label: const Text('Refresh Entitlements'),
                    ),
                    const SizedBox(height: 8),

                    // Cancel subscription button
                    if (_entitlements.any((e) => e.isActive && e.expiresAt != null))
                      FilledButton.icon(
                        onPressed: _isCancelling ? null : _cancelSubscription,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        icon: _isCancelling
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.close),
                        label: const Text('Cancel Subscription'),
                      ),
                    const SizedBox(height: 24),

                    // Entitlements list
                    if (_entitlements.isEmpty && !_isLoading)
                      _buildEmpty(context)
                    else
                      ..._sortedEntitlements.map(
                        (ent) => _buildEntitlementTile(context, ent),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Entitlement> get _sortedEntitlements {
    final sorted = List<Entitlement>.from(_entitlements);
    sorted.sort((a, b) {
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      if (a.expiresAt != null && b.expiresAt != null) {
        return b.expiresAt!.compareTo(a.expiresAt!);
      }
      return a.expiresAt != null ? -1 : 1;
    });
    return sorted;
  }

  Widget _buildSummary(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _summaryRow(context, 'Total Entitlements', '${_entitlements.length}'),
            const SizedBox(height: 8),
            _summaryRow(context, 'Active', '$_activeCount', color: Colors.green),
            const SizedBox(height: 8),
            _summaryRow(context, 'Expired', '$_expiredCount', color: Colors.red),
            if (_lastRefresh != null) ...[
              const SizedBox(height: 8),
              _summaryRow(
                context,
                'Last Refresh',
                '${_lastRefresh!.hour}:${_lastRefresh!.minute.toString().padLeft(2, '0')}',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(BuildContext context, String label, String value,
      {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: color,
              ),
        ),
      ],
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            'No entitlements found',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntitlementTile(BuildContext context, Entitlement ent) {
    final isExpanded = _expandedIds.contains(ent.id);
    final statusColor = _statusColor(ent);
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            if (isExpanded) {
              _expandedIds.remove(ent.id);
            } else {
              _expandedIds.add(ent.id);
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main row
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ent.productId,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            // Source chip
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: ent.source == EntitlementSource.storeKit
                                    ? Colors.blue.withValues(alpha: 0.15)
                                    : Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                ent.source == EntitlementSource.storeKit
                                    ? 'StoreKit'
                                    : 'Web',
                                style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      ent.source == EntitlementSource.storeKit
                                          ? Colors.blue
                                          : Colors.green,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Status
                            Text(
                              ent.isActive ? 'Active' : 'Expired',
                              style: TextStyle(
                                fontSize: 12,
                                color: ent.isActive ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),

              // Expanded details
              if (isExpanded) ...[
                const Divider(height: 24),
                _detailRow(context, 'ID', ent.id),
                _detailRow(context, 'Product ID', ent.productId),
                _detailRow(
                  context,
                  'Source',
                  ent.source == EntitlementSource.storeKit
                      ? 'StoreKit'
                      : 'Web Checkout',
                ),
                _detailRow(context, 'Active', ent.isActive ? 'Yes' : 'No'),
                _detailRow(context, 'Purchased', _formatDateTime(ent.purchasedAt)),
                if (ent.expiresAt != null) ...[
                  _detailRow(context, 'Expires', _formatDateTime(ent.expiresAt!)),
                  if (ent.isActive) ...[
                    () {
                      final remaining =
                          ent.expiresAt!.difference(DateTime.now());
                      if (remaining.isNegative) return const SizedBox.shrink();
                      return _detailRow(
                        context,
                        'Time Remaining',
                        _formatDuration(remaining),
                      );
                    }(),
                  ],
                ] else
                  _detailRow(context, 'Expires', 'Never (lifetime)'),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(left: 22, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          Flexible(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(Entitlement ent) {
    if (!ent.isActive) return Colors.red;
    if (ent.expiresAt != null) {
      final threshold = DateTime.now().add(const Duration(days: 7));
      if (ent.expiresAt!.isBefore(threshold)) return Colors.orange;
    }
    return Colors.green;
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration d) {
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes}m';
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);

    try {
      final entitlements =
          await ZeroSettle.instance.restoreEntitlements(userId: _appState.userId);
      _appState.setEntitlements(entitlements);
      setState(() => _lastRefresh = DateTime.now());
    } on ZSException {
      // Silently handle errors
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelSubscription() async {
    final activeSubscription = _entitlements
        .where((e) => e.isActive && e.expiresAt != null)
        .firstOrNull;
    if (activeSubscription == null) return;

    setState(() => _isCancelling = true);

    try {
      final result = await ZeroSettle.instance.presentCancelFlow(
        productId: activeSubscription.productId,
        userId: _appState.userId,
      );

      if (!mounted) return;

      final label = switch (result) {
        CancelFlowResult.cancelled => 'Subscription cancelled',
        CancelFlowResult.retained => 'Subscription retained',
        CancelFlowResult.dismissed => 'Cancel flow dismissed',
      };

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(label)),
      );

      if (result == CancelFlowResult.cancelled) {
        _appState.deactivateSubscription();
      }
    } on ZSException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message}')),
      );
    } finally {
      setState(() => _isCancelling = false);
    }
  }
}
