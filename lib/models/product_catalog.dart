import 'remote_config.dart';
import 'zs_product.dart';

/// The result of fetching the product catalog.
class ProductCatalog {
  final List<Product> products;
  final RemoteConfig? config;

  const ProductCatalog({
    required this.products,
    this.config,
  });

  factory ProductCatalog.fromMap(Map<String, dynamic> map) {
    final productsList = (map['products'] as List)
        .map((e) => Product.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    return ProductCatalog(
      products: productsList,
      config: map['config'] != null
          ? RemoteConfig.fromMap(Map<String, dynamic>.from(map['config'] as Map))
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'products': products.map((p) => p.toMap()).toList(),
      'config': config?.toMap(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductCatalog &&
          config == other.config;

  @override
  int get hashCode => Object.hash(products, config);
}
