import 'package:firebase_messaging/firebase_messaging.dart';

/// Background FCM handler — must be top-level and annotated.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHandler(RemoteMessage message) async {
  // OS shows the notification payload; no navigation in background isolate.
}
