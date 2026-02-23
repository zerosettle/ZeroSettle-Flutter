/// A price with currency information.
/// Mirrors the Swift `Price` struct in ZeroSettleKit.
class Price {
  /// Price in cents (e.g., 999 = $9.99). 1 unit = 1/100 of the currency.
  final int amountCents;

  /// ISO 4217 currency code (e.g., "USD")
  final String currencyCode;

  const Price({required this.amountCents, required this.currencyCode});

  /// Creates a [Price] from a micros value (1 unit = 1/1,000,000 of the currency).
  ///
  /// Converts micros to cents via integer division: `micros ~/ 10000`.
  factory Price.fromMicros(int micros, String currencyCode) {
    return Price(amountCents: micros ~/ 10000, currencyCode: currencyCode);
  }

  /// Formatted price string (e.g., "$9.99")
  String get formatted {
    final amount = amountCents / 100.0;
    // Simple currency symbol lookup for common codes
    final symbol = switch (currencyCode) {
      'USD' => '\$',
      'EUR' => '\u20AC',
      'GBP' => '\u00A3',
      _ => '$currencyCode ',
    };
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  factory Price.fromMap(Map<String, dynamic> map) {
    return Price(
      amountCents: map['amountCents'] as int,
      currencyCode: map['currencyCode'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'amountCents': amountCents,
      'currencyCode': currencyCode,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Price &&
          amountCents == other.amountCents &&
          currencyCode == other.currencyCode;

  @override
  int get hashCode => Object.hash(amountCents, currencyCode);

  @override
  String toString() => 'Price($formatted)';
}
