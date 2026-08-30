import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hudhud_delivery_driver/core/notifications/fcm_local_notification.dart';
import 'package:hudhud_delivery_driver/firebase_options.dart';

/// Background FCM handler — must be top-level and annotated.
///
/// Always posts a local notification with the custom native sound.
/// Backend should send data-only payloads ([FcmPayloadSpec]) to avoid duplicate
/// tray entries when a legacy `notification` block is still present.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      final options = DefaultFirebaseOptions.maybeCurrentPlatform;
      if (options != null) {
        await Firebase.initializeApp(options: options);
      }
    }
  } catch (_) {}

  await FcmLocalNotification.ensureReady();
  await FcmLocalNotification.show(message);
}
