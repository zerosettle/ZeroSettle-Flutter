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
  final Set<String> _transferringIds = {};
  final Set<String> _checkingUpgradeIds = {};

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
            const SizedBox(height: 12),
            // 1.3.0 demo: hasActiveEntitlement convenience accessor.
            // Checks the first product in the catalog and shows the bool result.
            OutlinedButton.icon(
              onPressed: _appState.products.isEmpty ? null : _checkFirstProductEntitlement,
              icon: const Icon(Icons.verified_outlined, size: 18),
              label: Text(
                _appState.products.isEmpty
                    ? 'Check entitlement (no products yet)'
                    : 'Check ${_appState.products.first.id} entitlement',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkFirstProductEntitlement() async {
    final productId = _appState.products.firstOrNull?.id;
    if (productId == null) return;
    try {
      final active = await ZeroSettle.instance.hasActiveEntitlement(productId: productId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('hasActiveEntitlement($productId) = $active'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ZeroSettleException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message}')),
      );
    }
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
                                color: _sourceColor(ent.source)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _sourceLabel(ent.source),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _sourceColor(ent.source),
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
                _detailRow(context, 'Source', _sourceLabel(ent.source)),
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
                ..._buildEntitlementActions(context, ent),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Action buttons available for an entitlement. Specific to each entitlement's
  // source and status:
  //
  // - StoreKit + signed-in user → "Transfer to current account"
  //   (transferStoreKitOwnershipToCurrentUser).
  // - Active subscription with an expiry → "Check for upgrade"
  //   (fetchUpgradeOfferConfig + presentUpgradeOffer).
  List<Widget> _buildEntitlementActions(BuildContext context, Entitlement ent) {
    final widgets = <Widget>[];

    if (ent.source == EntitlementSource.storeKit &&
        _appState.currentIdentity is IdentityUser) {
      widgets.add(const SizedBox(height: 12));
      widgets.add(
        OutlinedButton.icon(
          icon: const Icon(Icons.swap_horiz, size: 18),
          label: const Text('Transfer to current account'),
          onPressed: _transferringIds.contains(ent.id)
              ? null
              : () => _transferStoreKit(ent),
        ),
      );
    }

    if (ent.isActive && ent.expiresAt != null) {
      widgets.add(const SizedBox(height: 8));
      widgets.add(
        OutlinedButton.icon(
          icon: const Icon(Icons.upgrade, size: 18),
          label: const Text('Check for upgrade'),
          onPressed: _checkingUpgradeIds.contains(ent.id)
              ? null
              : () => _checkUpgradeOffer(ent),
        ),
      );
    }

    return widgets;
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
    // Skip if no usable identity yet — restoreEntitlements throws
    // ZSUserNotIdentifiedException for deferred or null identities.
    if (_appState.currentIdentity == null ||
        _appState.currentIdentity is IdentityDeferred) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final entitlements = await ZeroSettle.instance.restoreEntitlements();
      _appState.setEntitlements(entitlements);
      setState(() => _lastRefresh = DateTime.now());
    } on ZeroSettleException {
      // Silently handle errors
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      );

      if (!mounted) return;

      final label = switch (result) {
        CancelFlowCancelled() => 'Subscription cancelled',
        CancelFlowRetained() => 'Subscription retained',
        CancelFlowPaused() => 'Subscription paused',
        CancelFlowDismissed() => 'Cancel flow dismissed',
      };

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(label)),
      );

      if (result is CancelFlowCancelled) {
        _appState.deactivateSubscription();
      }
    } on ZeroSettleException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message}')),
      );
    } finally {
      setState(() => _isCancelling = false);
    }
  }

  // -- 1.3.0 demos --

  /// Calls [ZeroSettle.transferStoreKitOwnershipToCurrentUser]. Replaces the
  /// deprecated `claimEntitlement`. Only meaningful for StoreKit-source
  /// entitlements when an [IdentityUser] is active.
  Future<void> _transferStoreKit(Entitlement ent) async {
    setState(() => _transferringIds.add(ent.id));
    String message;
    try {
      await ZeroSettle.instance.transferStoreKitOwnershipToCurrentUser(
        productId: ent.productId,
      );
      message = 'Transferred ${ent.productId} to current account';
      // Refresh entitlements so the UI reflects the new ownership.
      try {
        final entitlements = await ZeroSettle.instance.restoreEntitlements();
        _appState.setEntitlements(entitlements);
      } catch (_) {}
    } on ZeroSettleException catch (e) {
      message = 'Transfer failed: ${e.message}';
    } finally {
      if (mounted) {
        setState(() => _transferringIds.remove(ent.id));
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Calls [ZeroSettle.fetchUpgradeOfferConfig]; if available, presents a
  /// confirmation card and offers to launch [ZeroSettle.presentUpgradeOffer].
  Future<void> _checkUpgradeOffer(Entitlement ent) async {
    setState(() => _checkingUpgradeIds.add(ent.id));
    UpgradeOfferConfig? config;
    String? errorMessage;
    try {
      config = await ZeroSettle.instance.fetchUpgradeOfferConfig(
        productId: ent.productId,
      );
    } on ZeroSettleException catch (e) {
      errorMessage = e.message;
    } finally {
      if (mounted) {
        setState(() => _checkingUpgradeIds.remove(ent.id));
      }
    }
    if (!mounted) return;

    if (errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upgrade check failed: $errorMessage')),
      );
      return;
    }
    if (config == null || !config.available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No upgrade available right now')),
      );
      return;
    }

    final shouldShow = await showDialog<bool>(
      context: context,
      builder: (ctx) => _UpgradeOfferDialog(config: config!),
    );
    if (shouldShow != true || !mounted) return;

    try {
      final result = await ZeroSettle.instance.presentUpgradeOffer(
        productId: ent.productId,
      );
      if (!mounted) return;
      final label = switch (result) {
        UpgradeOfferUpgraded() => 'Upgraded successfully',
        UpgradeOfferDeclined() => 'Upgrade declined',
        UpgradeOfferDismissed() => 'Upgrade sheet dismissed',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(label)));
      // Refresh after a successful upgrade.
      if (result is UpgradeOfferUpgraded) {
        await _refresh();
      }
    } on ZeroSettleException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upgrade error: ${e.message}')),
      );
    }
  }

  // -- Source presentation helpers --

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
}

