import 'package:flutter/material.dart';
import 'package:zerosettle/zerosettle.dart';

// ── Pure helpers ─────────────────────────────────────────────────────────────

/// Classifies a product's billing interval: 0 = weekly, 1 = monthly,
/// 2 = yearly, 3 = unknown. Drives both the sort order and the label.
///
/// [Product.billingInterval] is a free-form string and the backend does not
/// always emit it — a `null`/unrecognized interval ranks last (and labels
/// fall back to the display name).
int _intervalRank(Product p) {
  final i = p.billingInterval?.toLowerCase();
  if (i == null) return 3;
  if (i.contains('week')) return 0;
  if (i.contains('month')) return 1;
  if (i.contains('year') || i.contains('annual')) return 2;
  return 3;
}

/// The subscription plans within [products]: auto-renewable subscriptions
/// only, sorted weekly → monthly → yearly (unknown intervals last).
List<Product> subscriptionPlans(List<Product> products) {
  final subs = products
      .where((p) => p.type == ZSProductType.autoRenewableSubscription)
      .toList();
  subs.sort((a, b) => _intervalRank(a).compareTo(_intervalRank(b)));
  return subs;
}

/// A human-readable label for [product]'s billing cadence — "Weekly" /
/// "Monthly" / "Yearly". Falls back to [Product.displayName] when the
/// backend hasn't supplied a recognizable `billingInterval`.
String planLabel(Product product) {
  switch (_intervalRank(product)) {
    case 0:
      return 'Weekly';
    case 1:
      return 'Monthly';
    case 2:
      return 'Yearly';
    default:
      return product.displayName;
  }
}

/// The preferred default plan id: the monthly plan if present, otherwise the
/// first plan. Returns `null` only when [plans] is empty.
String? defaultPlanId(List<Product> plans) {
  for (final p in plans) {
    if (_intervalRank(p) == 1) return p.id;
  }
  return plans.isEmpty ? null : plans.first.id;
}

// ── PlanSelector widget ──────────────────────────────────────────────────────

/// A selectable list of subscription [plans]. Each row shows the plan label
/// and its price; the selected row is highlighted with a primary-color border
/// and a checkmark.
///
/// Mirrors the JustOne Android `PlanSelector` Composable.
class PlanSelector extends StatelessWidget {
  const PlanSelector({
    super.key,
    required this.plans,
    required this.selectedId,
    required this.onSelect,
  });

  /// Plans to display — already filtered and sorted (see [subscriptionPlans]).
  final List<Product> plans;

  /// [Product.id] of the currently selected plan.
  final String selectedId;

  /// Called with the [Product.id] when the user taps a row.
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final plan in plans)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _PlanRow(
              label: planLabel(plan),
              price:
                  (plan.webPrice ?? plan.storeKitPrice ?? plan.appStorePrice)
                          ?.formatted ??
                      '—',
              selected: plan.id == selectedId,
              onTap: () => onSelect(plan.id),
            ),
          ),
      ],
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.label,
    required this.price,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String price;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final muted = theme.colorScheme.outlineVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? accent : muted,
            width: selected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? accent : muted,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: theme.textTheme.titleMedium),
            ),
            Text(
              price,
              style: theme.textTheme.titleMedium?.copyWith(
                color: selected ? accent : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
