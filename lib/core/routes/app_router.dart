import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/pages/login_page.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/pages/sign_up/sign_up_otp_verification.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/pages/sign_up/sign_up_page.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/pages/splash_page.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/pages/walkthrough_page.dart';
import 'package:hudhud_delivery_driver/features/dashboard/presentation/pages/admin_shell_page.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/pages/delivery_home_page.dart';
import 'package:hudhud_delivery_driver/features/handyman/presentation/pages/handyman_shell_page.dart';
import 'package:hudhud_delivery_driver/features/ride_service/presentation/pages/ride_home_page.dart';

class AppRouter {
  static final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

  // Route names
  static const String splash = 'splash';
  static const String walkthrough = 'walkthrough';
  static const String login = 'login';
  static const String dashboard = 'dashboard';
  static const String rideHome = 'ride-home';
  static const String deliveryHome = 'delivery-home';
  static const String handymanHome = 'handyman-home';
  static const String signUp = 'sign-up';
  static const String signUpOtp = 'sign-up-otp';

  // Route paths
  static const String splashPath = '/';
  static const String walkthroughPath = '/walkthrough';
  static const String loginPath = '/login';
  static const String signUpPath = '/sign-up';
  static const String dashboardPath = '/dashboard';
  static const String rideHomePath = '/ride-home';
  static const String deliveryHomePath = '/delivery-home';
  static const String handymanHomePath = '/handyman-home';
  static const String signUpOtpPath = '/sign-up-otp';

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: splashPath,
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        name: splash,
        path: splashPath,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        name: walkthrough,
        path: walkthroughPath,
        builder: (context, state) => const WalkthroughPage(),
      ),
      GoRoute(
        name: login,
        path: loginPath,
        builder: (context, state) => const LoginPage(),
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const LoginPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        name: signUp,
        path: signUpPath,
        builder: (context, state) => const SignUpPage(),
      ),
      GoRoute(
        name: dashboard,
        path: dashboardPath,
        builder: (context, state) => const AdminShellPage(),
      ),
      GoRoute(
        name: rideHome,
        path: rideHomePath,
        builder: (context, state) => const RideHomePage(),
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const RideHomePage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        name: deliveryHome,
        path: deliveryHomePath,
        builder: (context, state) => const DeliveryHomePage(),
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const DeliveryHomePage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        name: handymanHome,
        path: handymanHomePath,
        builder: (context, state) => const HandymanShellPage(),
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const HandymanShellPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        name: signUpOtp,
        path: signUpOtpPath,
        builder: (context, state) {
          final email = state.extra as Map<String, dynamic>?;
          return SignUpOtpVerification(
            email: email?['email'],
            phone: email?['phone'],
          );
        },
        pageBuilder: (context, state) {
          final email = state.extra as Map<String, dynamic>?;
          return CustomTransitionPage(
            key: state.pageKey,
            child: SignUpOtpVerification(
              email: email?['email'],
              phone: email?['phone'],
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              );
            },
          );
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Error: ${state.error}'),
      ),
    ),
  );
}
