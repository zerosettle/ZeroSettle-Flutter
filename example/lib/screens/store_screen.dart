import 'package:flutter/material.dart';
import 'package:zerosettle/zerosettle.dart';
import '../app_state.dart';
import '../widgets/product_card.dart';
import '../widgets/payment_footer.dart';

class StoreScreen extends StatefulWidget {
  final AppState appState;
  final VoidCallback onSignIn;

  const StoreScreen({
    super.key,
    required this.appState,
    required this.onSignIn,
  });

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  StoreProduct? _selectedProduct;
  PurchaseInFlight _inFlight = PurchaseInFlight.none;

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
                    inFlight: _inFlight,
                    onZeroSettlePurchase: _handlePurchase,
                    onStoreKitPurchase: _handleStoreKitPurchase,
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
    final isDeferred = _appState.currentIdentity is IdentityDeferred;
    final hasNoIdentity = _appState.currentIdentity == null;

    // Deferred (or no-identity) callers get a sign-in CTA — the catalog only
    // loads after `identify()` resolves to a user/anonymous session.
    if (isDeferred || hasNoIdentity) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.person_outline,
                size: 48,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('Sign in to load products',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'The product catalog is fetched once you identify with the SDK. Sign in or continue as guest to load it.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: widget.onSignIn,
              icon: const Icon(Icons.login),
              label: const Text('Sign in'),
            ),
          ],
        ),
      );
    }

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

    setState(() => _inFlight = PurchaseInFlight.webCheckout);

    try {
      // 1.3.0 demo — single-product lookup. Re-fetches the freshest cached
      // detail before showing the payment sheet so the confirmation copy
      // reflects any server-side changes since the catalog was loaded.
      Product? fresh;
      try {
        fresh = await ZeroSettle.instance.product(productId: product.id);
      } catch (_) {
        // Non-fatal — fall back to local view-model copy.
      }

      if (mounted) {
        final confirmed = await _showPurchaseConfirmation(product, fresh);
        if (!confirmed) {
          if (mounted) setState(() => _inFlight = PurchaseInFlight.none);
          return;
        }
      }

      // Routes to the SwiftUI CheckoutSheet on iOS — Stripe-hosted web checkout.
      await ZeroSettle.instance.presentPaymentSheet(
        productId: product.id,
      );

      if (!mounted) return;

      _completePurchase(product, PaymentMethod.webCheckout);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully purchased ${product.name}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      try {
        final entitlements = await ZeroSettle.instance.restoreEntitlements();
        _appState.setEntitlements(entitlements);
      } catch (_) {}
      setState(() => _selectedProduct = null);
    } on ZeroSettleException {
      // Silently handle errors (cancelled, checkout failed, etc.)
    } finally {
      if (mounted) setState(() => _inFlight = PurchaseInFlight.none);
    }
  }

  /// 1.3.0 demo — explicit native StoreKit 2 purchase via the new SDK
  /// primitive. ZeroSettleKit's Transaction.updates listener auto-syncs the
  /// resulting transaction to the ZeroSettle backend; we just react to the
  /// returned [CheckoutTransaction] and refresh local state.
  Future<void> _handleStoreKitPurchase() async {
    final product = _selectedProduct;
    if (product == null) return;

    setState(() => _inFlight = PurchaseInFlight.storeKit);

    try {
      // Diagnostic: confirm SDK identity state at the exact moment of purchase.
      // The StoreKit appAccountToken is derived from this userId — if it's
      // null/empty/anonymous-UUID, the backend won't attribute the purchase
      // to the signed-in user.
      final identity = _appState.currentIdentity;
      final sdkUserId = await ZeroSettle.instance.getCurrentUserId();
      final isBoot = await ZeroSettle.instance.getIsBootstrapped();
      debugPrint(
        '[ZS] purchaseViaStoreKit: productId=${product.id}'
        ' appStateIdentity=${identity.runtimeType}'
        ' sdkCurrentUserId=$sdkUserId'
        ' isBootstrapped=$isBoot',
      );

      final txn = await ZeroSettle.instance.purchaseViaStoreKit(
        productId: product.id,
      );

      debugPrint(
        '[ZS] purchaseViaStoreKit: returned txn'
        ' id=${txn.id}'
        ' productId=${txn.productId}'
        ' source=${txn.source}',
      );

      if (!mounted) return;

      _completePurchase(product, PaymentMethod.storeKit);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Purchased ${product.name} via App Store (txn ${txn.id})',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Entitlements will arrive via the entitlement-updates EventChannel
      // once ZeroSettleKit syncs the StoreKit transaction. Refresh
      // proactively so the UI reflects state without waiting on a delegate.
      try {
        final entitlements = await ZeroSettle.instance.restoreEntitlements();
        _appState.setEntitlements(entitlements);
      } catch (_) {}
      setState(() => _selectedProduct = null);
    } on ZeroSettleException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('App Store purchase failed: ${e.message}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _inFlight = PurchaseInFlight.none);
    }
  }

  void _completePurchase(StoreProduct product, PaymentMethod method) {
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
      paymentMethod: method,
    ));
  }

  /// Confirmation sheet shown before [ZeroSettle.presentPaymentSheet]. When a
  /// fresh [Product] is available from `ZeroSettle.product(productId:)`, its
  /// data takes precedence so the user sees the most recent name/price/copy.
  Future<bool> _showPurchaseConfirmation(
    StoreProduct product,
    Product? fresh,
  ) async {
    final name = fresh?.displayName ?? product.name;
    final description = fresh?.productDescription ?? product.description;
    final priceText = fresh?.webPrice != null
        ? '\$${(fresh!.webPrice!.amountCents / 100).toStringAsFixed(2)}'
        : product.formattedPrice;
    final cs = Theme.of(context).colorScheme;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                priceText,
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Continue'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return result == true;
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
