import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hudhud_delivery_driver/core/constants/user_type_constants.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/notifications/delivery_home_extra.dart';
import 'package:hudhud_delivery_driver/core/notifications/fcm_local_notification.dart';
import 'package:hudhud_delivery_driver/core/notifications/marketing_preference_reader.dart';
import 'package:hudhud_delivery_driver/core/notifications/notification_events.dart';
import 'package:hudhud_delivery_driver/core/notifications/notification_router.dart';
import 'package:hudhud_delivery_driver/core/notifications/notification_sound_player.dart';
import 'package:hudhud_delivery_driver/core/models/food_dispatch_offer.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/services/food_offer_coordinator.dart';
import 'package:hudhud_delivery_driver/core/services/secure_storage_service.dart';
import 'package:hudhud_delivery_driver/core/utils/logger.dart';

/// Handles FCM permissions, token lifecycle, topic subscriptions, and routing.
class NotificationService {
  NotificationService({
    required SecureStorageService secureStorage,
    required ApiService apiService,
    required AppLogger logger,
    NotificationRouter? router,
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : _secureStorage = secureStorage,
        _apiService = apiService,
        _logger = logger,
        _router = router ?? NotificationRouter(secureStorage: secureStorage),
        _messaging = messaging,
        _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin();

  final SecureStorageService _secureStorage;
  final ApiService _apiService;
  final AppLogger _logger;
  final NotificationRouter _router;
  FirebaseMessaging? _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  bool get _firebaseReady => Firebase.apps.isNotEmpty;

  FirebaseMessaging? get _safeMessaging {
    if (!_firebaseReady) return null;
    return _messaging ??= FirebaseMessaging.instance;
  }

  RemoteMessage? _pendingLaunchMessage;

  /// Payload of a local notification (posted by the background isolate for
  /// a data-only push, e.g. `food_dispatch_offer`) that launched the app
  /// from a killed state. Not delivered to `onDidReceiveNotificationResponse`.
  String? _pendingLaunchPayload;
  String? _currentFcmToken;
  final Set<String> _subscribedTopics = {};

  /// Notifies home screens to refresh when a relevant push arrives in foreground.
  final ValueNotifier<int> homeRefreshTick = ValueNotifier(0);

  /// Latest delivery-related push context for targeted refresh.
  final ValueNotifier<DeliveryPushRefresh?> lastDeliveryPush = ValueNotifier(null);

  Future<void> initialize() async {
    await _initLocalNotifications();
    await _captureLocalNotificationLaunch();
    final messaging = _safeMessaging;
    if (messaging == null) {
      _logger.info('Skipping FCM setup; Firebase is not initialized.');
      return;
    }
    await _requestPermission();
    _listenForMessages();
    await _handleInitialMessage();
    messaging.onTokenRefresh.listen(_onTokenRefresh);

    if (await _secureStorage.hasToken()) {
      await onUserAuthenticated();
    }
  }

  Future<void> _initLocalNotifications() async {
    FcmLocalNotification.bindPlugin(_localNotifications);
    await FcmLocalNotification.ensureReady(
      onTap: _onLocalNotificationTap,
    );
  }

  Future<void> _requestPermission() async {
    await _safeMessaging?.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    await _safeMessaging?.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: false,
    );
  }

  void _listenForMessages() {
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);
  }

  Future<void> _handleInitialMessage() async {
    _pendingLaunchMessage = await _safeMessaging?.getInitialMessage();
  }

