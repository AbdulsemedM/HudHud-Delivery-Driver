import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/pages/login_page.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/pages/sign_up/sign_up_otp_verification.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/pages/splash_page.dart';
import 'package:hudhud_delivery_driver/features/dashboard/presentation/pages/admin_shell_page.dart';
import 'package:hudhud_delivery_driver/features/home/presentation/pages/home_page.dart';
import 'package:hudhud_delivery_driver/features/profile/presentation/pages/profile_page.dart';

class AppRouter {
  static final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  // static final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

  // Route names
  static const String splash = 'splash';
  static const String login = 'login';
  static const String dashboard = 'dashboard';
  static const String home = 'home';
  static const String profile = 'profile';
  static const String signUpOtp = 'sign-up-otp';

  // Route paths
  static const String splashPath = '/';
  static const String loginPath = '/login';
  static const String dashboardPath = '/dashboard';
  static const String homePath = '/home';
  static const String profilePath = '/profile';
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
        name: dashboard,
        path: dashboardPath,
        builder: (context, state) => const AdminShellPage(),
      ),
      GoRoute(
        name: home,
        path: homePath,
        builder: (context, state) => const HomePage(),
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const HomePage(),
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
        name: profile,
        path: profilePath,
        builder: (context, state) => const ProfilePage(),
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const ProfilePage(),
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