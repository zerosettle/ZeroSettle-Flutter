import 'package:flutter/material.dart';
import 'package:zerosettle/zerosettle.dart';

enum SubscriptionStatus { active, inactive, expired }

enum PaymentMethod {
  webCheckout('ZeroSettle'),
  storeKit('App Store');

  const PaymentMethod(this.displayName);
  final String displayName;
}

enum StoreProductType { consumable, nonConsumable, subscription }

enum SubscriptionDuration {
  weekly('week'),
  monthly('month'),
  yearly('year');

  const SubscriptionDuration(this.label);
  final String label;
}

class PurchaseRecord {
  final String id;
  final DateTime date;
  final String productName;
  final double amount;
  final PaymentMethod paymentMethod;
  final String? sessionId;

  PurchaseRecord({
    String? id,
    DateTime? date,
    required this.productName,
    required this.amount,
    required this.paymentMethod,
    this.sessionId,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        date = date ?? DateTime.now();

  String get formattedAmount {
    return '\$${amount.toStringAsFixed(2)}';
  }

  String get formattedDate {
    final m = date.month;
    final d = date.day;
    final y = date.year;
    final h = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final min = date.minute.toString().padLeft(2, '0');
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    return '$m/$d/$y $h:$min $ampm';
  }
}

/// View model wrapping [ZSProduct] with inferred visual properties.
class StoreProduct {
  final String id;
  final String name;
  final String description;
  final double price;
  final StoreProductType type;
  final SubscriptionDuration? duration;
  final List<String> features;
  final IconData iconData;
  final int colorValue;
  final String? badge;
  final int? gemAmount;
  final double? storeKitPrice;
  final bool storeKitAvailable;
  final int? savingsPercent;

  const StoreProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.type,
    this.duration,
    required this.features,
    required this.iconData,
    required this.colorValue,
    this.badge,
    this.gemAmount,
    this.storeKitPrice,
    this.storeKitAvailable = false,
    this.savingsPercent,
  });

  String get formattedPrice => '\$${price.toStringAsFixed(2)}';

  String? get formattedStoreKitPrice {
    if (storeKitPrice == null) return null;
    return '\$${storeKitPrice!.toStringAsFixed(2)}';
  }

  String? get billingPeriod => duration?.label;

  String? get pricePerMonth {
    if (duration == null) return null;
    switch (duration!) {
      case SubscriptionDuration.weekly:
        return '$formattedPrice/week';
      case SubscriptionDuration.monthly:
        return '$formattedPrice/month';
      case SubscriptionDuration.yearly:
        final monthly = price / 12;
        return '$formattedPrice/year (\$${monthly.toStringAsFixed(2)}/mo)';
    }
  }

  factory StoreProduct.fromZSProduct(ZSProduct product, {int index = 0}) {
    final StoreProductType type;
    final SubscriptionDuration? duration;
    final List<String> features;
    final IconData iconData;
    final int colorValue;
    final String? badge;
    int? gemAmount;

    final skPrice = product.storeKitPrice != null
        ? product.storeKitPrice!.amountMicros / 1000000.0
        : null;
    final webPrice = product.webPrice.amountMicros / 1000000.0;

    switch (product.type) {
      case ZSProductType.consumable:
        type = StoreProductType.consumable;
        duration = null;
        gemAmount = _inferGemAmount(product);
        features = _consumableFeatures(gemAmount);
        iconData = _consumableIcon(index);
        colorValue = _consumableColorValue(index);
        badge = _consumableBadge(index);
      case ZSProductType.nonConsumable:
        type = StoreProductType.nonConsumable;
        duration = null;
        gemAmount = null;
        features = ['Permanent unlock', 'One-time purchase'];
        iconData = _iconLockOpen;
        colorValue = 0xFF4CAF50; // green
        badge = null;
      case ZSProductType.autoRenewableSubscription:
        type = StoreProductType.subscription;
        final d = _inferDuration(product);
        duration = d;
        gemAmount = null;
        features = _subscriptionFeatures(d);
        iconData = _subscriptionIcon(d);
        colorValue = _subscriptionColorValue(d);
        badge = _subscriptionBadge(d);
      case ZSProductType.nonRenewingSubscription:
        type = StoreProductType.subscription;
        duration = SubscriptionDuration.monthly;
        gemAmount = null;
        features = ['Limited access', 'Non-renewing'];
        iconData = _iconCalendar;
        colorValue = 0xFFFF9800; // orange
        badge = null;
    }

    return StoreProduct(
      id: product.id,
      name: product.displayName,
      description: product.productDescription,
      price: webPrice,
      type: type,
      duration: duration,
      features: features,
      iconData: iconData,
      colorValue: colorValue,
      badge: badge,
      gemAmount: gemAmount,
      storeKitPrice: skPrice,
      storeKitAvailable: product.storeKitAvailable,
      savingsPercent: product.savingsPercent,
    );
  }

