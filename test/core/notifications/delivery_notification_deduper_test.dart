import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/notifications/delivery_notification_deduper.dart';

void main() {
  group('DeliveryNotificationDeduper', () {
    test('ignores duplicate delivery_id + status', () {
      final deduper = DeliveryNotificationDeduper();
      expect(
        deduper.shouldApply(deliveryId: 12, status: 'at_pickup'),
        isTrue,
      );
      expect(
        deduper.shouldApply(deliveryId: 12, status: 'at_pickup'),
        isFalse,
      );
    });

    test('ignores an older push after a newer status', () {
      final deduper = DeliveryNotificationDeduper();
      expect(
        deduper.shouldApply(deliveryId: 12, status: 'en_route_dropoff'),
        isTrue,
      );
      expect(
        deduper.shouldApply(deliveryId: 12, status: 'at_pickup'),
        isFalse,
      );
    });

    test('API status is authoritative over an older cached push', () {
      final deduper = DeliveryNotificationDeduper();
      expect(
        deduper.shouldApply(deliveryId: 12, status: 'pickup_assigned'),
        isTrue,
      );
      deduper.recordFromApi(12, 'in_transit');
      expect(
        deduper.shouldApply(deliveryId: 12, status: 'en_route_pickup'),
        isFalse,
      );
      expect(
        deduper.shouldApply(deliveryId: 12, status: 'at_dropoff'),
        isTrue,
      );
    });

    test('allows the same status on a different delivery', () {
      final deduper = DeliveryNotificationDeduper();
      expect(
        deduper.shouldApply(deliveryId: 1, status: 'delivered'),
        isTrue,
      );
      expect(
        deduper.shouldApply(deliveryId: 2, status: 'delivered'),
        isTrue,
      );
    });
  });
}
