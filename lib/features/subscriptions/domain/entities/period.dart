/// Period entity — a billing cycle for a subscription.
class Period {
  final int? id;
  final int subscriptionId;
  final DateTime startDate;
  final DateTime endDate;
  final String status; // 'open' or 'closed'
  final DateTime createdAt;

  const Period({
    this.id,
    required this.subscriptionId,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.createdAt,
  });

  bool get isOpen => status == 'open';
  bool get isClosed => status == 'closed';

  Period copyWith({
    int? id,
    int? subscriptionId,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    DateTime? createdAt,
  }) {
    return Period(
      id: id ?? this.id,
      subscriptionId: subscriptionId ?? this.subscriptionId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
