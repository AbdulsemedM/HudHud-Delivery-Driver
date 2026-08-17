import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hudhud_delivery_driver/core/notifications/delivery_home_extra.dart';
import 'package:hudhud_delivery_driver/core/notifications/notification_navigation_extra.dart';
import 'package:hudhud_delivery_driver/core/notifications/notification_router.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/pages/login_page.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/pages/sign_up/sign_up_otp_verification.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/pages/sign_up/sign_up_page.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/pages/splash_page.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/pages/walkthrough_page.dart';
import 'package:hudhud_delivery_driver/features/dashboard/presentation/pages/admin_shell_page.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/pages/available_deliveries_screen.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/pages/delivery_earnings_screen.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/pages/delivery_home_page.dart';
import 'package:hudhud_delivery_driver/features/handyman/presentation/pages/handyman_shell_page.dart';
import 'package:hudhud_delivery_driver/features/ride_service/presentation/pages/available_rides_screen.dart';
import 'package:hudhud_delivery_driver/features/ride_service/presentation/pages/ride_earnings_screen.dart';
import 'package:hudhud_delivery_driver/features/ride_service/presentation/pages/ride_home_page.dart';
import 'package:hudhud_delivery_driver/features/settings/presentation/pages/google_api_key_test_page.dart';
import 'package:hudhud_delivery_driver/features/chat/data/models/chat_conversation_model.dart';
import 'package:hudhud_delivery_driver/features/chat/presentation/pages/chat_thread_screen.dart';
import 'package:hudhud_delivery_driver/features/chat/presentation/pages/delivery_conversations_screen.dart';
import 'package:hudhud_delivery_driver/features/notifications/presentation/pages/notifications_inbox_page.dart';

class AppRouter {
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');

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
  static const String testGoogleApiKey = 'test-google-api-key';
  static const String deliveryEarnings = 'delivery-earnings';
  static const String rideEarnings = 'ride-earnings';
  static const String handymanEarnings = 'handyman-earnings';
  static const String availableDeliveries = 'available-deliveries';
  static const String availableRides = 'available-rides';
  static const String deliveryConversations = 'delivery-conversations';
  static const String deliveryChat = 'delivery-chat';
  static const String supportChat = 'support-chat';
  static const String notifications = 'notifications';

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
  static const String testGoogleApiKeyPath = '/test-google-api-key';
  static const String deliveryEarningsPath = '/delivery/earnings';
  static const String rideEarningsPath = '/ride/earnings';
  static const String handymanEarningsPath = '/handyman/earnings';
  static const String availableDeliveriesPath = '/delivery/available';
  static const String availableRidesPath = '/ride/available';
  static const String deliveryConversationsPath = '/delivery/conversations';
  static const String deliveryChatPath = '/delivery/:deliveryId/chat';
  static const String supportChatPath = '/support/chat';
  static const String notificationsPath = '/notifications';

  static final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
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
        builder: (context, state) {
          final extra = state.extra;
          return DeliveryHomePage(
            initialDeliveryId:
                extra is DeliveryHomeExtra ? extra.deliveryId : null,
            showCancelledMessage:
                extra is DeliveryHomeExtra && extra.showCancelledMessage,
          );
        },
        pageBuilder: (context, state) {
          final extra = state.extra;
          return CustomTransitionPage(
            key: state.pageKey,
            child: DeliveryHomePage(
              initialDeliveryId:
                  extra is DeliveryHomeExtra ? extra.deliveryId : null,
              showCancelledMessage:
                  extra is DeliveryHomeExtra && extra.showCancelledMessage,
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
      GoRoute(
        name: handymanHome,
        path: handymanHomePath,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is HandymanShellExtra) {
            return HandymanShellPage(
              initialIndex: extra.initialIndex,
              earningsBanner: extra.earningsBanner,
            );
          }
          return const HandymanShellPage();
        },
        pageBuilder: (context, state) {
          final extra = state.extra;
          final child = extra is HandymanShellExtra
              ? HandymanShellPage(
                  initialIndex: extra.initialIndex,
                  earningsBanner: extra.earningsBanner,
                )
              : const HandymanShellPage();
          return CustomTransitionPage(
            key: state.pageKey,
            child: child,
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
      GoRoute(
        name: deliveryEarnings,
        path: deliveryEarningsPath,
        builder: (context, state) {
          final extra = state.extra;
          return DeliveryEarningsScreen(
            navigationExtra:
                extra is NotificationNavigationExtra ? extra : null,
          );
        },
      ),
      GoRoute(
        name: rideEarnings,
        path: rideEarningsPath,
        builder: (context, state) {
          final extra = state.extra;
          return RideEarningsScreen(
            navigationExtra:
                extra is NotificationNavigationExtra ? extra : null,
          );
        },
      ),
      GoRoute(
        name: handymanEarnings,
        path: handymanEarningsPath,
        builder: (context, state) {
          final extra = state.extra;
          return HandymanShellPage(
            initialIndex: 2,
            earningsBanner:
                extra is NotificationNavigationExtra ? extra : null,
          );
        },
      ),
      GoRoute(
        name: availableDeliveries,
        path: availableDeliveriesPath,
        builder: (context, state) => const AvailableDeliveriesScreen(),
      ),
      GoRoute(
        name: availableRides,
        path: availableRidesPath,
        builder: (context, state) => const AvailableRidesScreen(),
      ),
      GoRoute(
        name: deliveryConversations,
        path: deliveryConversationsPath,
        builder: (context, state) => const DeliveryConversationsScreen(),
      ),
      GoRoute(
        name: notifications,
        path: notificationsPath,
        builder: (context, state) => const NotificationsInboxPage(),
      ),
      GoRoute(
        name: deliveryChat,
        path: deliveryChatPath,
        builder: (context, state) {
          final deliveryId = int.tryParse(state.pathParameters['deliveryId'] ?? '');
          final extra = state.extra;
          int? conversationId;
          String? title;
          if (extra is Map) {
            conversationId = extra['conversationId'] is int
                ? extra['conversationId'] as int
                : int.tryParse(extra['conversationId']?.toString() ?? '');
            title = extra['title']?.toString();
          }
          return ChatThreadScreen(
            chatContext: ChatContext.delivery,
            deliveryId: deliveryId,
            conversationId: conversationId,
            title: title,
          );
        },
      ),
      GoRoute(
        name: supportChat,
        path: supportChatPath,
        builder: (context, state) {
          final extra = state.extra;
          int? conversationId;
          if (extra is Map) {
            conversationId = extra['conversationId'] is int
                ? extra['conversationId'] as int
                : int.tryParse(extra['conversationId']?.toString() ?? '');
          } else if (extra is int) {
            conversationId = extra;
          }
          return ChatThreadScreen(
            chatContext: ChatContext.support,
            conversationId: conversationId,
          );
        },
      ),
      GoRoute(
        name: testGoogleApiKey,
        path: testGoogleApiKeyPath,
        builder: (context, state) => const GoogleApiKeyTestPage(),
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
