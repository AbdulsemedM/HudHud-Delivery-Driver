import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/services/active_delivery_cache.dart';
import 'package:hudhud_delivery_driver/core/services/driver_location_heartbeat.dart';
import 'package:hudhud_delivery_driver/core/services/notification_service.dart';
import 'package:hudhud_delivery_driver/core/services/secure_storage_service.dart';

/// Clears push notification state before wiping local auth storage.
class LogoutHelper {
  static bool _handlingUnauthenticated = false;
  static VoidCallback? _redirectToLogin;

  /// Register once from app startup (avoids ApiService ↔ AppRouter import cycles).
  static void registerLoginRedirect(VoidCallback redirect) {
    _redirectToLogin = redirect;
  }

  static Future<void> logout() async {
    try {
      if (getIt.isRegistered<DriverLocationHeartbeat>()) {
        await getIt<DriverLocationHeartbeat>().stop();
      }
    } catch (_) {}
    try {
      if (getIt.isRegistered<ActiveDeliveryCache>()) {
        await getIt<ActiveDeliveryCache>().clear();
      }
    } catch (_) {}
    await getIt<NotificationService>().teardown();
    await getIt<SecureStorageService>().clearSession();
  }

  /// Global handler for API 401 / Unauthenticated responses.
  /// Logs out once, then redirects to login (debounced for parallel failures).
  static Future<void> handleUnauthenticated() async {
    if (_handlingUnauthenticated) return;
    _handlingUnauthenticated = true;
    try {
      await logout();
      _redirectToLogin?.call();
    } catch (e, st) {
      debugPrint('LogoutHelper.handleUnauthenticated failed: $e\n$st');
    } finally {
      // Allow a later session expiry after the user logs in again.
      unawaited(
        Future<void>.delayed(const Duration(seconds: 2), () {
          _handlingUnauthenticated = false;
        }),
      );
    }
  }
}