  // -- Inference helpers (mirrors StoreProduct.swift) --

  static int? _inferGemAmount(ZSProduct product) {
    final lowerId = product.id.toLowerCase();
    final lowerName = product.displayName.toLowerCase();

    if (lowerId.contains('small') || lowerName.contains('small')) return 100;
    if (lowerId.contains('medium') || lowerName.contains('medium')) return 500;
    if (lowerId.contains('large') || lowerName.contains('large')) return 1200;

    final numbers = RegExp(r'\d+')
        .allMatches(lowerName)
        .map((m) => int.tryParse(m.group(0)!) ?? 0)
        .where((n) => n > 0)
        .toList();
    return numbers.isNotEmpty ? numbers.first : null;
  }

  static SubscriptionDuration _inferDuration(ZSProduct product) {
    final lowerId = product.id.toLowerCase();
    final lowerName = product.displayName.toLowerCase();

    if (lowerId.contains('week') || lowerName.contains('week')) {
      return SubscriptionDuration.weekly;
    }
    if (lowerId.contains('year') ||
        lowerName.contains('year') ||
        lowerName.contains('annual')) {
      return SubscriptionDuration.yearly;
    }
    return SubscriptionDuration.monthly;
  }

  // Icons
  static const _iconDiamond = Icons.diamond;
  static const _iconDiamondOutlined = Icons.diamond_outlined;
  static const _iconAutoAwesome = Icons.auto_awesome;
  static const _iconLockOpen = Icons.lock_open;
  static const _iconCalendar = Icons.calendar_today;
  static const _iconStar = Icons.star_outline;
  static const _iconStarFilled = Icons.star;
  static const _iconWorkspacePremium = Icons.workspace_premium;

  static IconData _consumableIcon(int index) {
    return [_iconDiamondOutlined, _iconDiamond, _iconAutoAwesome][index % 3];
  }

  static int _consumableColorValue(int index) {
    return [0xFF00BCD4, 0xFF2196F3, 0xFF9C27B0][index % 3]; // cyan, blue, purple
  }

  static String? _consumableBadge(int index) {
    return [null, 'Popular', 'Best Value'][index % 3];
  }

  static List<String> _consumableFeatures(int? gemAmount) {
    if (gemAmount == null) return ['Digital currency', 'Use anytime'];
    final features = ['$gemAmount gems', 'Never expires'];
    if (gemAmount >= 500) features.add('Bonus included');
    return features;
  }

  static IconData _subscriptionIcon(SubscriptionDuration d) {
    switch (d) {
      case SubscriptionDuration.weekly:
        return _iconStar;
      case SubscriptionDuration.monthly:
        return _iconStarFilled;
      case SubscriptionDuration.yearly:
        return _iconWorkspacePremium;
    }
  }

  static int _subscriptionColorValue(SubscriptionDuration d) {
    switch (d) {
      case SubscriptionDuration.weekly:
        return 0xFF26A69A; // teal/mint
      case SubscriptionDuration.monthly:
        return 0xFFFF9800; // orange
      case SubscriptionDuration.yearly:
        return 0xFFFFC107; // amber/yellow
    }
  }

  static String? _subscriptionBadge(SubscriptionDuration d) {
    switch (d) {
      case SubscriptionDuration.weekly:
        return null;
      case SubscriptionDuration.monthly:
        return null;
      case SubscriptionDuration.yearly:
        return 'Save 17%';
    }
  }

  static List<String> _subscriptionFeatures(SubscriptionDuration d) {
    final features = ['Unlimited access', 'Ad-free experience'];
    switch (d) {
      case SubscriptionDuration.weekly:
        features.add('Cancel anytime');
      case SubscriptionDuration.monthly:
        features.add('Priority support');
      case SubscriptionDuration.yearly:
        features.add('2 months free');
        features.add('Early access to features');
    }
    return features;
  }
}

class AppState extends ChangeNotifier {
  // User identity
  String userId;
  String email;
  DateTime memberSince;

  // Local state
  int gemCount;
  SubscriptionStatus subscriptionStatus;
  String? subscriptionPlan;
  DateTime? subscriptionExpiryDate;
  List<PurchaseRecord> purchaseHistory;
  Set<String> unlockedProducts;

  // SDK data
  List<ZSProduct> products;
  List<StoreProduct> storeProducts;
  List<Entitlement> entitlements;
  RemoteConfig? remoteConfig;
  bool isInitialized;
  bool isLoading;
  String? error;

