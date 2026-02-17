import 'package:subscription_management/features/subscriptions/domain/entities/member.dart';
import 'package:subscription_management/features/subscriptions/domain/entities/payment.dart';
import 'package:subscription_management/features/subscriptions/domain/entities/period.dart';
import 'package:subscription_management/features/subscriptions/domain/entities/subscription.dart';

/// A subscription with its members and current period payment info.
class SubscriptionDetail {
  final Subscription subscription;
  final List<Member> members;
  final Period? currentPeriod;
  final List<Payment> currentPayments;

  const SubscriptionDetail({
    required this.subscription,
    required this.members,
    this.currentPeriod,
    this.currentPayments = const [],
  });

  int get paidCount => currentPayments.where((p) => p.isPaid).length;
  int get totalMembers => members.length;
}

/// A subscription summary for the home screen list.
class SubscriptionSummary {
  final Subscription subscription;
  final int memberCount;
  final int paidCount;

  const SubscriptionSummary({
    required this.subscription,
    required this.memberCount,
    required this.paidCount,
  });
}

/// A period with all its payments and the corresponding member names.
class PeriodWithPayments {
  final Period period;
  final List<PaymentWithMember> payments;

  const PeriodWithPayments({required this.period, required this.payments});
}

/// A single payment joined with member info.
class PaymentWithMember {
  final Payment payment;
  final Member member;

  const PaymentWithMember({required this.payment, required this.member});
}
