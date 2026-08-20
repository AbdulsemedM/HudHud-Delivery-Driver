import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hudhud_delivery_driver/core/auth/application_status_gate.dart';
import 'package:hudhud_delivery_driver/core/auth/force_update_gate.dart';
import 'package:hudhud_delivery_driver/core/auth/phone_verification_gate.dart';
import 'package:hudhud_delivery_driver/core/constants/application_status.dart';
import 'package:hudhud_delivery_driver/core/constants/user_type_constants.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/services/notification_service.dart';
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

    final needsUpdate = await ForceUpdateGate.ensureUpToDate(context);
    if (!mounted || needsUpdate) return;

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
    } else if (UserTypeConstants.isDriver(userType) ||
        UserTypeConstants.isCourier(userType)) {
      final phoneOk = await PhoneVerificationGate.ensurePhoneVerified(context);
      if (!mounted) return;
      if (!phoneOk) {
        context.goNamed(AppRouter.login);
        return;
      }
      final gated = await _routeDriverByApplicationStatus(secureStorage);
      if (gated) return;
      if (UserTypeConstants.isCourier(userType)) {
        context.goNamed(AppRouter.deliveryHome);
      } else {
        final driverMode = await secureStorage.getDriverMode();
        context.goNamed(
          driverMode == 'delivery' ? AppRouter.deliveryHome : AppRouter.rideHome,
        );
      }
    } else {
      await secureStorage.clearAll();
      context.goNamed(AppRouter.login);
    }

    if (mounted) {
      await getIt<NotificationService>().processPendingLaunchMessage();
    }
  }

  /// Returns true when navigation to pending/suspended already happened.
  Future<bool> _routeDriverByApplicationStatus(
    SecureStorageService storage,
  ) async {
    var status = await storage.getApplicationStatus();
    try {
      final res = await getIt<ApiService>().getDriverApplicationStatus();
      final fresh = ApplicationStatus.normalize(
            res?['application_status']?.toString(),
          ) ??
          ApplicationStatus.fromLegacyUserStatus(res?['status']?.toString());
      if (fresh != null) {
        status = fresh;
        await ApplicationStatusGate.persist(
          fresh,
          reason: ApplicationStatus.reasonFrom(res),
        );
      }
    } catch (_) {}
    if (!mounted) return true;
    final route = ApplicationStatusGate.routeFor(status);
    if (route != null) {
      context.goNamed(route);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/images/logo.jpg',
                width: 120,
                height: 120,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'HudHud Admin',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
    );
  }
}