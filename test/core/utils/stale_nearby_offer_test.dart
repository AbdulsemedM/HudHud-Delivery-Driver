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
