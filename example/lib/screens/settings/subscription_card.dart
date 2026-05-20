import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zerosettle/zerosettle.dart';

import '../../app/routes.dart';

/// Subscription card shown in [SettingsScreen].
///
/// Uses a [StreamBuilder] over [ZeroSettle.instance.entitlementUpdates] as the
/// reactive source. A non-blocking seed load is kicked off in [initState] via
/// [ZeroSettle.instance.getEntitlements] so that the card populates from cache
/// on first build without blocking the render cycle.
///
/// Branch logic:
/// - No active entitlement → "Upgrade to Premium" [FilledButton] that calls
///   [ZeroSettle.instance.presentUpgradeOffer].
/// - Active entitlement → shows plan + status + optional expiry date, a
///   "Cancel subscription" [OutlinedButton] (navigates to cancel flow), and
///   a "Resume" [FilledButton] when paused. A [FutureBuilder] checks
///   upgrade availability and shows an "Upgrade available ›" row when the
///   config reports [UpgradeOfferConfig.available] == true.
///
/// Mirrors the `SubscriptionCard` Composable in the JustOne Android sample.
class SubscriptionCard extends StatefulWidget {
  const SubscriptionCard({super.key});

  @override
  State<SubscriptionCard> createState() => _SubscriptionCardState();
}

class _SubscriptionCardState extends State<SubscriptionCard> {
  /// Cached seed from the last [ZeroSettle.instance.getEntitlements] call.
  /// Starts null — the StreamBuilder's initialData starts as null, so it
  /// renders the no-sub branch until the seed or first stream event arrives.
  List<Entitlement>? _seed;

  /// Single-slot cache of the in-flight upgrade-offer future, keyed by the
  /// product id it was created for. When the active subscription's product
  /// changes the future is recreated, so a stale `available: true` from a
  /// previous product is never reused.
  Future<UpgradeOfferConfig>? _upgradeFuture;
  String? _upgradeFutureProductId;

  @override
  void initState() {
    super.initState();
    ZeroSettle.instance
        .getEntitlements()
        .then((v) {
          if (mounted) setState(() => _seed = v);
        })
        .catchError((_) {});
  }

  /// Returns the upgrade-offer future for [productId], recreating it whenever
  /// [productId] differs from the slot's current key. Safe to call from
  /// `build` — it only assigns fields, never calls `setState`.
  Future<UpgradeOfferConfig> _upgradeConfigFor(String productId) {
    if (_upgradeFutureProductId != productId || _upgradeFuture == null) {
      _upgradeFutureProductId = productId;
      _upgradeFuture =
          ZeroSettle.instance.fetchUpgradeOfferConfig(productId: productId);
    }
    return _upgradeFuture!;
  }

  Future<void> _presentUpgrade(BuildContext ctx, String? productId) async {
    try {
      await ZeroSettle.instance.presentUpgradeOffer(productId: productId);
      if (!ctx.mounted) return;
    } catch (_) {
      // Dismissed / not available — no error surfaced.
    }
  }

  Future<void> _resume(BuildContext ctx, String productId) async {
    try {
      await ZeroSettle.instance.resumeSubscription(productId: productId);
    } catch (e) {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('Could not resume: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Entitlement>>(
      stream: ZeroSettle.instance.entitlementUpdates,
      builder: (ctx, snap) {
        // The stream is canonical once it emits; until then fall back to the
        // cached seed loaded in initState. Reading the seed in the builder
        // (rather than via `initialData`) means a `setState`-driven rebuild
        // after the seed resolves is reflected — `initialData` is only
        // consulted on a StreamBuilder's first build.
        final entitlements = snap.data ?? _seed ?? const <Entitlement>[];

        // Find the first active entitlement (consumables never produce one —
        // confirmed JustOne behaviour; no productType field on Entitlement).
        Entitlement? active;
        for (final e in entitlements) {
          if (e.isActive) {
            active = e;
            break;
          }
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Subscription',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (active == null) _buildNoSubBranch(ctx) else _buildActiveBranch(ctx, active),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoSubBranch(BuildContext ctx) {
    final theme = Theme.of(ctx);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Unlock all features with a premium plan.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => _presentUpgrade(ctx, null),
          child: const Text('Upgrade to Premium'),
        ),
      ],
    );
  }

  Widget _buildActiveBranch(BuildContext ctx, Entitlement sub) {
    final theme = Theme.of(ctx);

    final statusLabel = switch (true) {
      _ when sub.isTrial => 'Free trial',
      _ when sub.isPaused => 'Paused',
      _ when sub.willRenew => 'Renews',
      _ => 'Active',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Plan name
        Text(
          'Plan',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(sub.productId, style: theme.textTheme.bodyMedium),

        const SizedBox(height: 8),

        // Status
        Text(
          'Status',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(statusLabel, style: theme.textTheme.bodyMedium),

        // Expiry date
        if (sub.expiresAt != null) ...[
          const SizedBox(height: 4),
          Text(
            'Expires: ${_formatDate(sub.expiresAt!)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],

        // Upgrade availability check
        FutureBuilder<UpgradeOfferConfig>(
          future: _upgradeConfigFor(sub.productId),
          builder: (ctx, upgradeSnap) {
            if (upgradeSnap.hasData && upgradeSnap.data!.available) {
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: InkWell(
                  onTap: () => _presentUpgrade(ctx, sub.productId),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Upgrade available',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      Text(
                        '›',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),

        const SizedBox(height: 12),

        // Resume button — only when paused
        if (sub.isPaused) ...[
          FilledButton(
            onPressed: () => _resume(ctx, sub.productId),
            child: const Text('Resume'),
          ),
          const SizedBox(height: 8),
        ],

        // Cancel button
        OutlinedButton(
          onPressed: () => ctx.go(Routes.cancelFlow(sub.productId)),
          child: const Text('Cancel subscription'),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
