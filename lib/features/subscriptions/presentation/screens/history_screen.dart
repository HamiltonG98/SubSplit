import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:subscription_management/core/theme/app_theme.dart';
import 'package:subscription_management/features/subscriptions/presentation/providers/subscription_providers.dart';

class HistoryScreen extends ConsumerWidget {
  final int subscriptionId;

  const HistoryScreen({super.key, required this.subscriptionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(paymentHistoryProvider(subscriptionId));

    return Scaffold(
      appBar: AppBar(title: const Text('Payment History')),
      body: historyAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.accentCyan),
        ),
        error: (err, _) => Center(
          child: Text(
            'Error: $err',
            style: const TextStyle(color: AppTheme.error),
          ),
        ),
        data: (periods) {
          if (periods.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.history_rounded,
                    size: 48,
                    color: AppTheme.textMuted,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No history yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Close a period to see it here',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: periods.length,
            itemBuilder: (context, index) {
              final pw = periods[index];
              final dateFormat = DateFormat('MMM d, yyyy');
              final isOpen = pw.period.isOpen;
              final allPaid = pw.payments.every((p) => p.payment.isPaid);
              final paidCount = pw.payments
                  .where((p) => p.payment.isPaid)
                  .length;

              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 300 + (index * 80)),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 16 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isOpen
                            ? AppTheme.accentCyan.withValues(alpha: 0.4)
                            : AppTheme.cardBorder,
                      ),
                    ),
                    child: Theme(
                      data: Theme.of(
                        context,
                      ).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        childrenPadding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          bottom: 12,
                        ),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isOpen
                                ? AppTheme.accentCyan.withValues(alpha: 0.15)
                                : allPaid
                                ? AppTheme.success.withValues(alpha: 0.15)
                                : AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isOpen
                                ? Icons.schedule_rounded
                                : allPaid
                                ? Icons.check_circle_rounded
                                : Icons.cancel_rounded,
                            color: isOpen
                                ? AppTheme.accentCyan
                                : allPaid
                                ? AppTheme.success
                                : AppTheme.error,
                            size: 22,
                          ),
                        ),
                        title: Text(
                          '${dateFormat.format(pw.period.startDate)} – ${dateFormat.format(pw.period.endDate)}',
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(fontSize: 14),
                        ),
                        subtitle: Row(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isOpen
                                    ? AppTheme.accentCyan.withValues(
                                        alpha: 0.15,
                                      )
                                    : AppTheme.surfaceLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isOpen
                                    ? 'CURRENT'
                                    : '$paidCount/${pw.payments.length} paid',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isOpen
                                      ? AppTheme.accentCyan
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        children: pw.payments.map((pm) {
                          final dateTimeFormat = DateFormat('MMM d, h:mm a');
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Icon(
                                  pm.payment.isPaid
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  size: 18,
                                  color: pm.payment.isPaid
                                      ? AppTheme.success
                                      : AppTheme.textMuted,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    pm.member.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: AppTheme.textPrimary),
                                  ),
                                ),
                                Text(
                                  '\$${pm.member.amount.toStringAsFixed(2)}',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                if (pm.payment.isPaid &&
                                    pm.payment.paidAt != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    dateTimeFormat.format(pm.payment.paidAt!),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall,
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
