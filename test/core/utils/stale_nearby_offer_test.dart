import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/models/available_driver_requests.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';
import 'package:hudhud_delivery_driver/core/utils/stale_nearby_offer.dart';

void main() {
  group('StaleNearbyOffer', () {
    test('matches DRIVER_OFFER_NOT_ACTIVE 409', () {
      final error = ConflictException(
        'This nearby offer has expired or is reserved for another driver.',
        code: 'DRIVER_OFFER_NOT_ACTIVE',
      );
      expect(StaleNearbyOffer.matches(error), isTrue);
      expect(StaleNearbyOffer.matches(ConflictException(
        'Complete your active job',
        code: 'DRIVER_ACTIVE_JOB_CONFLICT',
      )), isFalse);
    });

    test('matches GoneException and generic non-active-job 409', () {
      expect(StaleNearbyOffer.matches(GoneException('Gone')), isTrue);
      expect(
        StaleNearbyOffer.matches(ConflictException('This job is no longer available.')),
        isTrue,
      );
    });
  });

  group('StaleNearbyOffer.isDeliveryNoLongerAvailable', () {
    test('unpaid prepaid parcel refusal (DRIVER_OFFER_NOT_ACTIVE)', () {
      final error = ConflictException(
        'This nearby offer has expired or is reserved for another driver. Refresh available requests.',
        code: 'DRIVER_OFFER_NOT_ACTIVE',
        details: {'success': false, 'code': 'DRIVER_OFFER_NOT_ACTIVE'},
      );
      expect(StaleNearbyOffer.isDeliveryNoLongerAvailable(error), isTrue);
    });

    test('taken or cancelled parcel', () {
      for (final reason in ['unavailable', 'cancelled']) {
        final error = ConflictException(
          'This delivery is no longer available.',
          details: {'success': false, 'reason': reason},
        );
        expect(StaleNearbyOffer.isDeliveryNoLongerAvailable(error), isTrue);
      }
      expect(
        StaleNearbyOffer.isDeliveryNoLongerAvailable(GoneException('Gone')),
        isTrue,
      );
    });

    test('wallet capacity and active-job 409s keep their own message', () {
      final capacity = ConflictException(
        'This delivery requires more available wallet capacity than the driver currently has.',
        code: 'INSUFFICIENT_SETTLEMENT_CAPACITY',
        details: {'code': 'INSUFFICIENT_SETTLEMENT_CAPACITY', 'deficit': 50},
      );
      final activeJob = ConflictException(
        'Complete your active job',
        code: 'DRIVER_ACTIVE_JOB_CONFLICT',
      );
      expect(StaleNearbyOffer.isDeliveryNoLongerAvailable(capacity), isFalse);
      expect(StaleNearbyOffer.isDeliveryNoLongerAvailable(activeJob), isFalse);
      expect(
        StaleNearbyOffer.isDeliveryNoLongerAvailable(ForbiddenException('x')),
        isFalse,
      );
    });
  });

  group('AvailableDriverRequests', () {
    test('parses deliveries and dispatch message', () {
      final parsed = AvailableDriverRequests.fromJson({
        'success': true,
        'rides': [],
        'deliveries': [
          {'id': 1, 'offer_expires_at': '2026-08-19T10:31:00.000000Z'},
        ],
        'dispatch': {
          'strategy': 'proximity_wave_v1',
          'message':
              'Requests are offered nearest-first. Keep live location enabled to remain eligible for nearby offers.',
        },
      });

      expect(parsed.deliveries, hasLength(1));
      expect(parsed.deliveries.first['id'], 1);
      expect(parsed.dispatch?.strategy, 'proximity_wave_v1');
      expect(parsed.dispatch?.message, contains('nearest-first'));
    });
  });

  group('DriverAvailability', () {
    test('reads is_available from driver_profile', () {
      expect(
        DriverAvailability.fromProfile({
          'driver_profile': {'is_available': true},
        }),
        isTrue,
      );
      expect(
        DriverAvailability.fromProfile({'is_available': false}),
        isFalse,
      );
    });
  });
}
