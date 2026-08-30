/// Backend FCM payload contract for HudHud driver app notifications.
///
/// **Preferred: data-only messages** so the app always displays tray notifications
/// with the custom sound (`notification_sound` on Android, `notification_sound.caf`
/// on iOS). Do not include a top-level `notification` block.
///
/// ```json
/// {
///   "message": {
///     "token": "<device_token>",
///     "data": {
///       "title": "New delivery",
///       "body": "Pickup at ...",
///       "event": "nearby_job_available",
///       "delivery_id": "123"
///     }
///   }
/// }
/// ```
///
/// If a `notification` block is kept temporarily, never send `"sound": "default"`.
/// Use channel [FcmLocalNotification.channelId] and:
/// - Android: `android.notification.channel_id`, `android.notification.sound`
/// - iOS/APNs: `apns.payload.aps.sound` = `notification_sound.caf`
library;

import 'package:hudhud_delivery_driver/core/notifications/fcm_local_notification.dart';

/// Documents expected server-side FCM fields (not used at runtime).
abstract final class FcmPayloadSpec {
  static const preferredChannelId = FcmLocalNotification.channelId;
  static const androidSound = FcmLocalNotification.androidSoundResource;
  static const iosSound = FcmLocalNotification.iosSoundFile;

  static const dataKeys = [
    'title',
    'body',
    'message',
    'notification_title',
    'notification_body',
    'event',
    'screen',
    'delivery_id',
  ];
}
