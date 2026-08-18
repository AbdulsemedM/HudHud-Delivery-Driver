import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hudhud_delivery_driver/core/config/google_maps_api_key_provider.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/notifications/firebase_background_handler.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';
import 'package:hudhud_delivery_driver/core/services/notification_service.dart';
import 'package:hudhud_delivery_driver/core/utils/app_localizations.dart';
import 'package:hudhud_delivery_driver/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await GoogleMapsApiKeyProvider.getApiKey();
  FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessageHandler);
  await setupServiceLocator();
  await getIt<NotificationService>().initialize();
  runApp(
    EasyLocalization(
      supportedLocales: AppLocalizations.supportedLocales,
      path: AppLocalizations.translationsPath,
      fallbackLocale: AppLocalizations.fallbackLocale,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'HudHud Admin',
      debugShowCheckedModeBanner: false,
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6F81BF)),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      routerConfig: AppRouter.router,
    );
  }
}
