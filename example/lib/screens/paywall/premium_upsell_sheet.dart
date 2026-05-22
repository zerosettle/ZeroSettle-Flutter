import 'package:flutter/material.dart';
import 'package:zerosettle/zerosettle.dart';

import '../../widgets/checkout_sheet_header.dart';
import '../../widgets/dual_price_buttons.dart';
import '../../widgets/plan_selector.dart';

/// Shows a condensed premium upsell as a modal bottom sheet.
///
/// Fetches the catalog, lets the user pick a billing plan (weekly / monthly /
/// yearly) via [PlanSelector], and renders [CheckoutSheetHeader] +
/// [DualPriceButtons] for the selected plan, with a "Maybe later" escape hatch.
///
/// Mirrors the visual hierarchy of the Android `PremiumUpsellSheet` Composable.
Future<void> showPremiumUpsell(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _PremiumUpsellSheet(),
  );
}

class _PremiumUpsellSheet extends StatefulWidget {
  const _PremiumUpsellSheet();

  @override
  State<_PremiumUpsellSheet> createState() => _PremiumUpsellSheetState();
}

class _PremiumUpsellSheetState extends State<_PremiumUpsellSheet> {
  late Future<List<Product>> _productsFuture;

  /// The user's explicitly-picked plan id. Null until they tap a row — until
  /// then the default plan (monthly, else first) is used.
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    // Actively fetch the catalog — the sheet must not assume an earlier
    // call warmed the SDK's product cache (`getProducts()`). `fetchProducts()`
    // loads it (or surfaces a real error instead of an empty list).
    _productsFuture =
        ZeroSettle.instance.fetchProducts().then((catalog) => catalog.products);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      // Lift the sheet above the software keyboard when it's open.
      padding: MediaQuery.viewInsetsOf(context),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ────────────────────────────────────────────────────
              Text(
                'Go Premium',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Unlimited habits, streak savers, and more.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              // ── Product section ───────────────────────────────────────────
              FutureBuilder<List<Product>>(
                future: _productsFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text(
                      "Couldn't load premium plans.\n${snapshot.error}",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    );
                  }
                  if (!snapshot.hasData) {
                    return const SizedBox(
                      height: 80,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final plans = subscriptionPlans(snapshot.requireData);
                  if (plans.isEmpty) {
                    return Text(
                      'Premium isn\'t available right now.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    );
                  }

                  // Effective selection: the user's explicit pick while it's
                  // still a valid plan, otherwise the default.
                  final selectedId = (_selectedId != null &&
                          plans.any((p) => p.id == _selectedId))
                      ? _selectedId!
                      : defaultPlanId(plans)!;
                  final selected = plans.firstWhere((p) => p.id == selectedId);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CheckoutSheetHeader(product: selected),
                      const SizedBox(height: 16),
                      PlanSelector(
                        plans: plans,
                        selectedId: selectedId,
                        onSelect: (id) => setState(() => _selectedId = id),
                      ),
                      const SizedBox(height: 20),
                      DualPriceButtons(
                        product: selected,
                        onPurchased: () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 12),

              // ── Dismiss ───────────────────────────────────────────────────
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text(
                    'Maybe later',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
