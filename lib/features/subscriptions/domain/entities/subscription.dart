/// Subscription entity — pure domain object.
class Subscription {
  final int? id;
  final String name;
  final String color;
  final double totalCost;
  final int billingDay;
  final String currency;
  final DateTime createdAt;

  const Subscription({
    this.id,
    required this.name,
    required this.color,
    required this.totalCost,
    required this.billingDay,
    this.currency = 'USD',
    required this.createdAt,
  });

  Subscription copyWith({
    int? id,
    String? name,
    String? color,
    double? totalCost,
    int? billingDay,
    String? currency,
    DateTime? createdAt,
  }) {
    return Subscription(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      totalCost: totalCost ?? this.totalCost,
      billingDay: billingDay ?? this.billingDay,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Returns the symbol for this subscription's currency.
  String get currencySymbol {
    switch (currency) {
      case 'NIO':
        return 'C\$';
      case 'USD':
      default:
        return '\$';
    }
  }
}
