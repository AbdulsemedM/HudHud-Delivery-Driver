import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/notifications/notification_navigation_extra.dart';

void main() {
  group('NotificationNavigationExtra', () {
    test('builds wallet_low banner from payload', () {
      final extra = NotificationNavigationExtra.fromData({
        'event': 'wallet_low',
        'balance': '42.50',
        'currency': 'ETB',
      });

      expect(extra.showTopUpHint, isTrue);
      expect(extra.bannerMessage, contains('42.50'));
      expect(extra.bannerMessage, contains('ETB'));
    });

    test('maps USD payload currency to ETB', () {
      final extra = NotificationNavigationExtra.fromData({
        'event': 'wallet_low',
        'balance': '42.50',
        'currency': 'USD',
      });

      expect(extra.bannerMessage, contains('ETB'));
      expect(extra.bannerMessage, isNot(contains('USD')));
    });

    test('builds commission_deducted banner from payload', () {
      final extra = NotificationNavigationExtra.fromData({
        'event': 'commission_deducted',
        'fee': '200.00',
        'order_number': 'PKG-123',
        'rider_keeps': '800.00',
        'currency': 'ETB',
      });

      expect(extra.bannerMessage, contains('PKG-123'));
      expect(extra.bannerMessage, contains('200.00'));
    });
  });
}
