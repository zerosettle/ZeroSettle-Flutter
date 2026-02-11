/// A price with currency information.
/// Mirrors the Swift `Price` struct in ZeroSettleKit.
class Price {
  /// Price in micros (e.g., 9990000 = $9.99). 1 unit = 1/1,000,000 of the currency.
  final int amountMicros;

  /// ISO 4217 currency code (e.g., "USD")
  final String currencyCode;

  const Price({required this.amountMicros, required this.currencyCode});

  /// Formatted price string (e.g., "$9.99")
  String get formatted {
    final amount = amountMicros / 1000000.0;
    // Simple currency symbol lookup for common codes
    final symbol = switch (currencyCode) {
      'USD' => '\$',
      'EUR' => '€',
      'GBP' => '£',
      _ => '$currencyCode ',
    };
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  factory Price.fromMap(Map<String, dynamic> map) {
    return Price(
      amountMicros: map['amountMicros'] as int,
      currencyCode: map['currencyCode'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'amountMicros': amountMicros,
      'currencyCode': currencyCode,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Price &&
          amountMicros == other.amountMicros &&
          currencyCode == other.currencyCode;

  @override
  int get hashCode => Object.hash(amountMicros, currencyCode);

  @override
  String toString() => 'Price($formatted)';
}
