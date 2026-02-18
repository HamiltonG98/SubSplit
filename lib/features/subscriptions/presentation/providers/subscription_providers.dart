import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subscription_management/core/di/injection_container.dart';
import 'package:subscription_management/features/subscriptions/domain/entities/member.dart'
    as domain;
import 'package:subscription_management/features/subscriptions/domain/entities/subscription.dart'
    as domain;
import 'package:subscription_management/features/subscriptions/domain/entities/subscription_detail.dart';
import 'package:subscription_management/features/subscriptions/domain/repositories/subscription_repository.dart';

// ── All subscriptions (home screen) ──

final subscriptionListProvider =
    StateNotifierProvider<
      SubscriptionListNotifier,
      AsyncValue<List<SubscriptionSummary>>
    >((ref) => SubscriptionListNotifier());

class SubscriptionListNotifier
    extends StateNotifier<AsyncValue<List<SubscriptionSummary>>> {
  final SubscriptionRepository _repo = sl<SubscriptionRepository>();

  SubscriptionListNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    final result = await _repo.getSubscriptions();
    state = result.fold(
      (failure) => AsyncValue.error(failure.message, StackTrace.current),
      (data) => AsyncValue.data(data),
    );
  }

  Future<void> deleteSubscription(int id) async {
    await _repo.deleteSubscription(id);
    await load();
  }
}

// ── Subscription detail ──

final subscriptionDetailProvider =
    StateNotifierProvider.family<
      SubscriptionDetailNotifier,
      AsyncValue<SubscriptionDetail>,
      int
    >((ref, subscriptionId) => SubscriptionDetailNotifier(subscriptionId));

class SubscriptionDetailNotifier
    extends StateNotifier<AsyncValue<SubscriptionDetail>> {
  final SubscriptionRepository _repo = sl<SubscriptionRepository>();
  final int subscriptionId;

  SubscriptionDetailNotifier(this.subscriptionId)
    : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    final result = await _repo.getSubscriptionDetail(subscriptionId);
    state = result.fold(
      (failure) => AsyncValue.error(failure.message, StackTrace.current),
      (data) => AsyncValue.data(data),
    );
  }

  Future<void> togglePayment(int paymentId, bool isPaid) async {
    await _repo.togglePayment(paymentId, isPaid);
    await load();
  }

  Future<String?> closePeriod() async {
    final result = await _repo.closePeriod(subscriptionId);
    final failureMessage = result.fold<String?>((failure) => failure.message, (
      _,
    ) {
      return null;
    });
    if (failureMessage != null) {
      return failureMessage;
    }

    await load();
    return null;
  }

  Future<void> addMember(String name) async {
    final member = domain.Member(
      subscriptionId: subscriptionId,
      name: name,
      amount: 0, // auto-calculated by repository
      createdAt: DateTime.now(),
    );
    await _repo.addMember(member);
    await load();
  }

  Future<void> updateMember(int memberId, String name) async {
    await _repo.updateMember(memberId, name);
    await load();
  }

  Future<void> deleteMember(int memberId) async {
    await _repo.deleteMember(memberId);
    await load();
  }

  Future<void> deleteSubscription() async {
    await _repo.deleteSubscription(subscriptionId);
  }

  Future<String?> updateSubscription(domain.Subscription subscription) async {
    final result = await _repo.updateSubscription(subscription);
    final failureMessage = result.fold<String?>((failure) => failure.message, (
      _,
    ) {
      return null;
    });
    if (failureMessage != null) {
      return failureMessage;
    }

    await load();
    return null;
  }
}

// ── Payment history ──

final paymentHistoryProvider =
    StateNotifierProvider.family<
      PaymentHistoryNotifier,
      AsyncValue<List<PeriodWithPayments>>,
      int
    >((ref, subscriptionId) => PaymentHistoryNotifier(subscriptionId));

class PaymentHistoryNotifier
    extends StateNotifier<AsyncValue<List<PeriodWithPayments>>> {
  final SubscriptionRepository _repo = sl<SubscriptionRepository>();
  final int subscriptionId;

  PaymentHistoryNotifier(this.subscriptionId)
    : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    final result = await _repo.getPaymentHistory(subscriptionId);
    state = result.fold(
      (failure) => AsyncValue.error(failure.message, StackTrace.current),
      (data) => AsyncValue.data(data),
    );
  }
}
