import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/models/active_job.dart';

void main() {
  group('ActiveJob.fromJson', () {
    test('parses DRIVER_ACTIVE_JOB_CONFLICT active_job', () {
      final job = ActiveJob.fromJson({
        'type': 'delivery',
        'id': 95,
        'status': 'en_route_dropoff',
        'accepted_at': '2026-08-18T10:00:00.000000Z',
        'started_at': '2026-08-18T10:04:00.000000Z',
        'tracking_number': 'HUD-123',
      });

      expect(job, isNotNull);
      expect(job!.type, ActiveJobType.delivery);
      expect(job.id, 95);
      expect(job.status, 'en_route_dropoff');
      expect(job.trackingNumber, 'HUD-123');
      expect(job.acceptedAt, isNotNull);
      expect(job.startedAt, isNotNull);
    });

    test('parses ride and order types', () {
      expect(
        ActiveJob.fromJson({'type': 'ride', 'id': 1})!.type,
        ActiveJobType.ride,
      );
      expect(
        ActiveJob.fromJson({'type': 'order', 'id': 2})!.type,
        ActiveJobType.order,
      );
    });
  });

  group('ActiveJob.fromDriverProfile', () {
    test('prefers current_ride_id', () {
      final job = ActiveJob.fromDriverProfile({
        'driver_profile': {
          'current_ride_id': 7,
          'current_delivery_id': 9,
        },
      });
      expect(job?.type, ActiveJobType.ride);
      expect(job?.id, 7);
    });

    test('uses current_delivery_id when no ride', () {
      final job = ActiveJob.fromDriverProfile({
        'driver_profile': {'current_delivery_id': '12'},
      });
      expect(job?.type, ActiveJobType.delivery);
      expect(job?.id, 12);
    });

    test('returns null when profile has no current job', () {
      expect(
        ActiveJob.fromDriverProfile({'driver_profile': {}}),
        isNull,
      );
    });
  });
}
