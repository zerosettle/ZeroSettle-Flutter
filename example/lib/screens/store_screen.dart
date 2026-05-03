import 'package:flutter/material.dart';
import 'package:zerosettle/zerosettle.dart';
import '../app_state.dart';
import '../widgets/product_card.dart';
import '../widgets/payment_footer.dart';

class StoreScreen extends StatefulWidget {
  final AppState appState;

  const StoreScreen({super.key, required this.appState});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  StoreProduct? _selectedProduct;
  bool _isProcessing = false;

  AppState get _appState => widget.appState;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _appState,
      builder: (context, _) {
        return Scaffold(
          body: Stack(
            children: [
              // Main scrollable content
              CustomScrollView(
                slivers: [
                  SliverAppBar.large(title: const Text('Store')),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 160),
                    sliver: SliverList.list(
                      children: [
                        // Header
                        _buildHeader(context),
                        const SizedBox(height: 24),

                        if (_appState.isLoading && _appState.storeProducts.isEmpty)
                          _buildLoading(context)
                        else if (_appState.storeProducts.isEmpty)
                          _buildEmpty(context)
                        else ...[
                          // Consumables
                          if (_appState.consumables.isNotEmpty)
                            _buildSection(
                              context,
                              title: 'Gem Bundles',
                              icon: Icons.auto_awesome,
                              iconColor: Colors.cyan,
                              products: _appState.consumables,
                            ),

                          // Non-consumables
                          if (_appState.nonConsumables.isNotEmpty)
                            _buildSection(
                              context,
                              title: 'Permanent Unlocks',
                              icon: Icons.lock_open,
                              iconColor: Colors.green,
                              products: _appState.nonConsumables,
                            ),

                          // Subscriptions
                          if (_appState.subscriptions.isNotEmpty)
                            _buildSection(
                              context,
                              title: 'Premium',
                              icon: Icons.workspace_premium,
                              iconColor: Colors.orange,
                              products: _appState.subscriptions,
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              // Sticky payment footer
              if (_appState.storeProducts.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: PaymentFooter(
                    selectedProduct: _selectedProduct,
                    isProcessing: _isProcessing,
                    onZeroSettlePurchase: _handlePurchase,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.indigo, Colors.purple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(Icons.diamond, size: 30, color: Colors.white),
        ),
        const SizedBox(height: 16),
        Text(
          'Power Up',
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Grab gems or go premium',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading products...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.shopping_bag_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text('No Products Available',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Check back later for new offerings',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<StoreProduct> products,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        ...products.map(
          (product) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ProductCard(
              product: product,
              isSelected: _selectedProduct?.id == product.id,
              onTap: () => _selectProduct(product),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  void _selectProduct(StoreProduct product) {
    setState(() {
      if (_selectedProduct?.id == product.id) {
        _selectedProduct = null;
      } else {
        _selectedProduct = product;
      }
    });
  }

  Future<void> _handlePurchase() async {
    final product = _selectedProduct;
    if (product == null) return;

    setState(() => _isProcessing = true);

    try {
      await ZeroSettle.instance.presentPaymentSheet(
        productId: product.id,
        userId: _appState.userId,
      );

      if (!mounted) return;

      // Update local state based on product type
      _completePurchase(product);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully purchased ${product.name}'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Refresh entitlements
      try {
        final entitlements = await ZeroSettle.instance
            .restoreEntitlements(userId: _appState.userId);
        _appState.setEntitlements(entitlements);
      } catch (_) {}

      setState(() => _selectedProduct = null);
    } on ZSException {
      // Silently handle errors (cancelled, checkout failed, etc.)
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _completePurchase(StoreProduct product) {
    switch (product.type) {
      case StoreProductType.consumable:
        if (product.gemAmount != null) {
          _appState.addGems(product.gemAmount!);
        }
      case StoreProductType.nonConsumable:
        _appState.unlockProduct(product.id);
      case StoreProductType.subscription:
        final expiryDate = _expiryForDuration(product.duration);
        _appState.activateSubscription(
          plan: product.name,
          expiryDate: expiryDate,
        );
    }

    _appState.recordPurchase(PurchaseRecord(
      productName: product.name,
      amount: product.price,
      paymentMethod: PaymentMethod.webCheckout,
    ));
  }

  DateTime _expiryForDuration(SubscriptionDuration? duration) {
    final now = DateTime.now();
    switch (duration) {
      case SubscriptionDuration.weekly:
        return now.add(const Duration(days: 7));
      case SubscriptionDuration.monthly:
        return now.add(const Duration(days: 30));
      case SubscriptionDuration.yearly:
        return now.add(const Duration(days: 365));
      case null:
        return now.add(const Duration(days: 30));
    }
  }
}