  Future<void> _captureLocalNotificationLaunch() async {
    try {
      final details =
          await _localNotifications.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp != true) return;
      final payload = details?.notificationResponse?.payload;
      if (payload != null && payload.isNotEmpty) {
        _pendingLaunchPayload = payload;
      }
    } catch (e) {
      _logger.error('Failed to read notification launch details', e);
    }
  }

  /// Call after splash navigation so the navigator is ready.
  Future<void> processPendingLaunchMessage() async {
    final message = _pendingLaunchMessage;
    final payload = _pendingLaunchPayload;
    _pendingLaunchMessage = null;
    _pendingLaunchPayload = null;
    if (message == null && payload == null) return;
    if (!await _secureStorage.hasToken()) return;
    if (message != null) {
      await _router.handleMessage(message);
      return;
    }
    try {
      final data = Map<String, dynamic>.from(jsonDecode(payload!) as Map);
      await _router.handleMessage(RemoteMessage(data: data));
    } catch (e) {
      _logger.error('Failed to parse launch notification payload', e);
    }
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    // Phase 10: a food-order offer opens the full-screen offer card at once
    // (no banner to tap; the card has its own countdown).
    if (FoodDispatchOffer.isOfferPush(message.data) &&
        getIt.isRegistered<FoodOfferCoordinator>()) {
      await NotificationSoundPlayer.play();
      await getIt<FoodOfferCoordinator>().handlePush(
        Map<String, dynamic>.from(message.data),
      );
      return;
    }
    lastDeliveryPush.value = DeliveryPushRefresh(
      deliveryId: DeliveryHomeExtra.parseDeliveryId(message.data),
      status: NotificationEvents.parseDeliveryStatus(message.data),
    );
    homeRefreshTick.value++;
    await NotificationSoundPlayer.play();
    await FcmLocalNotification.show(message, playSound: false);
  }

  Future<void> _onMessageOpened(RemoteMessage message) async {
    if (!await _secureStorage.hasToken()) return;
    await _router.handleMessage(message);
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final data = Map<String, dynamic>.from(jsonDecode(payload) as Map);
      _router.handleMessage(RemoteMessage(data: data));
    } catch (e) {
      _logger.error('Failed to parse notification payload', e);
    }
  }

  /// Returns the current FCM token, fetching a new one if needed.
  Future<String?> getFcmToken() async {
    try {
      _currentFcmToken = await _safeMessaging?.getToken();
      return _currentFcmToken;
    } catch (e) {
      _logger.error('Failed to get FCM token', e);
      return null;
    }
  }

  Future<void> onUserAuthenticated() async {
    final token = await getFcmToken();
    if (token != null) {
      await _registerTokenWithBackend(token);
    }
    await _subscribeToTopics();
  }

  Future<void> _onTokenRefresh(String token) async {
    _currentFcmToken = token;
    if (await _secureStorage.hasToken()) {
      await _registerTokenWithBackend(token);
    }
  }

  Future<void> _registerTokenWithBackend(String token) async {
    try {
      await _apiService.updateDeviceToken(token);
    } catch (e) {
      _logger.error('Failed to register device token with backend', e);
    }
  }

  Future<void> _subscribeToTopics() async {
    final userId = await _secureStorage.getUserId();
    final userType = await _secureStorage.getUserType();
    if (userId != null && userId.isNotEmpty) {
      await _subscribe('rider_$userId');
    }
    await _subscribe('system_updates');

    final cityCode = await _fetchCityCode(userType);
    if (cityCode != null && cityCode.isNotEmpty) {
      await _subscribe('riders_$cityCode');
    }

    final marketingReader = MarketingPreferenceReader(_secureStorage);
    Map<String, dynamic>? driverProfile;
    Map<String, dynamic>? handymanProfile;
    try {
      if (UserTypeConstants.isHandyman(userType)) {
        handymanProfile = await _apiService.getHandymanProfile();
      } else {
        driverProfile = await _apiService.getDriverProfile();
      }
    } catch (_) {}

    final marketingEnabled = await marketingReader.resolve(
      userType: userType,
      driverProfile: driverProfile,
      handymanProfile: handymanProfile,
    );
    if (marketingEnabled) {
      await _subscribe('promotions');
    }
  }

  Future<String?> _fetchCityCode(String? userType) async {
    try {
      if (UserTypeConstants.isHandyman(userType)) {
        final profile = await _apiService.getHandymanProfile();
        if (profile == null) return null;
        final handymanProfile = profile['handyman_profile'];
        if (handymanProfile is Map<String, dynamic>) {
          final code = handymanProfile['city_code'] ?? handymanProfile['city'];
          if (code != null) {
            return code.toString().toLowerCase().replaceAll(' ', '_');
          }
        }
        final address = profile['address']?.toString();
        if (address != null && address.isNotEmpty) {
          return _cityCodeFromAddress(address);
        }
        return null;
      }

      final profile = await _apiService.getDriverProfile();
      if (profile == null) return null;
      final driverProfile = profile['driver_profile'];
      if (driverProfile is Map<String, dynamic>) {
        final code = driverProfile['city_code'] ?? driverProfile['city'];
        return code?.toString().toLowerCase().replaceAll(' ', '_');
      }
    } catch (_) {}
    return null;
  }

  String? _cityCodeFromAddress(String address) {
    final firstSegment = address.split(',').first.trim();
    if (firstSegment.isEmpty) return null;
    return firstSegment.toLowerCase().replaceAll(' ', '_');
  }

  Future<void> _subscribe(String topic) async {
    if (_subscribedTopics.contains(topic)) return;
    final messaging = _safeMessaging;
    if (messaging == null) return;
    try {
      await messaging.subscribeToTopic(topic);
      _subscribedTopics.add(topic);
    } catch (e) {
      _logger.error('Failed to subscribe to topic $topic', e);
    }
  }

  Future<void> _unsubscribe(String topic) async {
    if (!_subscribedTopics.contains(topic)) return;
    final messaging = _safeMessaging;
    if (messaging == null) {
      _subscribedTopics.remove(topic);
      return;
    }
    try {
      await messaging.unsubscribeFromTopic(topic);
      _subscribedTopics.remove(topic);
    } catch (e) {
      _logger.error('Failed to unsubscribe from topic $topic', e);
    }
  }

  /// Call before clearing secure storage on logout.
  Future<void> teardown() async {
    final token = _currentFcmToken ?? await getFcmToken();
    if (token != null) {
      try {
        await _apiService.removeDeviceToken(token);
      } catch (e) {
        _logger.error('Failed to remove device token from backend', e);
      }
    }

    for (final topic in _subscribedTopics.toList()) {
      await _unsubscribe(topic);
    }

    try {
      await _safeMessaging?.deleteToken();
    } catch (e) {
      _logger.error('Failed to delete FCM token locally', e);
    }
    _currentFcmToken = null;
  }
}

/// Convenience accessor after service locator setup.
NotificationService get notificationService => getIt<NotificationService>();

/// Delivery identity parsed from a foreground push for home-screen refresh.
class DeliveryPushRefresh {
  const DeliveryPushRefresh({this.deliveryId, this.status});

  final int? deliveryId;
  final String? status;
}
