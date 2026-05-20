import 'package:flutter/material.dart';
import 'package:zerosettle/zerosettle.dart';

import '../../app/inherited_just_one.dart';
import '../../widgets/checkout_sheet_header.dart';
import '../../widgets/dual_price_buttons.dart';

/// The number of streak savers a given consumable product grants.
///
/// Parses the trailing integer from the product id
/// (e.g. `com.app.streaksaver5` → 5). A real app would model the grant
/// amount explicitly per product; parsing the id is a sample convenience
/// that only holds because of the `…streaksaver<N>` naming convention.
/// Falls back to 1 for any id that doesn't end in a number.
int streakSaverGrant(Product product) {
  final match = RegExp(r'(\d+)$').firstMatch(product.id);
  if (match == null) return 1;
  return int.tryParse(match.group(1) ?? '') ?? 1;
}

/// A shop screen that lists consumable streak-saver products and shows the
/// user's locally-tracked owned count.
///
/// **Local inventory**: Consumable purchases produce no server-side
/// entitlement — the app owns the count locally via
/// [UserPrefs.streakSaverCount]. Purchasing a product increments the local
/// count by [streakSaverGrant] units.
///
/// Mirrors the Android `ConsumableShopScreen` Composable.
class ConsumableShopScreen extends StatefulWidget {
  const ConsumableShopScreen({super.key});

  @override
  State<ConsumableShopScreen> createState() => _ConsumableShopScreenState();
}

class _ConsumableShopScreenState extends State<ConsumableShopScreen> {
  late Future<List<Product>> _productsFuture;
  int _owned = 0;

  @override
  void initState() {
    super.initState();
    _productsFuture = ZeroSettle.instance.getProducts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // InheritedJustOne.of requires a valid BuildContext — read it here where
    // context is fully wired to the widget tree.
    _owned = InheritedJustOne.of(context).prefs.streakSaverCount;
  }

  Future<void> _onPurchased(Product p) async {
    final grant = streakSaverGrant(p);
    final prefs = InheritedJustOne.of(context).prefs;
    await prefs.setStreakSaverCount(prefs.streakSaverCount + grant);
    if (mounted) {
      setState(() => _owned = prefs.streakSaverCount);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Streak Saver Shop')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              'You own $_owned streak saver(s)',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Product>>(
              future: _productsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final consumables = snapshot.requireData
                    .where((p) => p.type == ZSProductType.consumable)
                    .toList();

                if (consumables.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'No streak savers available right now.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: consumables.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final product = consumables[index];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            CheckoutSheetHeader(product: product),
                            const SizedBox(height: 12),
                            StreamBuilder<bool>(
                              stream: ZeroSettle.instance.isUcbEnabledUpdates,
                              initialData: false,
                              builder: (context, ucbSnapshot) {
                                return DualPriceButtons(
                                  product: product,
                                  ucbEnabled: ucbSnapshot.data ?? false,
                                  onPurchased: () => _onPurchased(product),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
