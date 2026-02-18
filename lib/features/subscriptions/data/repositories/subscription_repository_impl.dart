import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:subscription_management/core/error/failures.dart';
import 'package:subscription_management/features/subscriptions/data/datasources/app_database.dart';
import 'package:subscription_management/features/subscriptions/domain/entities/member.dart'
    as domain;
import 'package:subscription_management/features/subscriptions/domain/entities/payment.dart'
    as domain;
import 'package:subscription_management/features/subscriptions/domain/entities/period.dart'
    as domain;
import 'package:subscription_management/features/subscriptions/domain/entities/subscription.dart'
    as domain;
import 'package:subscription_management/features/subscriptions/domain/entities/subscription_detail.dart';
import 'package:subscription_management/features/subscriptions/domain/repositories/subscription_repository.dart';
import 'package:subscription_management/core/services/notification_service.dart';

/// Concrete repository implementation backed by Drift.
class SubscriptionRepositoryImpl implements SubscriptionRepository {
  final AppDatabase _db;
  final NotificationService _notificationService;

  SubscriptionRepositoryImpl(this._db, this._notificationService);

  // ── Mappers ──

  domain.Subscription _mapSubscription(Subscription row) {
    return domain.Subscription(
      id: row.id,
      name: row.name,
      color: row.color,
      totalCost: row.totalCost,
      billingDay: row.billingDay,
      currency: row.currency,
      createdAt: row.createdAt,
    );
  }

  domain.Member _mapMember(Member row) {
    return domain.Member(
      id: row.id,
      subscriptionId: row.subscriptionId,
      name: row.name,
      amount: row.amount,
      createdAt: row.createdAt,
    );
  }

  domain.Period _mapPeriod(Period row) {
    return domain.Period(
      id: row.id,
      subscriptionId: row.subscriptionId,
      startDate: row.startDate,
      endDate: row.endDate,
      status: row.status,
      createdAt: row.createdAt,
    );
  }

  domain.Payment _mapPayment(Payment row) {
    return domain.Payment(
      id: row.id,
      periodId: row.periodId,
      memberId: row.memberId,
      isPaid: row.isPaid,
      paidAt: row.paidAt,
    );
  }

  // ── Repository Methods ──

  @override
  Future<Either<Failure, List<SubscriptionSummary>>> getSubscriptions() async {
    try {
      final rows = await _db.getAllSubscriptions();
      final summaries = <SubscriptionSummary>[];

      for (final row in rows) {
        final members = await _db.getMembersForSubscription(row.id);
        final paidCount = await _db.getPaidCountForSubscription(row.id);
        summaries.add(
          SubscriptionSummary(
            subscription: _mapSubscription(row),
            memberCount: members.length,
            paidCount: paidCount,
          ),
        );
      }

      return Right(summaries);
    } catch (e) {
      return Left(DatabaseFailure('Failed to load subscriptions: $e'));
    }
  }

  @override
  Future<Either<Failure, SubscriptionDetail>> getSubscriptionDetail(
    int subscriptionId,
  ) async {
    try {
      final row = await _db.getSubscriptionById(subscriptionId);
      final memberRows = await _db.getMembersForSubscription(subscriptionId);
      final openPeriod = await _db.getOpenPeriod(subscriptionId);

      List<domain.Payment> payments = [];
      if (openPeriod != null) {
        final paymentRows = await _db.getPaymentsForPeriod(openPeriod.id);
        payments = paymentRows.map(_mapPayment).toList();
      }

      return Right(
        SubscriptionDetail(
          subscription: _mapSubscription(row),
          members: memberRows.map(_mapMember).toList(),
          currentPeriod: openPeriod != null ? _mapPeriod(openPeriod) : null,
          currentPayments: payments,
        ),
      );
    } catch (e) {
      return Left(DatabaseFailure('Failed to load subscription detail: $e'));
    }
  }

