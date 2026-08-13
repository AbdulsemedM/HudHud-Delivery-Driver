import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hudhud_delivery_driver/core/constants/user_type_constants.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/notifications/marketing_preference_reader.dart';
import 'package:hudhud_delivery_driver/core/notifications/notification_router.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
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
        _messaging = messaging ?? FirebaseMessaging.instance,
        _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin();

  final SecureStorageService _secureStorage;
  final ApiService _apiService;
  final AppLogger _logger;
  final NotificationRouter _router;
  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  static const _transactionalChannelId = 'transactional';
  static const _transactionalChannelName = 'Orders & Wallet';

  RemoteMessage? _pendingLaunchMessage;
  String? _currentFcmToken;
  final Set<String> _subscribedTopics = {};

  /// Notifies home screens to refresh when a relevant push arrives in foreground.
  final ValueNotifier<int> homeRefreshTick = ValueNotifier(0);

  Future<void> initialize() async {
    await _initLocalNotifications();
    await _requestPermission();
    await _createAndroidChannels();
    _listenForMessages();
    await _handleInitialMessage();
    _messaging.onTokenRefresh.listen(_onTokenRefresh);

    if (await _secureStorage.hasToken()) {
      await onUserAuthenticated();
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );
  }

  Future<void> _requestPermission() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _createAndroidChannels() async {
    const channel = AndroidNotificationChannel(
      _transactionalChannelId,
      _transactionalChannelName,
      description: 'Order updates, job offers, and wallet movements',
      importance: Importance.high,
    );

    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);
  }

  void _listenForMessages() {
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);
  }

  Future<void> _handleInitialMessage() async {
    _pendingLaunchMessage = await _messaging.getInitialMessage();
  }

  /// Call after splash navigation so the navigator is ready.
  Future<void> processPendingLaunchMessage() async {
    final message = _pendingLaunchMessage;
    if (message == null) return;
    _pendingLaunchMessage = null;
    if (!await _secureStorage.hasToken()) return;
    await _router.handleMessage(message);
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    homeRefreshTick.value++;
    await _showLocalNotification(message);
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

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['body']?.toString();
    if (title == null && body == null) return;

    final payload = jsonEncode(message.data);

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _transactionalChannelId,
          _transactionalChannelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  /// Returns the current FCM token, fetching a new one if needed.
  Future<String?> getFcmToken() async {
    try {
      _currentFcmToken = await _messaging.getToken();
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
    try {
      await _messaging.subscribeToTopic(topic);
      _subscribedTopics.add(topic);
    } catch (e) {
      _logger.error('Failed to subscribe to topic $topic', e);
    }
  }

  Future<void> _unsubscribe(String topic) async {
    if (!_subscribedTopics.contains(topic)) return;
    try {
      await _messaging.unsubscribeFromTopic(topic);
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
      await _messaging.deleteToken();
    } catch (e) {
      _logger.error('Failed to delete FCM token locally', e);
    }
    _currentFcmToken = null;
  }
}

/// Convenience accessor after service locator setup.
NotificationService get notificationService => getIt<NotificationService>();
