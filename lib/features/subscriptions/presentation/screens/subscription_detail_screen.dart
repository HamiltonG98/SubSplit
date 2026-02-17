import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:subscription_management/core/theme/app_theme.dart';
import 'package:subscription_management/core/widgets/app_toast.dart';
import 'package:subscription_management/features/subscriptions/domain/entities/subscription_detail.dart';
import 'package:subscription_management/features/subscriptions/presentation/providers/subscription_providers.dart';
import 'package:subscription_management/features/subscriptions/presentation/screens/history_screen.dart';
import 'package:subscription_management/features/subscriptions/presentation/widgets/member_payment_tile.dart';

class SubscriptionDetailScreen extends ConsumerWidget {
  final int subscriptionId;

  const SubscriptionDetailScreen({super.key, required this.subscriptionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(subscriptionDetailProvider(subscriptionId));

    return Scaffold(
      appBar: AppBar(
        title:
            detailAsync.whenData((d) => Text(d.subscription.name)).value ??
            const Text('Loading...'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Payment History',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HistoryScreen(subscriptionId: subscriptionId),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Delete Subscription',
            onPressed: () => _confirmDeleteSubscription(context, ref),
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.accentCyan),
        ),
        error: (err, _) => Center(
          child: Text(
            'Error: $err',
            style: const TextStyle(color: AppTheme.error),
          ),
        ),
        data: (detail) => _buildDetail(context, ref, detail),
      ),
    );
  }

  Widget _buildDetail(
    BuildContext context,
    WidgetRef ref,
    SubscriptionDetail detail,
  ) {
    final sub = detail.subscription;
    final accentColor = AppTheme.colorFromHex(sub.color);
    final dateFormat = DateFormat('MMM d, yyyy');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Header Card ──
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accentColor.withValues(alpha: 0.15),
                accentColor.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accentColor.withValues(alpha: 0.3)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${sub.currencySymbol}${sub.totalCost.toStringAsFixed(2)}',
                        style: Theme.of(
                          context,
                        ).textTheme.displayLarge?.copyWith(color: accentColor),
                      ),
                      Text(
                        'per month · bills on day ${sub.billingDay}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accentColor,
                          accentColor.withValues(alpha: 0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        sub.name[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (detail.currentPeriod != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 16,
                        color: accentColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Current period: ${dateFormat.format(detail.currentPeriod!.startDate)} – ${dateFormat.format(detail.currentPeriod!.endDate)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── Members & Payments ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Members', style: Theme.of(context).textTheme.titleLarge),
            Text(
              '${detail.paidCount}/${detail.totalMembers} paid',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: detail.paidCount == detail.totalMembers
                    ? AppTheme.success
                    : accentColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Member tiles
        if (detail.members.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Center(
              child: Text(
                'No members yet. Add someone!',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          )
        else
          ...detail.members.map((member) {
            final payment = detail.currentPayments
                .where((p) => p.memberId == member.id)
                .firstOrNull;
            return MemberPaymentTile(
              member: member,
              payment: payment,
              accentColor: accentColor,
              currencySymbol: sub.currencySymbol,
              onToggle: (isPaid) {
                if (payment != null) {
                  ref
                      .read(subscriptionDetailProvider(subscriptionId).notifier)
                      .togglePayment(payment.id!, isPaid);
                }
              },
              onEdit: () {
                _showEditMemberDialog(context, ref, member);
              },
              onDelete: () {
                _confirmDeleteMember(context, ref, member.id!, member.name);
              },
            );
          }),

        const SizedBox(height: 16),

        // Add member button
        OutlinedButton.icon(
          onPressed: () => _showAddMemberDialog(context, ref),
          icon: const Icon(Icons.person_add_rounded),
          label: const Text('Add Member'),
          style: OutlinedButton.styleFrom(
            foregroundColor: accentColor,
            side: BorderSide(color: accentColor.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Close period button
        if (detail.currentPeriod != null)
          ElevatedButton.icon(
            onPressed: () => _confirmClosePeriod(context, ref, detail),
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: const Text('Close Period & Start New'),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),

        const SizedBox(height: 32),
      ],
    );
  }

  void _showAddMemberDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Member'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'e.g. Juan',
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Name is required' : null,
            textCapitalization: TextCapitalization.words,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx);
                ref
                    .read(subscriptionDetailProvider(subscriptionId).notifier)
                    .addMember(nameController.text.trim());
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditMemberDialog(
    BuildContext context,
    WidgetRef ref,
    dynamic member,
  ) {
    final nameController = TextEditingController(text: member.name);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Member'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Name'),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Name is required' : null,
            textCapitalization: TextCapitalization.words,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx);
                ref
                    .read(subscriptionDetailProvider(subscriptionId).notifier)
                    .updateMember(member.id!, nameController.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteMember(
    BuildContext context,
    WidgetRef ref,
    int memberId,
    String name,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Remove $name from this subscription?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(subscriptionDetailProvider(subscriptionId).notifier)
                  .deleteMember(memberId);
            },
            child: const Text(
              'Remove',
              style: TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClosePeriod(
    BuildContext context,
    WidgetRef ref,
    SubscriptionDetail detail,
  ) {
    // Block if not all members have paid
    if (detail.paidCount < detail.totalMembers) {
      final unpaid = detail.totalMembers - detail.paidCount;
      AppToast.show(
        context,
        message:
            '$unpaid member${unpaid > 1 ? 's have' : ' has'} not paid yet. All members must pay before closing the period.',
        type: ToastType.error,
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close Period'),
        content: const Text(
          'All members have paid! This will close the current billing period and start a new one. All payment statuses will reset. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(subscriptionDetailProvider(subscriptionId).notifier)
                  .closePeriod();
              if (context.mounted) {
                AppToast.show(
                  context,
                  message: 'Period closed! A new billing period has started.',
                  type: ToastType.success,
                );
              }
            },
            child: const Text(
              'Close Period',
              style: TextStyle(color: AppTheme.accentCyan),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSubscription(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Subscription'),
        content: const Text(
          'This will permanently delete this subscription, all its members, and the entire payment history. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(subscriptionDetailProvider(subscriptionId).notifier)
                  .deleteSubscription();
              // Refresh home list and pop back
              ref.read(subscriptionListProvider.notifier).load();
              if (ctx.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