  AppState({
    this.userId = 'flutter_example_user',
    this.email = 'demo@example.com',
    DateTime? memberSince,
    this.gemCount = 0,
    this.subscriptionStatus = SubscriptionStatus.inactive,
    this.subscriptionPlan,
    this.subscriptionExpiryDate,
    List<PurchaseRecord>? purchaseHistory,
    Set<String>? unlockedProducts,
    List<ZSProduct>? products,
    List<StoreProduct>? storeProducts,
    List<Entitlement>? entitlements,
    this.remoteConfig,
    this.isInitialized = false,
    this.isLoading = false,
    this.error,
  })  : memberSince = memberSince ?? DateTime.now(),
        purchaseHistory = purchaseHistory ?? [],
        unlockedProducts = unlockedProducts ?? {},
        products = products ?? [],
        storeProducts = storeProducts ?? [],
        entitlements = entitlements ?? [];

  // -- Computed getters --

  List<PurchaseRecord> get recentPurchases =>
      purchaseHistory.take(5).toList();

  double get totalSpent =>
      purchaseHistory.fold(0.0, (sum, p) => sum + p.amount);

  int get totalPurchases => purchaseHistory.length;

  int get daysSinceMember =>
      DateTime.now().difference(memberSince).inDays;

  List<StoreProduct> get consumables =>
      storeProducts.where((p) => p.type == StoreProductType.consumable).toList();

  List<StoreProduct> get nonConsumables =>
      storeProducts.where((p) => p.type == StoreProductType.nonConsumable).toList();

  List<StoreProduct> get subscriptions =>
      storeProducts.where((p) => p.type == StoreProductType.subscription).toList();

  // -- Mutators --

  void setProducts(List<ZSProduct> newProducts) {
    products = newProducts;
    var consumableIndex = 0;
    var subscriptionIndex = 0;
    storeProducts = newProducts.map((p) {
      final int index;
      switch (p.type) {
        case ZSProductType.consumable:
        case ZSProductType.nonConsumable:
          index = consumableIndex++;
        case ZSProductType.autoRenewableSubscription:
        case ZSProductType.nonRenewingSubscription:
          index = subscriptionIndex++;
      }
      return StoreProduct.fromZSProduct(p, index: index);
    }).toList();
    notifyListeners();
  }

  void setEntitlements(List<Entitlement> newEntitlements) {
    entitlements = newEntitlements;
    syncFromEntitlements();
    notifyListeners();
  }

  void addGems(int amount) {
    gemCount += amount;
    notifyListeners();
  }

  void activateSubscription({required String plan, required DateTime expiryDate}) {
    subscriptionPlan = plan;
    subscriptionExpiryDate = expiryDate;
    subscriptionStatus = SubscriptionStatus.active;
    notifyListeners();
  }

  void deactivateSubscription() {
    subscriptionStatus = SubscriptionStatus.expired;
    notifyListeners();
  }

  void unlockProduct(String productId) {
    unlockedProducts.add(productId);
    notifyListeners();
  }

  bool isProductUnlocked(String productId) =>
      unlockedProducts.contains(productId);

  void recordPurchase(PurchaseRecord record) {
    purchaseHistory.insert(0, record);
    notifyListeners();
  }

  void syncFromEntitlements() {
    // Sync purchase history from entitlements
    final records = entitlements.map((ent) {
      final product = products.where((p) => p.id == ent.productId).firstOrNull;
      final amount = product != null
          ? product.webPrice.amountMicros / 1000000.0
          : 0.0;
      return PurchaseRecord(
        id: ent.id,
        date: ent.purchasedAt,
        productName: product?.displayName ?? ent.productId,
        amount: amount,
        paymentMethod: ent.source == EntitlementSource.webCheckout
            ? PaymentMethod.webCheckout
            : PaymentMethod.storeKit,
        sessionId: ent.id,
      );
    }).toList();
    records.sort((a, b) => b.date.compareTo(a.date));
    purchaseHistory = records;

    // Sync subscription status
    final activeSubscription = entitlements.where((e) =>
        e.isActive && e.expiresAt != null).firstOrNull;
    if (activeSubscription != null) {
      subscriptionPlan = activeSubscription.productId;
      subscriptionExpiryDate = activeSubscription.expiresAt;
      subscriptionStatus = SubscriptionStatus.active;
    }

    // Sync unlocked products (non-consumables with no expiry)
    for (final ent in entitlements) {
      if (ent.isActive && ent.expiresAt == null) {
        unlockedProducts.add(ent.productId);
      }
    }
  }

  void setLoading(bool loading) {
    isLoading = loading;
    notifyListeners();
  }

  void setError(String? err) {
    error = err;
    notifyListeners();
  }

  void setInitialized(bool initialized) {
    isInitialized = initialized;
    notifyListeners();
  }

  void setRemoteConfig(RemoteConfig? config) {
    remoteConfig = config;
    notifyListeners();
  }

  void resetForUser(String newUserId) {
    userId = newUserId;
    gemCount = 0;
    subscriptionStatus = SubscriptionStatus.inactive;
    subscriptionPlan = null;
    subscriptionExpiryDate = null;
    purchaseHistory = [];
    unlockedProducts = {};
    entitlements = [];
    memberSince = DateTime.now();
    notifyListeners();
  }
}
