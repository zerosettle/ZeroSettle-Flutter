import 'package:flutter/material.dart';
import 'package:zerosettle/zerosettle.dart';

/// Renders a product's name, description, and best-available price.
///
/// Price priority: web checkout → store-native (StoreKit / Play) → App Store
/// → fallback dash. Mirrors the visual hierarchy of the native Android
/// `CheckoutSheetHeader` Composable.
class CheckoutSheetHeader extends StatelessWidget {
  const CheckoutSheetHeader({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priceText = product.webPrice?.formatted ??
        product.storeKitPrice?.formatted ??
        product.appStorePrice?.formatted ??
        '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          product.displayName,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          product.productDescription,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          priceText,
          style: theme.textTheme.headlineSmall,
        ),
      ],
    );
  }
}
