import 'package:flutter/material.dart';
import 'package:zerosettle/zerosettle.dart';

import '../../widgets/checkout_sheet_header.dart';
import '../../widgets/dual_price_buttons.dart';

/// Shows a condensed premium upsell as a modal bottom sheet.
///
/// Resolves the first [ZSProductType.autoRenewableSubscription] product from
/// [ZeroSettle.instance.getProducts], renders [CheckoutSheetHeader] +
/// [DualPriceButtons], and offers a "Maybe later" escape hatch.
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

  @override
  void initState() {
    super.initState();
    _productsFuture = ZeroSettle.instance.getProducts();
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
                  if (!snapshot.hasData) {
                    return const SizedBox(
                      height: 80,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final products = snapshot.requireData;
                  final subs = products
                      .where((p) =>
                          p.type == ZSProductType.autoRenewableSubscription)
                      .toList();
                  final subscription = subs.isEmpty ? null : subs.first;

                  if (subscription == null) {
                    return Text(
                      'Premium isn\'t available right now.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CheckoutSheetHeader(product: subscription),
                      const SizedBox(height: 20),
                      DualPriceButtons(
                        product: subscription,
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
