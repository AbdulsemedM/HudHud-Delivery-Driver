import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hudhud_delivery_driver/core/notifications/fcm_local_notification.dart';
import 'package:hudhud_delivery_driver/firebase_options.dart';

/// Background FCM handler — must be top-level and annotated.
///
/// Data-only FCM payloads are not shown by Android. This isolate must post
/// a local notification (native channel sound). Notification+data payloads
/// are left to the system tray / APNs sound from the FCM payload.
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
  await FcmLocalNotification.show(
    message,
    skipIfSystemWillDisplay: true,
  );
}
