import 'package:get_it/get_it.dart';
import '../api_client.dart';
import 'auth_service.dart';
import 'location_service.dart';
import 'friends_service.dart';
import 'status_service.dart';
import 'ar_tag_service.dart';
import 'notification_service.dart';
import 'event_service.dart';
import 'local_storage_service.dart';

final GetIt getIt = GetIt.instance;

void setupServiceLocator() {
  // Core dependency
  getIt.registerLazySingleton<ApiClient>(() => ApiClient());

  // Services that depend on ApiClient
  getIt.registerLazySingleton<AuthService>(() => AuthService(getIt<ApiClient>()));
  getIt.registerLazySingleton<LocationService>(() => LocationService(getIt<ApiClient>()));
  getIt.registerLazySingleton<FriendsService>(() => FriendsService(getIt<ApiClient>()));
  getIt.registerLazySingleton<StatusService>(() => StatusService(getIt<ApiClient>()));
  getIt.registerLazySingleton<ARTagService>(() => ARTagService(getIt<ApiClient>()));
  getIt.registerLazySingleton<NotificationService>(() => NotificationService(getIt<ApiClient>()));
  getIt.registerLazySingleton<EventService>(() => EventService(getIt<ApiClient>()));

  // Independent service
  getIt.registerLazySingleton<LocalStorageService>(() => LocalStorageService());
}
