import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/notifications/legacy_notification_mapper.dart';
import 'package:hudhud_delivery_driver/core/notifications/notification_events.dart';

void main() {
  group('LegacyNotificationMapper', () {
    test('uses explicit event when present', () {
      expect(
        LegacyNotificationMapper.resolveEvent({'event': 'wallet_low'}),
        NotificationEvents.walletLow,
      );
    });

    test('maps NewOrderNotification legacy class name', () {
      expect(
        LegacyNotificationMapper.resolveEvent({'type': 'NewOrderNotification'}),
        NotificationEvents.newOrder,
      );
    });

    test('maps AvailableOrderNotification legacy class name', () {
      expect(
        LegacyNotificationMapper.resolveEvent(
          {'notification_type': 'AvailableOrderNotification'},
        ),
        NotificationEvents.nearbyJobAvailable,
      );
    });

    test('maps commission_deducted via legacy type alias', () {
      expect(
        LegacyNotificationMapper.resolveEvent({'type': 'CommissionDeducted'}),
        NotificationEvents.commissionDeducted,
      );
    });

    test('OTP notifications are non-navigable', () {
      expect(
        LegacyNotificationMapper.isNonNavigable(
          '',
          {'type': 'PhoneVerificationNotification'},
        ),
        isTrue,
      );
    });

    test('maps pickup_assigned type to order_status_changed', () {
      expect(
        LegacyNotificationMapper.resolveEvent({'type': 'pickup_assigned'}),
        NotificationEvents.orderStatusChanged,
      );
    });

    test('maps at_dropoff type to order_status_changed', () {
      expect(
        LegacyNotificationMapper.resolveEvent({'type': 'at_dropoff'}),
        NotificationEvents.orderStatusChanged,
      );
    });

    test('otp_required type is non-navigable', () {
      expect(
        LegacyNotificationMapper.isNonNavigable(
          NotificationEvents.otpRequired,
          {'type': 'otp_required', 'otp': '4821'},
        ),
        isTrue,
      );
    });

    test('verify_delivery screen is non-navigable', () {
      expect(
        LegacyNotificationMapper.isNonNavigable(
          '',
          {'screen': 'verify_delivery'},
        ),
        isTrue,
      );
    });
  });
}
