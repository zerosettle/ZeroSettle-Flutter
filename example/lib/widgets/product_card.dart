import 'package:flutter/material.dart';
import '../app_state.dart';

class ProductCard extends StatelessWidget {
  final StoreProduct product;
  final bool isSelected;
  final VoidCallback onTap;

  const ProductCard({
    super.key,
    required this.product,
    required this.isSelected,
    required this.onTap,
  });

  Color get _accentColor => Color(product.colorValue);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: isSelected ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _accentColor : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isSelected ? 0.15 : 0.08),
              blurRadius: isSelected ? 12 : 8,
              offset: Offset(0, isSelected ? 6 : 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: icon + name/badge + pricing
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          product.iconData,
                          size: 36,
                          color: _accentColor,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Name + badge
                              Wrap(
                                spacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    product.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  if (product.badge != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color:
                                            _accentColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        product.badge!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: _accentColor,
                                        ),
                                      ),
                                    ),
                                ],
                              ),

                              const SizedBox(height: 4),

                              // Dual pricing
                              if (product.formattedStoreKitPrice != null) ...[
                                Row(
                                  children: [
                                    Icon(Icons.apple,
                                        size: 12, color: cs.onSurfaceVariant),
                                    const SizedBox(width: 4),
                                    Text(
                                      product.formattedStoreKitPrice!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: cs.onSurfaceVariant,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                    if (product.billingPeriod != null)
                                      Text(
                                        '/${product.billingPeriod}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: cs.onSurfaceVariant,
                                          decoration:
                                              TextDecoration.lineThrough,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                              ],

                              // Web price
                              Row(
                                children: [
                                  Text(
                                    product.formattedPrice,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.bold),
                                  ),
                                  if (product.billingPeriod != null)
                                    Text(
                                      '/${product.billingPeriod}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  if (product.savingsPercent != null &&
                                      product.savingsPercent! > 0) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Save ${product.savingsPercent}%',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Description
                    Text(
                      product.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),

                    const SizedBox(height: 12),

                    // Features
                    ...product.features.map(
                      (f) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle,
                                size: 16, color: _accentColor),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(f,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Radio button
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? _accentColor : cs.outline,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _accentColor,
                          ),
                          child: const Icon(Icons.check,
                              size: 10, color: Colors.white),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
