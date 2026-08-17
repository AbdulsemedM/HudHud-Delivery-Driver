import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'package:hudhud_delivery_driver/core/constants/user_type_constants.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/notifications/delivery_home_extra.dart';
import 'package:hudhud_delivery_driver/core/notifications/legacy_notification_mapper.dart';
import 'package:hudhud_delivery_driver/core/notifications/notification_events.dart';
import 'package:hudhud_delivery_driver/core/notifications/notification_navigation_extra.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';
import 'package:hudhud_delivery_driver/core/services/secure_storage_service.dart';

/// Routes push notification taps based on `event`, then `screen` hint.
class NotificationRouter {
  NotificationRouter({
    SecureStorageService? secureStorage,
  }) : _secureStorage = secureStorage ?? getIt<SecureStorageService>();

  final SecureStorageService _secureStorage;

  Future<void> handleMessage(RemoteMessage message) async {
    await handleData(Map<String, dynamic>.from(message.data));
  }

  Future<void> handleData(Map<String, dynamic> data) async {
    final event = LegacyNotificationMapper.resolveEvent(data);
    final screen = data['screen']?.toString();

    if (LegacyNotificationMapper.isNonNavigable(event, data)) return;

    final userType = await _secureStorage.getUserType();
    final driverMode = await _secureStorage.getDriverMode();
    final enrichedData = Map<String, dynamic>.from(data);
    if (event.isNotEmpty &&
        (enrichedData['event'] == null ||
            enrichedData['event'].toString().trim().isEmpty)) {
      enrichedData['event'] = event;
    }
    final extra = NotificationNavigationExtra.fromData(enrichedData);
    final deliveryId = DeliveryHomeExtra.parseDeliveryId(enrichedData);

    if (NotificationEvents.isWalletTopUpEvent(event) ||
        NotificationEvents.isWalletTransactionsEvent(event)) {
      await _navigateToEarnings(
        userType: userType,
        driverMode: driverMode,
        extra: extra,
      );
      return;
    }

    if (NotificationEvents.isJobOfferEvent(event)) {
      await _navigateToAvailableJobs(
        userType: userType,
        driverMode: driverMode,
      );
      return;
    }

    switch (event) {
      case NotificationEvents.jobAssigned:
      case NotificationEvents.pickupReminder:
      case 'delivery_completed':
      case NotificationEvents.orderStatusChanged:
      case NotificationEvents.pickupAssigned:
      case NotificationEvents.enRoutePickup:
      case NotificationEvents.atPickup:
      case NotificationEvents.enRouteDropoff:
      case NotificationEvents.atDropoff:
      case NotificationEvents.delivered:
      case 'order_rated':
      case 'service_rated':
        await _navigateToHome(
          userType: userType,
          driverMode: driverMode,
          deliveryId: deliveryId,
        );
        return;
      case NotificationEvents.customerCancelled:
        await _navigateToHome(
          userType: userType,
          driverMode: driverMode,
          deliveryId: deliveryId,
          showCancelledMessage: true,
        );
        return;
      case 'price_drop':
        await _navigateToHome(userType: userType, driverMode: driverMode);
        return;
      default:
        await _navigateByScreenHint(
          screen: screen,
          userType: userType,
          driverMode: driverMode,
          extra: extra,
          deliveryId: deliveryId,
        );
    }
  }

  Future<void> _navigateToEarnings({
    required String? userType,
    required String? driverMode,
    required NotificationNavigationExtra extra,
  }) async {
    if (UserTypeConstants.isHandyman(userType)) {
      _go(AppRouter.handymanEarnings, extra: extra);
      return;
    }
    if (UserTypeConstants.isCourier(userType) ||
        (UserTypeConstants.isDriver(userType) && driverMode == 'delivery')) {
      _go(AppRouter.deliveryEarnings, extra: extra);
      return;
    }
    _go(AppRouter.rideEarnings, extra: extra);
  }

  Future<void> _navigateToAvailableJobs({
    required String? userType,
    required String? driverMode,
  }) async {
    if (UserTypeConstants.isHandyman(userType)) {
      _go(AppRouter.handymanHome, extra: const HandymanShellExtra(initialIndex: 1));
      return;
    }
    if (UserTypeConstants.isCourier(userType) ||
        (UserTypeConstants.isDriver(userType) && driverMode == 'delivery')) {
      _go(AppRouter.availableDeliveries);
      return;
    }
    _go(AppRouter.availableRides);
  }

  Future<void> _navigateToHome({
    required String? userType,
    required String? driverMode,
    int? deliveryId,
    bool showCancelledMessage = false,
  }) async {
    if (UserTypeConstants.isHandyman(userType)) {
      _go(AppRouter.handymanHome);
      return;
    }
    if (UserTypeConstants.isCourier(userType) ||
        (UserTypeConstants.isDriver(userType) && driverMode == 'delivery')) {
      _go(
        AppRouter.deliveryHome,
        extra: DeliveryHomeExtra(
          deliveryId: deliveryId,
          showCancelledMessage: showCancelledMessage,
        ),
      );
      return;
    }
    if (UserTypeConstants.isDriver(userType)) {
      _go(AppRouter.rideHome);
      return;
    }
    if (UserTypeConstants.isAdmin(userType)) {
      _go(AppRouter.dashboard);
    }
  }

  Future<void> _navigateByScreenHint({
    required String? screen,
    required String? userType,
    required String? driverMode,
    required NotificationNavigationExtra extra,
    int? deliveryId,
  }) async {
    switch (screen) {
      case NotificationEvents.screenWalletTopUp:
      case NotificationEvents.screenWalletTransactions:
        await _navigateToEarnings(
          userType: userType,
          driverMode: driverMode,
          extra: extra,
        );
        return;
      case 'delivery_home':
        _go(
          AppRouter.deliveryHome,
          extra: DeliveryHomeExtra(deliveryId: deliveryId),
        );
        return;
      case 'ride_home':
        _go(AppRouter.rideHome);
        return;
      case 'handyman_requests':
        _go(AppRouter.handymanHome, extra: const HandymanShellExtra(initialIndex: 1));
        return;
      default:
        await _navigateToHome(
          userType: userType,
          driverMode: driverMode,
          deliveryId: deliveryId,
        );
    }
  }

  void _go(String routeName, {Object? extra}) {
    final context = AppRouter.rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    context.goNamed(routeName, extra: extra);
  }
}

/// Passed as [GoRouter] extra when opening handyman shell on a specific tab.
class HandymanShellExtra {
  const HandymanShellExtra({
    this.initialIndex = 0,
    this.earningsBanner,
  });

  final int initialIndex;
  final NotificationNavigationExtra? earningsBanner;
}
