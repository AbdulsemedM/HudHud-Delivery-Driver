import 'package:hudhud_delivery_driver/core/notifications/notification_events.dart';

/// Maps legacy server notification class names and payload shapes to
/// standardized [event] strings for routing.
class LegacyNotificationMapper {
  LegacyNotificationMapper._();

  /// Resolves the routing event from FCM [data], checking `event` first then
  /// legacy `type` / notification class names.
  static String resolveEvent(Map<String, dynamic> data) {
    final explicit = NotificationEvents.normalizeEvent(data['event']?.toString());
    if (explicit.isNotEmpty) return explicit;

    final candidates = [
      data['type']?.toString(),
      data['notification_type']?.toString(),
      data['notification']?.toString(),
      data['class']?.toString(),
    ];

    for (final candidate in candidates) {
      if (candidate == null || candidate.trim().isEmpty) continue;
      final mapped = _mapLegacyType(candidate);
      if (mapped != null && mapped.isNotEmpty) return mapped;
    }

    return '';
  }

  /// Returns true when the notification is a password-reset OTP (do not skip OTP entry).
  static bool isForgotPasswordOtp(String event, Map<String, dynamic> data) {
    if (event == 'forgot_password_otp') return true;
    final type = _normalizeTypeKey(
      data['type']?.toString() ??
          data['notification_type']?.toString() ??
          data['notification']?.toString() ??
          '',
    );
    return type == 'passwordresetotpnotification';
  }

  /// Returns true when the notification should not trigger navigation (OTP, etc.).
  static bool isNonNavigable(String event, Map<String, dynamic> data) {
    if (_nonNavigableEvents.contains(event)) return true;

    final screen = data['screen']?.toString().trim().toLowerCase();
    if (screen == NotificationEvents.screenVerifyDelivery) return true;

    final type = _normalizeTypeKey(
      data['type']?.toString() ??
          data['notification_type']?.toString() ??
          data['notification']?.toString() ??
          '',
    );
    return _nonNavigableLegacyTypes.contains(type);
  }

  static String? _mapLegacyType(String raw) {
    final key = _normalizeTypeKey(raw);
    if (key.isEmpty) return null;
    return _legacyTypeToEvent[key];
  }

  static String _normalizeTypeKey(String raw) {
    return raw
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '')
        .toLowerCase();
  }

  static const Set<String> _nonNavigableEvents = {
    'registration_otp',
    'login_otp',
    'forgot_password_otp',
    'phone_verification',
    NotificationEvents.otpRequired,
  };

  static const Set<String> _nonNavigableLegacyTypes = {
    'phoneverificationnotification',
    'passwordresetotpnotification',
    'registrationnotification',
    'otprequired',
    'otp_required',
  };

  /// Legacy Laravel notification class → normalized event.
  static const Map<String, String> _legacyTypeToEvent = {
    // Rider job lifecycle
    'newordernotification': NotificationEvents.newOrder,
    'availableordernotification': NotificationEvents.nearbyJobAvailable,
    'orderacceptednotification': NotificationEvents.jobAssigned,
    'orderpickedupnotification': NotificationEvents.pickupReminder,
    'orderdeliverednotification': 'delivery_completed',
    'ordercancellednotification': NotificationEvents.customerCancelled,
    'orderstatuschanged': NotificationEvents.orderStatusChanged,
    'orderratednotification': 'order_rated',
    'serviceratednotification': 'service_rated',
    'pickup_assigned': NotificationEvents.orderStatusChanged,
    'en_route_pickup': NotificationEvents.orderStatusChanged,
    'at_pickup': NotificationEvents.orderStatusChanged,
    'en_route_dropoff': NotificationEvents.orderStatusChanged,
    'at_dropoff': NotificationEvents.orderStatusChanged,
    'delivered': NotificationEvents.orderStatusChanged,

    // Wallet (snake_case legacy variants)
    'walletlow': NotificationEvents.walletLow,
    'insufficientbalance': NotificationEvents.insufficientBalance,
    'commissiondeducted': NotificationEvents.commissionDeducted,
    'earningcredited': NotificationEvents.earningCredited,
    'settlementrequired': NotificationEvents.settlementRequired,

    // Marketing
    'pricedropnotification': 'price_drop',

    // Handyman / service
    'newservicerequestnotification': NotificationEvents.newOrder,
    'servicerequestnotification': NotificationEvents.newOrder,
  };
}