class _UpgradeOfferDialog extends StatelessWidget {
  final UpgradeOfferConfig config;

  const _UpgradeOfferDialog({required this.config});

  @override
  Widget build(BuildContext context) {
    final target = config.targetProduct;
    final savings = config.savingsPercent;
    final display = config.display;
    return AlertDialog(
      title: Text(display?.title ?? 'Upgrade available'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (display?.body != null && display!.body.isNotEmpty)
            Text(display.body)
          else
            const Text('A better plan is available for your subscription.'),
          const SizedBox(height: 16),
          if (target != null) ...[
            _kvRow('Plan', target.name),
            _kvRow(
              'Price',
              _formatPrice(target.priceCents, target.currency),
            ),
            _kvRow('Billing', target.billingLabel),
          ],
          if (savings != null) _kvRow('Savings', '$savings%'),
          if (config.upgradeType != null)
            _kvRow('Upgrade type', config.upgradeType!),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(display?.dismissText ?? 'Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(display?.ctaText ?? 'Show upgrade'),
        ),
      ],
    );
  }

  Widget _kvRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(int cents, String currency) {
    final value = cents / 100.0;
    final symbol = switch (currency.toUpperCase()) {
      'USD' || 'CAD' || 'AUD' => '\$',
      'EUR' => '€',
      'GBP' => '£',
      _ => '',
    };
    return '$symbol${value.toStringAsFixed(2)} $currency';
  }
}
