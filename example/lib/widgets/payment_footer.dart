import 'package:flutter/material.dart';
import '../app_state.dart';

class PaymentFooter extends StatelessWidget {
  final StoreProduct? selectedProduct;
  final bool isProcessing;
  final VoidCallback onZeroSettlePurchase;

  const PaymentFooter({
    super.key,
    required this.selectedProduct,
    required this.isProcessing,
    required this.onZeroSettlePurchase,
  });

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
                            // StoreKit price (if available)
                            if (selectedProduct!.formattedStoreKitPrice !=
                                null) ...[
                              Row(
                                children: [
                                  Icon(Icons.apple,
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
                            // ZeroSettle price
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
          Row(
            children: [
              // App Store button (disabled with tooltip for Flutter)
              Expanded(
                child: Tooltip(
                  message: 'StoreKit purchases are only\navailable in the native iOS app',
                  child: FilledButton(
                    onPressed: null, // Always disabled in Flutter
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 50),
                      backgroundColor: Colors.blue,
                      disabledBackgroundColor: Colors.blue.withValues(alpha: 0.3),
                      disabledForegroundColor: Colors.white54,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.apple, size: 18),
                        SizedBox(width: 6),
                        Text('App Store',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // ZeroSettle (web checkout) button
              Expanded(
                child: FilledButton(
                  onPressed: selectedProduct == null || isProcessing
                      ? null
                      : onZeroSettlePurchase,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 50),
                    backgroundColor: Colors.deepPurple,
                    disabledBackgroundColor:
                        Colors.deepPurple.withValues(alpha: 0.3),
                    disabledForegroundColor: Colors.white54,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isProcessing
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
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
