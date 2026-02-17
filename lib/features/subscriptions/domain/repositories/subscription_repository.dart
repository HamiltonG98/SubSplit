import 'package:dartz/dartz.dart';
import 'package:subscription_management/core/error/failures.dart';
import 'package:subscription_management/features/subscriptions/domain/entities/member.dart';
import 'package:subscription_management/features/subscriptions/domain/entities/subscription.dart';
import 'package:subscription_management/features/subscriptions/domain/entities/subscription_detail.dart';

/// Abstract repository interface — domain layer contract.
abstract class SubscriptionRepository {
  /// Get summaries of all subscriptions.
  Future<Either<Failure, List<SubscriptionSummary>>> getSubscriptions();

  /// Get full detail for a subscription (members + current period + payments).
  Future<Either<Failure, SubscriptionDetail>> getSubscriptionDetail(
    int subscriptionId,
  );

  /// Create a subscription with its members and an initial open period.
  Future<Either<Failure, int>> addSubscription(
    Subscription subscription,
    List<Member> members,
  );

  /// Delete a subscription and all associated data.
  Future<Either<Failure, void>> deleteSubscription(int subscriptionId);

  /// Update a subscription's basic info.
  Future<Either<Failure, void>> updateSubscription(Subscription subscription);

  /// Add a member to an existing subscription.
  Future<Either<Failure, int>> addMember(Member member);

  /// Update a member's name.
  Future<Either<Failure, void>> updateMember(int memberId, String name);

  /// Remove a member from a subscription.
  Future<Either<Failure, void>> deleteMember(int memberId);

  /// Toggle a payment's paid status for the current period.
  Future<Either<Failure, void>> togglePayment(int paymentId, bool isPaid);

  /// Close the current period and create a new one.
  Future<Either<Failure, void>> closePeriod(int subscriptionId);

  /// Get payment history — all periods with payments for a subscription.
  Future<Either<Failure, List<PeriodWithPayments>>> getPaymentHistory(
    int subscriptionId,
  );
}