  @override
  Future<Either<Failure, int>> addSubscription(
    domain.Subscription subscription,
    List<domain.Member> members,
  ) async {
    try {
      final subId = await _db.insertSubscription(
        SubscriptionsCompanion.insert(
          name: subscription.name,
          color: subscription.color,
          totalCost: subscription.totalCost,
          billingDay: subscription.billingDay,
          currency: Value(subscription.currency),
        ),
      );

      // Auto-calculate amount per member
      final amountPerMember = members.isNotEmpty
          ? subscription.totalCost / members.length
          : 0.0;

      // Insert members with calculated amount
      for (final member in members) {
        await _db.insertMember(
          MembersCompanion.insert(
            subscriptionId: subId,
            name: member.name,
            amount: amountPerMember,
          ),
        );
      }

      // Create the first period
      await _createNewPeriod(subId, subscription.billingDay);

      // Schedule notification (errors are logged, not propagated)
      await _scheduleNotification(
        id: subId,
        name: subscription.name,
        billingDay: subscription.billingDay,
      );

      return Right(subId);
    } catch (e) {
      return Left(DatabaseFailure('Failed to add subscription: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteSubscription(int subscriptionId) async {
    try {
      // Delete payments for all periods
      final periods = await _db.getPeriodsForSubscription(subscriptionId);
      for (final period in periods) {
        await _db.removePaymentsForPeriod(period.id);
      }
      await _db.removePeriodsForSubscription(subscriptionId);
      await _db.removeMembersForSubscription(subscriptionId);
      await _db.removeSubscription(subscriptionId);
      await _notificationService.cancelReminder(subscriptionId);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure('Failed to delete subscription: $e'));
    }
  }

  Future<void> _scheduleNotification({
    required int id,
    required String name,
    required int billingDay,
  }) async {
    final result = await _notificationService.scheduleMonthlyReminder(
      id: id,
      title: 'Payment Due',
      body: 'Your $name subscription period starts today.',
      dayOfMonth: billingDay,
      hour: 9,
      minute: 0,
    );

    if (result == ScheduleResult.permissionDenied) {
      debugPrint(
        'Notification schedule skipped: missing notification permission',
      );
    } else if (result == ScheduleResult.initFailed) {
      debugPrint(
        'Notification schedule failed: notification service not ready',
      );
    } else if (result == ScheduleResult.scheduledInexact) {
      debugPrint('Notification scheduled as inexact: exact alarm unavailable');
    }
  }

  @override
  Future<Either<Failure, void>> updateSubscription(
    domain.Subscription subscription,
  ) async {
    try {
      final previous = await _db.getSubscriptionById(subscription.id!);

      await _db.updateSubscription(
        SubscriptionsCompanion(
          id: Value(subscription.id!),
          name: Value(subscription.name),
          color: Value(subscription.color),
          totalCost: Value(subscription.totalCost),
          billingDay: Value(subscription.billingDay),
          currency: Value(subscription.currency),
          createdAt: Value(subscription.createdAt),
        ),
      );

      if (previous.billingDay != subscription.billingDay) {
        final openPeriod = await _db.getOpenPeriod(subscription.id!);
        if (openPeriod != null) {
          final (startDate, endDate) = _currentPeriodRange(
            subscription.billingDay,
          );
          await _db.updatePeriodDates(openPeriod.id, startDate, endDate);
        }
      }

      // Update notification schedule (errors are logged, not propagated)
      await _scheduleNotification(
        id: subscription.id!,
        name: subscription.name,
        billingDay: subscription.billingDay,
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure('Failed to update subscription: $e'));
    }
  }

  @override
  Future<Either<Failure, int>> addMember(domain.Member member) async {
    try {
      final memberId = await _db.insertMember(
        MembersCompanion.insert(
          subscriptionId: member.subscriptionId,
          name: member.name,
          amount: 0, // will be recalculated
        ),
      );

      // Add a payment record for the current open period
      final openPeriod = await _db.getOpenPeriod(member.subscriptionId);
      if (openPeriod != null) {
        await _db.insertPayment(
          PaymentsCompanion.insert(periodId: openPeriod.id, memberId: memberId),
        );
      }

      // Recalculate amounts for all members
      await _recalculateMemberAmounts(member.subscriptionId);

      return Right(memberId);
    } catch (e) {
      return Left(DatabaseFailure('Failed to add member: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updateMember(int memberId, String name) async {
    try {
      await _db.updateMemberName(memberId, name);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure('Failed to update member: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteMember(int memberId) async {
    try {
      // Get subscription ID before deleting
      final members = await _db.select(_db.members).get();
      final member = members.firstWhere((m) => m.id == memberId);
      final subscriptionId = member.subscriptionId;

      await _db.removePaymentsForMember(memberId);
      await _db.removeMember(memberId);

      // Recalculate amounts for remaining members
      await _recalculateMemberAmounts(subscriptionId);

      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure('Failed to delete member: $e'));
    }
  }

  /// Recalculates member amounts by evenly dividing the subscription cost.
  Future<void> _recalculateMemberAmounts(int subscriptionId) async {
    final sub = await _db.getSubscriptionById(subscriptionId);
    final memberList = await _db.getMembersForSubscription(subscriptionId);
    if (memberList.isEmpty) return;
    final amountPerMember = sub.totalCost / memberList.length;
    await _db.updateAmountForAllMembers(subscriptionId, amountPerMember);
  }

  (DateTime, DateTime) _currentPeriodRange(int billingDay) {
    final now = DateTime.now();
    final day = billingDay.clamp(1, 28);

    DateTime startDate;
    if (now.day >= day) {
      startDate = DateTime(now.year, now.month, day);
    } else {
      startDate = now.month == 1
          ? DateTime(now.year - 1, 12, day)
          : DateTime(now.year, now.month - 1, day);
    }

    final endDate = DateTime(
      startDate.month == 12 ? startDate.year + 1 : startDate.year,
      startDate.month == 12 ? 1 : startDate.month + 1,
      day,
    ).subtract(const Duration(days: 1));

    return (startDate, endDate);
  }

  @override
  Future<Either<Failure, void>> togglePayment(
    int paymentId,
    bool isPaid,
  ) async {
    try {
      await _db.togglePaymentStatus(paymentId, isPaid);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure('Failed to toggle payment: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> closePeriod(int subscriptionId) async {
    try {
      final openPeriod = await _db.getOpenPeriod(subscriptionId);
      if (openPeriod == null) {
        return const Left(
          NotFoundFailure('No open period found for this subscription'),
        );
      }

      // Close the current period
      await _db.closePeriodById(openPeriod.id);

      // Get the billing day
      final sub = await _db.getSubscriptionById(subscriptionId);

      // Create the next period starting after the closed one
      final nextStart = openPeriod.endDate.add(const Duration(days: 1));
      await _createNewPeriodFrom(subscriptionId, sub.billingDay, nextStart);

      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure('Failed to close period: $e'));
    }
  }

  @override
  Future<Either<Failure, List<PeriodWithPayments>>> getPaymentHistory(
    int subscriptionId,
  ) async {
    try {
      final periodRows = await _db.getPeriodsForSubscription(subscriptionId);
      final memberRows = await _db.getMembersForSubscription(subscriptionId);

      final memberMap = {for (final m in memberRows) m.id: _mapMember(m)};

      final result = <PeriodWithPayments>[];
      for (final period in periodRows) {
        final paymentRows = await _db.getPaymentsForPeriod(period.id);
        final paymentsWithMembers = paymentRows
            .where((p) => memberMap.containsKey(p.memberId))
            .map(
              (p) => PaymentWithMember(
                payment: _mapPayment(p),
                member: memberMap[p.memberId]!,
              ),
            )
            .toList();

        result.add(
          PeriodWithPayments(
            period: _mapPeriod(period),
            payments: paymentsWithMembers,
          ),
        );
      }

      return Right(result);
    } catch (e) {
      return Left(DatabaseFailure('Failed to load payment history: $e'));
    }
  }

  // ── Private Helpers ──

  Future<void> _createNewPeriod(int subscriptionId, int billingDay) async {
    final now = DateTime.now();
    final day = billingDay.clamp(1, 28);

    DateTime startDate;
    if (now.day >= day) {
      startDate = DateTime(now.year, now.month, day);
    } else {
      // Go back to previous month
      final prevMonth = now.month == 1
          ? DateTime(now.year - 1, 12, day)
          : DateTime(now.year, now.month - 1, day);
      startDate = prevMonth;
    }

    final endDate = DateTime(
      startDate.month == 12 ? startDate.year + 1 : startDate.year,
      startDate.month == 12 ? 1 : startDate.month + 1,
      day,
    ).subtract(const Duration(days: 1));

    final periodId = await _db.insertPeriod(
      PeriodsCompanion.insert(
        subscriptionId: subscriptionId,
        startDate: startDate,
        endDate: endDate,
      ),
    );

    // Create payments for all members
    final members = await _db.getMembersForSubscription(subscriptionId);
    for (final member in members) {
      await _db.insertPayment(
        PaymentsCompanion.insert(periodId: periodId, memberId: member.id),
      );
    }
  }

  /// Creates a new period starting from a specific date (used when closing a period).
  Future<void> _createNewPeriodFrom(
    int subscriptionId,
    int billingDay,
    DateTime startDate,
  ) async {
    final day = billingDay.clamp(1, 28);

    // End date is one day before the next billing day
    final endDate = DateTime(
      startDate.month == 12 ? startDate.year + 1 : startDate.year,
      startDate.month == 12 ? 1 : startDate.month + 1,
      day,
    ).subtract(const Duration(days: 1));

    final periodId = await _db.insertPeriod(
      PeriodsCompanion.insert(
        subscriptionId: subscriptionId,
        startDate: startDate,
        endDate: endDate,
      ),
    );

    // Create payments for all members
    final members = await _db.getMembersForSubscription(subscriptionId);
    for (final member in members) {
      await _db.insertPayment(
        PaymentsCompanion.insert(periodId: periodId, memberId: member.id),
      );
    }
  }
}
