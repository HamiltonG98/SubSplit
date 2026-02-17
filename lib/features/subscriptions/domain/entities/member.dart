/// Member entity — someone sharing a subscription.
class Member {
  final int? id;
  final int subscriptionId;
  final String name;
  final double amount;
  final DateTime createdAt;

  const Member({
    this.id,
    required this.subscriptionId,
    required this.name,
    required this.amount,
    required this.createdAt,
  });

  Member copyWith({
    int? id,
    int? subscriptionId,
    String? name,
    double? amount,
    DateTime? createdAt,
  }) {
    return Member(
      id: id ?? this.id,
      subscriptionId: subscriptionId ?? this.subscriptionId,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
