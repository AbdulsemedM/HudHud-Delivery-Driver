import 'package:get_it/get_it.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/services/secure_storage_service.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';
import 'package:hudhud_delivery_driver/core/utils/logger.dart';
import 'package:hudhud_delivery_driver/features/auth/data/providers/sign_up_provider.dart';
import 'package:hudhud_delivery_driver/features/auth/data/repositories/sign_up_repository.dart';

final GetIt getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // Utils
  getIt.registerLazySingleton<AppLogger>(() => AppLogger());
  getIt.registerLazySingleton<ErrorHandler>(() => ErrorHandler(getIt<AppLogger>()));
  
  // Services
  getIt.registerLazySingleton<SecureStorageService>(() => SecureStorageService());
  getIt.registerLazySingleton<ApiService>(() => ApiService(
        secureStorage: getIt(),
        logger: getIt(),
      ));
      
  // Providers
  getIt.registerLazySingleton<SignUpProvider>(() => SignUpProvider());
  
  // Repositories
  getIt.registerLazySingleton<SignUpRepository>(() => SignUpRepository(getIt()));

  // // Blocs
  // getIt.registerFactory<AuthBloc>(() => AuthBloc(secureStorage: getIt()));
  // getIt.registerFactory<SignUpBloc>(() => SignUpBloc(getIt()));
}