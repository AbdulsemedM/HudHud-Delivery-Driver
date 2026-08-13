import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/services/notification_service.dart';
import 'package:hudhud_delivery_driver/core/services/secure_storage_service.dart';

/// Clears push notification state before wiping local auth storage.
class LogoutHelper {
  static Future<void> logout() async {
    await getIt<NotificationService>().teardown();
    await getIt<SecureStorageService>().clearAll();
  }
}
