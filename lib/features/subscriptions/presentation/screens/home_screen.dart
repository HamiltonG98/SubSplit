import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:subscription_management/core/theme/app_theme.dart';
import 'package:subscription_management/features/subscriptions/presentation/providers/subscription_providers.dart';
import 'package:subscription_management/features/subscriptions/presentation/screens/add_subscription_screen.dart';
import 'package:subscription_management/features/subscriptions/presentation/screens/subscription_detail_screen.dart';
import 'package:subscription_management/features/subscriptions/presentation/widgets/subscription_card.dart';

import 'package:subscription_management/core/di/injection_container.dart' as di;
import 'package:subscription_management/core/services/notification_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize and request permissions after the UI is built
    // to avoid hanging the splash screen on Android
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await di.sl<NotificationService>().init();
      await di.sl<NotificationService>().requestPermissions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionsAsync = ref.watch(subscriptionListProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: true,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'My Subscriptions',
                style: Theme.of(context).appBarTheme.titleTextStyle,
              ),
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () =>
                      ref.read(subscriptionListProvider.notifier).load(),
                ),
              ),
            ],
          ),
          subscriptionsAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.accentCyan),
              ),
            ),
            error: (err, _) => SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                    const SizedBox(height: 12),
                    Text(
                      'Something went wrong',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      err.toString(),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            data: (summaries) {
              if (summaries.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.subscriptions_outlined,
                            size: 40,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No subscriptions yet',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap + to add your first shared subscription',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.only(bottom: 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final summary = summaries[index];
                    return Slidable(
                      endActionPane: ActionPane(
                        motion: const BehindMotion(),
                        children: [
                          SlidableAction(
                            onPressed: (_) => _confirmDelete(
                              context,
                              summary.subscription.id!,
                            ),
                            backgroundColor: AppTheme.error,
                            foregroundColor: Colors.white,
                            icon: Icons.delete_rounded,
                            label: 'Delete',
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ],
                      ),
                      child: SubscriptionCard(
                        summary: summary,
                        index: index,
                        onTap: () =>
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SubscriptionDetailScreen(
                                  subscriptionId: summary.subscription.id!,
                                ),
                              ),
                            ).then(
                              (_) => ref
                                  .read(subscriptionListProvider.notifier)
                                  .load(),
                            ),
                      ),
                    );
                  }, childCount: summaries.length),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddSubscriptionScreen()),
        ).then((_) => ref.read(subscriptionListProvider.notifier).load()),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  void _confirmDelete(BuildContext context, int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Subscription'),
        content: const Text(
          'This will permanently delete this subscription and all its payment history. Continue?',
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
              Navigator.pop(ctx);
              ref
                  .read(subscriptionListProvider.notifier)
                  .deleteSubscription(id);
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
