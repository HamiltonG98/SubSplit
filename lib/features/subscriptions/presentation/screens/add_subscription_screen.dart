import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subscription_management/core/di/injection_container.dart';
import 'package:subscription_management/core/theme/app_theme.dart';
import 'package:subscription_management/core/widgets/app_toast.dart';
import 'package:subscription_management/features/subscriptions/domain/entities/member.dart'
    as domain;
import 'package:subscription_management/features/subscriptions/domain/entities/subscription.dart'
    as domain;
import 'package:subscription_management/features/subscriptions/domain/repositories/subscription_repository.dart';
import 'package:subscription_management/features/subscriptions/presentation/providers/subscription_providers.dart';

class AddSubscriptionScreen extends ConsumerStatefulWidget {
  const AddSubscriptionScreen({super.key});

  @override
  ConsumerState<AddSubscriptionScreen> createState() =>
      _AddSubscriptionScreenState();
}

class _AddSubscriptionScreenState extends ConsumerState<AddSubscriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _costController = TextEditingController();
  final _billingDayController = TextEditingController(text: '1');

  Color _selectedColor = AppTheme.subscriptionColors[0];
  String _selectedCurrency = 'USD';
  final List<_MemberEntry> _members = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _costController.dispose();
    _billingDayController.dispose();
    for (final m in _members) {
      m.nameController.dispose();
    }
    super.dispose();
  }

  void _addMemberField() {
    setState(() {
      _members.add(_MemberEntry(nameController: TextEditingController()));
    });
  }

  void _removeMemberField(int index) {
    setState(() {
      _members[index].nameController.dispose();
      _members.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_members.isEmpty) {
      AppToast.show(
        context,
        message: 'Add at least one member',
        type: ToastType.warning,
      );
      return;
    }

    setState(() => _isLoading = true);

    final subscription = domain.Subscription(
      name: _nameController.text.trim(),
      color: AppTheme.colorToHex(_selectedColor),
      totalCost: double.parse(_costController.text),
      billingDay: int.parse(_billingDayController.text),
      currency: _selectedCurrency,
      createdAt: DateTime.now(),
    );

    final members = _members
        .map(
          (m) => domain.Member(
            subscriptionId: 0, // will be set by repo
            name: m.nameController.text.trim(),
            amount: 0, // auto-calculated by repository
            createdAt: DateTime.now(),
          ),
        )
        .toList();

    final repo = sl<SubscriptionRepository>();
    final result = await repo.addSubscription(subscription, members);

    if (!mounted) return;

    setState(() => _isLoading = false);

    result.fold(
      (failure) {
        AppToast.show(context, message: failure.message, type: ToastType.error);
      },
      (_) {
        ref.read(subscriptionListProvider.notifier).load();
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Subscription')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Name ──
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Subscription Name',
                hintText: 'e.g. Netflix, Spotify, Disney+',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name is required' : null,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            // ── Cost & Billing Day ──
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _costController,
                    decoration: const InputDecoration(
                      labelText: 'Total Cost',
                      hintText: '15.99',
                      prefixText: '\$ ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Invalid';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _billingDayController,
                    decoration: const InputDecoration(
                      labelText: 'Billing Day',
                      hintText: '1-28',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      final day = int.tryParse(v);
                      if (day == null || day < 1 || day > 28) {
                        return '1-28';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Currency Selector ──
            Text('Currency', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Row(
              children: [
                _CurrencyChip(
                  label: 'USD',
                  subtitle: 'US Dollar',
                  symbol: '\$',
                  isSelected: _selectedCurrency == 'USD',
                  onTap: () => setState(() => _selectedCurrency = 'USD'),
                ),
                const SizedBox(width: 12),
                _CurrencyChip(
                  label: 'NIO',
                  subtitle: 'Córdoba',
                  symbol: 'C\$',
                  isSelected: _selectedCurrency == 'NIO',
                  onTap: () => setState(() => _selectedCurrency = 'NIO'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Color Picker ──
            Text('Color', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: AppTheme.subscriptionColors.map((color) {
                final isSelected = _selectedColor == color;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.5),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 20,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),

            // ── Members ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Members', style: Theme.of(context).textTheme.titleMedium),
                TextButton.icon(
                  onPressed: _addMemberField,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.accentCyan,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_members.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Center(
                  child: Text(
                    'Add members who share this subscription',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              )
            else
              ...List.generate(_members.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _members[i].nameController,
                            decoration: const InputDecoration(
                              labelText: 'Name',
                              hintText: 'e.g. Juan',
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Required'
                                : null,
                            textCapitalization: TextCapitalization.words,
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: () => _removeMemberField(i),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: AppTheme.error,
                            size: 20,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

            const SizedBox(height: 32),

            // ── Save Button ──
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppTheme.scaffoldBg,
                        ),
                      )
                    : const Text('Create Subscription'),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _MemberEntry {
  final TextEditingController nameController;

  _MemberEntry({required this.nameController});
}

class _CurrencyChip extends StatelessWidget {
  final String label;
  final String subtitle;
  final String symbol;
  final bool isSelected;
  final VoidCallback onTap;

  const _CurrencyChip({
    required this.label,
    required this.subtitle,
    required this.symbol,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.accentCyan.withValues(alpha: 0.1)
                : AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppTheme.accentCyan : AppTheme.cardBorder,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.accentCyan.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.accentCyan.withValues(alpha: 0.2)
                      : AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    symbol,
                    style: TextStyle(
                      color: isSelected
                          ? AppTheme.accentCyan
                          : AppTheme.textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isSelected
                          ? AppTheme.textSecondary
                          : AppTheme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
