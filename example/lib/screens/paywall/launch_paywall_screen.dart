import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zerosettle/zerosettle.dart';

import '../../app/inherited_just_one.dart';
import '../../app/routes.dart';
import '../../widgets/checkout_sheet_header.dart';
import '../../widgets/dual_price_buttons.dart';

/// Full-screen premium gate shown at app launch when the user has not
/// purchased a subscription and hasn't dismissed the paywall.
///
/// Resolves the subscription product from [ZeroSettle.instance.getProducts],
/// renders [CheckoutSheetHeader] + [DualPriceButtons], and offers a "Continue
/// with free version" escape hatch that writes [UserPrefs.setPaywallDismissedAt]
/// before navigating to [Routes.home].
///
/// Mirrors the visual hierarchy of the Android `LaunchPaywallScreen` Composable.
class LaunchPaywallScreen extends StatefulWidget {
  const LaunchPaywallScreen({super.key});

  @override
  State<LaunchPaywallScreen> createState() => _LaunchPaywallScreenState();
}

class _LaunchPaywallScreenState extends State<LaunchPaywallScreen> {
  late Future<List<Product>> _productsFuture;

  @override
  void initState() {
    super.initState();
    // Actively fetch the catalog — a product-display screen must not assume
    // the SDK's product cache (`getProducts()`) was pre-warmed by an earlier
    // `identify()`. `fetchProducts()` loads it (or surfaces a real error).
    _productsFuture =
        ZeroSettle.instance.fetchProducts().then((catalog) => catalog.products);
  }

  Future<void> _dismiss(BuildContext context) async {
    await InheritedJustOne.of(context)
        .prefs
        .setPaywallDismissedAt(DateTime.now());
    if (context.mounted) {
      context.go(Routes.home);
    }
  }

  void _finish(BuildContext context) {
    if (context.mounted) {
      context.go(Routes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Hero / value-prop area ──────────────────────────────────
              Text(
                'Unlock unlimited habits',
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Build the life you want — track every habit that matters to you. '
                'Premium unlocks unlimited habits, streak savers so you never lose '
                'your momentum, and detailed insights to keep you on track.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // ── Subscription section ────────────────────────────────────
              FutureBuilder<List<Product>>(
                future: _productsFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text(
                      "Couldn't load Premium right now.\n${snapshot.error}",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    );
                  }
                  if (!snapshot.hasData) {
                    return const SizedBox(
                      height: 120,
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
                        onPurchased: () => _finish(context),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              // ── Free-version escape hatch ───────────────────────────────
              TextButton(
                onPressed: () => _dismiss(context),
                child: Text(
                  'Continue with free version',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
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
