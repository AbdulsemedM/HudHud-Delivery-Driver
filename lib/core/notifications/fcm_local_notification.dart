import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hudhud_delivery_driver/core/notifications/legacy_notification_mapper.dart';
import 'package:hudhud_delivery_driver/core/notifications/notification_events.dart';
import 'package:hudhud_delivery_driver/core/utils/logger.dart';

/// Shared FCM tray presentation for foreground and background isolates.
///
/// Channel id must match AndroidManifest
/// `com.google.firebase.messaging.default_notification_channel_id`.
class FcmLocalNotification {
  FcmLocalNotification._();

  /// Bumped when channel sound settings change (Android channels are immutable).
  static const channelId = 'transactional_v3';
  static const channelName = 'Orders & Wallet';
  static const channelDescription =
      'Order updates, job offers, and wallet movements';
  static const androidSoundResource = 'notification_sound';
  static const iosSoundFile = 'notification_sound.caf';

  static FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Use the same plugin instance as [NotificationService] so tap routing works.
  static void bindPlugin(FlutterLocalNotificationsPlugin plugin) {
    _plugin = plugin;
  }

  static Future<void> ensureReady({
    void Function(NotificationResponse response)? onTap,
  }) async {
    if (!_initialized) {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const settings = InitializationSettings(
        android: androidSettings,
        iOS: DarwinInitializationSettings(),
      );
      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: onTap,
      );
      _initialized = true;
    }

    const channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(androidSoundResource),
    );
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);
  }

  /// Shows a tray notification. Returns false when the payload should stay silent.
  ///
  /// Backend should send data-only FCM payloads so this is the single tray path
  /// and custom sound is always applied. See [FcmPayloadSpec].
  static Future<bool> show(
    RemoteMessage message, {
    bool playSound = true,
  }) async {
    final event = LegacyNotificationMapper.resolveEvent(message.data);
    if (event == NotificationEvents.otpRequired ||
        message.data['screen']?.toString() ==
            NotificationEvents.screenVerifyDelivery) {
      return false;
    }

    final notification = message.notification;
    final title = notification?.title ??
        message.data['title']?.toString() ??
        message.data['notification_title']?.toString();
    final body = notification?.body ??
        message.data['body']?.toString() ??
        message.data['message']?.toString() ??
        message.data['notification_body']?.toString();
    if (title == null && body == null) return false;

    await ensureReady();

    final redacted = AppLogger.redactSensitive(message.data);
    final payload = jsonEncode(
      redacted is Map ? Map<String, dynamic>.from(redacted) : message.data,
    );

    await _plugin.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          playSound: playSound,
          sound: playSound
              ? const RawResourceAndroidNotificationSound(androidSoundResource)
              : null,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: playSound,
          sound: playSound ? iosSoundFile : null,
        ),
      ),
      payload: payload,
    );
    return true;
  }
}
