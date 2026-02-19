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

  Future<String?> togglePayment(int paymentId, bool isPaid) async {
    final result = await _repo.togglePayment(paymentId, isPaid);
    final failureMessage = result.fold<String?>(
      (failure) => failure.message,
      (_) => null,
    );
    if (failureMessage != null) return failureMessage;

    await load();
    return null;
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

  Future<String?> addMember(String name) async {
    final member = domain.Member(
      subscriptionId: subscriptionId,
      name: name,
      amount: 0, // auto-calculated by repository
      createdAt: DateTime.now(),
    );
    final result = await _repo.addMember(member);
    final failureMessage = result.fold<String?>(
      (failure) => failure.message,
      (_) => null,
    );
    if (failureMessage != null) return failureMessage;

    await load();
    return null;
  }

  Future<String?> updateMember(int memberId, String name) async {
    final result = await _repo.updateMember(memberId, name);
    final failureMessage = result.fold<String?>(
      (failure) => failure.message,
      (_) => null,
    );
    if (failureMessage != null) return failureMessage;

    await load();
    return null;
  }

  Future<String?> deleteMember(int memberId) async {
    final result = await _repo.deleteMember(memberId);
    final failureMessage = result.fold<String?>(
      (failure) => failure.message,
      (_) => null,
    );
    if (failureMessage != null) return failureMessage;

    await load();
    return null;
  }

  Future<String?> deleteSubscription() async {
    final result = await _repo.deleteSubscription(subscriptionId);
    return result.fold<String?>((failure) => failure.message, (_) => null);
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
