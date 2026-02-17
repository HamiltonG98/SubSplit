import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:subscription_management/core/theme/app_theme.dart';
import 'package:subscription_management/features/subscriptions/domain/entities/member.dart';
import 'package:subscription_management/features/subscriptions/domain/entities/payment.dart';

class MemberPaymentTile extends StatelessWidget {
  final Member member;
  final Payment? payment;
  final Color accentColor;
  final String currencySymbol;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const MemberPaymentTile({
    super.key,
    required this.member,
    this.payment,
    required this.accentColor,
    this.currencySymbol = '\$',
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isPaid = payment?.isPaid ?? false;
    final dateFormat = DateFormat('MMM d, h:mm a');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: isPaid
              ? AppTheme.success.withValues(alpha: 0.08)
              : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPaid
                ? AppTheme.success.withValues(alpha: 0.3)
                : AppTheme.cardBorder,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          leading: GestureDetector(
            onTap: () => onToggle(!isPaid),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isPaid ? AppTheme.success : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isPaid ? AppTheme.success : AppTheme.textMuted,
                  width: 2,
                ),
              ),
              child: isPaid
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 22,
                    )
                  : null,
            ),
          ),
          title: Text(
            member.name,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              decoration: isPaid ? TextDecoration.lineThrough : null,
              color: isPaid ? AppTheme.textSecondary : null,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$currencySymbol${member.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              if (isPaid && payment?.paidAt != null)
                Text(
                  'Paid ${dateFormat.format(payment!.paidAt!)}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: AppTheme.success),
                ),
            ],
          ),
          trailing: PopupMenuButton(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: AppTheme.textMuted,
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(
                      Icons.edit_rounded,
                      color: AppTheme.accentCyan,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      color: AppTheme.error,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text('Remove', style: TextStyle(color: AppTheme.error)),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
          ),
        ),
      ),
    );
  }
}
