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
  });
}
