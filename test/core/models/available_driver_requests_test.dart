import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/models/available_driver_requests.dart';
import 'package:hudhud_delivery_driver/core/notifications/notification_events.dart';

void main() {
  const delivery132 = {
    'id': 132,
    'tracking_number': 'PKG202608240AFB9B',
    'pickup_location': 'Fafan, Jijiga',
    'dropoff_location': 'Jijiga, Ethiopia',
    'estimated_cost': '121.86',
    'status': 'pending',
    'driver_offer': {
      'offer_type': 'delivery',
      'delivery_id': 132,
      'is_currently_offered': true,
      'can_accept': true,
      'offer_state': 'active',
      'dispatch_wave': 4,
      'search_radius_km': 20,
    },
  };

  group('AvailableDriverRequests.fromJson', () {
    test('parses deliveries nested only under data', () {
      final parsed = AvailableDriverRequests.fromJson({
        'success': true,
        'data': {
          'deliveries': [delivery132],
          'delivery_offers': [],
        },
      });

      expect(parsed.deliveries, hasLength(1));
      expect(parsed.deliveries.first['id'], 132);
      expect(DriverDeliveryOffer.canAccept(parsed.deliveries.first), isTrue);
    });

    test('prefers root deliveries when both root and data are present', () {
      final parsed = AvailableDriverRequests.fromJson({
        'success': true,
        'deliveries': [delivery132],
        'data': {
          'deliveries': [
            {'id': 999},
          ],
        },
      });

      expect(parsed.deliveries, hasLength(1));
      expect(parsed.deliveries.first['id'], 132);
    });

    test('reads dispatch from data envelope', () {
      final parsed = AvailableDriverRequests.fromJson({
        'data': {
          'deliveries': [],
          'dispatch': {
            'strategy': 'proximity_wave_v1',
            'message': 'Keep live location enabled.',
          },
        },
      });

      expect(parsed.dispatch?.strategy, 'proximity_wave_v1');
      expect(parsed.dispatch?.message, contains('live location'));
    });
  });

  group('DriverDeliveryOffer', () {
    test('uses nested can_accept when driver_offer is present', () {
      expect(DriverDeliveryOffer.canAccept(delivery132), isTrue);
      expect(
        DriverDeliveryOffer.canAccept({
          ...delivery132,
          'driver_offer': {
            ...delivery132['driver_offer'] as Map<String, dynamic>,
            'can_accept': false,
          },
        }),
        isFalse,
      );
    });

    test('falls back to COD can_accept when driver_offer is absent', () {
      expect(
        DriverDeliveryOffer.canAccept({
          'id': 1,
          'cod_acceptance': {'can_accept': false},
        }),
        isFalse,
      );
      expect(DriverDeliveryOffer.canAccept({'id': 1}), isTrue);
    });

    test('hides cards when nested can_accept is false', () {
      expect(DriverDeliveryOffer.shouldShowCard(delivery132), isTrue);
      expect(
        DriverDeliveryOffer.shouldShowCard({
          'id': 132,
          'driver_offer': {'can_accept': false},
        }),
        isFalse,
      );
      expect(
        DriverDeliveryOffer.shouldShowCard({
          'id': 1,
          'cod_acceptance': {'can_accept': false},
        }),
        isTrue,
      );
    });
  });

  group('NotificationEvents', () {
    test('treats proximity_delivery_offer as a job offer', () {
      expect(
        NotificationEvents.isJobOfferEvent(
          NotificationEvents.proximityDeliveryOffer,
        ),
        isTrue,
      );
    });
  });
}
