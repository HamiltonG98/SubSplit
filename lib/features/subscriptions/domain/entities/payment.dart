/// Payment entity — tracks whether a member paid for a period.
class Payment {
  final int? id;
  final int periodId;
  final int memberId;
  final bool isPaid;
  final DateTime? paidAt;

  const Payment({
    this.id,
    required this.periodId,
    required this.memberId,
    required this.isPaid,
    this.paidAt,
  });

  Payment copyWith({
    int? id,
    int? periodId,
    int? memberId,
    bool? isPaid,
    DateTime? paidAt,
  }) {
    return Payment(
      id: id ?? this.id,
      periodId: periodId ?? this.periodId,
      memberId: memberId ?? this.memberId,
      isPaid: isPaid ?? this.isPaid,
      paidAt: paidAt ?? this.paidAt,
    );
  }
}
