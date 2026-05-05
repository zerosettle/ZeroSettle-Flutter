import 'package:flutter/material.dart';
import '../app_state.dart';

/// Which button is currently mid-purchase, if any. Lets the footer show a
/// spinner only on the actually-active button while disabling its sibling.
enum PurchaseInFlight { none, webCheckout, storeKit }

class PaymentFooter extends StatelessWidget {
  final StoreProduct? selectedProduct;
  final PurchaseInFlight inFlight;
  final VoidCallback onZeroSettlePurchase;
  final VoidCallback onStoreKitPurchase;

  const PaymentFooter({
    super.key,
    required this.selectedProduct,
    required this.inFlight,
    required this.onZeroSettlePurchase,
    required this.onStoreKitPurchase,
  });

  bool get _anyInFlight => inFlight != PurchaseInFlight.none;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Selected product info
          if (selectedProduct != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedProduct!.name,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            // Store price (if available)
                            if (selectedProduct!.formattedStoreKitPrice !=
                                null) ...[
                              Row(
                                children: [
                                  Icon(
                                      Theme.of(context).platform == TargetPlatform.iOS
                                          ? Icons.apple
                                          : Icons.shopping_cart,
                                      size: 12,
                                      color: selectedProduct!.storeKitAvailable
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant
                                              .withValues(alpha: 0.5)),
                                  const SizedBox(width: 4),
                                  Text(
                                    selectedProduct!.formattedStoreKitPrice!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: selectedProduct!.storeKitAvailable
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant
                                              .withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                            ],
                            // ZeroSettle price (only when web checkout available)
                            if (selectedProduct!.webCheckoutAvailable)
                              Row(
                                children: [
                                  const Icon(Icons.credit_card,
                                      size: 12, color: Colors.green),
                                  const SizedBox(width: 4),
                                  Text(
                                    selectedProduct!.formattedPrice,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Payment buttons
          _buildPaymentButtons(context),
        ],
      ),
    );
  }

  Widget _buildPaymentButtons(BuildContext context) {
    final showWebCheckout = selectedProduct?.webCheckoutAvailable ?? false;
    final showStoreKit = selectedProduct?.storeKitAvailable ?? false;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    final storeKitInFlight = inFlight == PurchaseInFlight.storeKit;
    final webInFlight = inFlight == PurchaseInFlight.webCheckout;

    final storeButton = Expanded(
      child: FilledButton(
        onPressed: selectedProduct == null || _anyInFlight || !showStoreKit
            ? null
            : onStoreKitPurchase,
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 50),
          backgroundColor: Colors.blue,
          disabledBackgroundColor: Colors.blue.withValues(alpha: 0.3),
          disabledForegroundColor: Colors.white54,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: storeKitInFlight
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(isIOS ? Icons.apple : Icons.shopping_cart, size: 18),
                  const SizedBox(width: 6),
                  Text(isIOS ? 'App Store' : 'Play Store',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    );

    if (!showWebCheckout) {
      return Row(children: [storeButton]);
    }

    final webButton = Expanded(
      child: FilledButton(
        onPressed: selectedProduct == null || _anyInFlight
            ? null
            : onZeroSettlePurchase,
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 50),
          backgroundColor: Colors.deepPurple,
          disabledBackgroundColor: Colors.deepPurple.withValues(alpha: 0.3),
          disabledForegroundColor: Colors.white54,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: webInFlight
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.credit_card, size: 18),
                  SizedBox(width: 6),
                  Text('Pay with Card',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    );

    if (!showStoreKit) {
      return Row(children: [webButton]);
    }

    return Row(
      children: [
        storeButton,
        const SizedBox(width: 12),
        webButton,
      ],
    );
  }
}
