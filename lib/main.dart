import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hudhud_delivery_driver/core/auth/logout_helper.dart';
import 'package:hudhud_delivery_driver/core/config/google_maps_api_key_provider.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/notifications/firebase_background_handler.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';
import 'package:hudhud_delivery_driver/core/services/notification_service.dart';
import 'package:hudhud_delivery_driver/core/services/wallet_topup_recovery_service.dart';
import 'package:hudhud_delivery_driver/core/utils/app_localizations.dart';
import 'package:hudhud_delivery_driver/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await _initFirebase();
  await GoogleMapsApiKeyProvider.getApiKey();
  await setupServiceLocator();
  LogoutHelper.registerLoginRedirect(() {
    final location = AppRouter.router.routeInformationProvider.value.uri.path;
    if (location == AppRouter.loginPath) return;
    AppRouter.router.goNamed(AppRouter.login);
  });
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

Future<void> _initFirebase() async {
  try {
    final options = DefaultFirebaseOptions.maybeCurrentPlatform;
    if (options == null) {
      debugPrint(
        'Firebase is not configured for this platform; continuing without FCM.',
      );
      return;
    }
    await Firebase.initializeApp(options: options);
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessageHandler);
  } catch (e, stackTrace) {
    debugPrint('Firebase init skipped: $e\n$stackTrace');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    getIt<WalletTopUpRecoveryService>().attach();
  }

  @override
  void dispose() {
    getIt<WalletTopUpRecoveryService>().detach();
    super.dispose();
  }

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
