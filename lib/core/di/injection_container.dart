import 'package:get_it/get_it.dart';
import 'package:subscription_management/core/services/notification_service.dart';
import 'package:subscription_management/features/subscriptions/data/datasources/app_database.dart';
import 'package:subscription_management/features/subscriptions/data/repositories/subscription_repository_impl.dart';
import 'package:subscription_management/features/subscriptions/domain/repositories/subscription_repository.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // Services
  sl.registerLazySingleton<NotificationService>(() => NotificationService());

  // Database
  sl.registerLazySingleton<AppDatabase>(() => AppDatabase());

  // Repository
  sl.registerLazySingleton<SubscriptionRepository>(
    () => SubscriptionRepositoryImpl(
      sl<AppDatabase>(),
      sl<NotificationService>(),
    ),
  );
}
