import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subscription_management/core/di/injection_container.dart' as di;
import 'package:subscription_management/core/services/notification_service.dart';
import 'package:subscription_management/core/theme/app_theme.dart';
import 'package:subscription_management/features/subscriptions/presentation/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.initDependencies();
  await di.sl<NotificationService>().init();
  await di.sl<NotificationService>().requestPermissions();

  runApp(const ProviderScope(child: SubscriptionApp()));
}

class SubscriptionApp extends StatelessWidget {
  const SubscriptionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SubSplit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
