import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hudhud_delivery_driver/core/constants/user_type_constants.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';
import 'package:hudhud_delivery_driver/core/services/secure_storage_service.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/pages/walkthrough_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final hasSeenWalkthrough = await WalkthroughPage.hasSeenWalkthrough();
    if (!hasSeenWalkthrough) {
      context.goNamed(AppRouter.walkthrough);
      return;
    }
    final secureStorage = getIt<SecureStorageService>();
    final hasToken = await secureStorage.hasToken();
    if (!hasToken) {
      context.goNamed(AppRouter.login);
      return;
    }
    final userType = await secureStorage.getUserType();
    if (UserTypeConstants.isAdmin(userType)) {
      context.goNamed(AppRouter.dashboard);
    } else if (UserTypeConstants.isHandyman(userType)) {
      context.goNamed(AppRouter.handymanHome);
    } else if (UserTypeConstants.isDriver(userType)) {
      final driverMode = await secureStorage.getDriverMode();
      if (driverMode == 'delivery') {
        context.goNamed(AppRouter.deliveryHome);
      } else {
        context.goNamed(AppRouter.rideHome);
      }
    } else if (UserTypeConstants.isCourier(userType)) {
      context.goNamed(AppRouter.deliveryHome);
    } else {
      await secureStorage.clearAll();
      context.goNamed(AppRouter.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const FlutterLogo(size: 100),
            const SizedBox(height: 24),
            Text(
              'HudHud Delivery',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
    );
  }
}