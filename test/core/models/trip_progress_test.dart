import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/models/driver_current_status.dart';
import 'package:hudhud_delivery_driver/core/models/trip_progress.dart';

/// The driver app used to show the ESTIMATE as the trip, and post that
/// estimate back as `actual_distance` / `actual_duration` on completion, so
/// the "actual" values on every completed delivery were the quote. The backend
/// now measures the trip from the GPS trail the app already sends and serves
/// it on `current-status`. These tests cover reading it.
void main() {
  group('TripProgress.fromJson', () {
    test('reads a measured trip', () {
      final trip = TripProgress.fromJson({
        'distance_km': 2.22,
        'duration_minutes': 20,
        'source': 'gps',
        'started_at': '2026-11-17T10:00:00Z',
        'points': 5,
      });

      expect(trip, isNotNull);
      expect(trip!.distanceKm, closeTo(2.22, 0.001));
      expect(trip.durationMinutes, 20);
      expect(trip.isMeasured, isTrue);
      expect(trip.points, 5);
      expect(trip.startedAt, isNotNull);
    });

    test('an estimate is not reported as measured', () {
      final trip = TripProgress.fromJson({
        'distance_km': 6.98,
        'duration_minutes': 15,
        'source': 'estimate',
      });

      expect(trip!.isMeasured, isFalse);
    });

    /// The app ships ahead of the API often enough that this matters: an older
    /// backend sends no `trip`, and the screen has to fall back rather than
    /// render a blank card.
    test('absent or unusable payloads give null', () {
      expect(TripProgress.fromJson(null), isNull);
      expect(TripProgress.fromJson('nonsense'), isNull);
      expect(TripProgress.fromJson(<String, dynamic>{}), isNull);
      expect(TripProgress.fromJson({'source': 'gps'}), isNull);
    });

    test('string numbers survive, since decimals arrive quoted', () {
      final trip = TripProgress.fromJson({
        'distance_km': '2.22',
        'duration_minutes': '20',
        'source': 'gps',
      });

      expect(trip!.distanceKm, closeTo(2.22, 0.001));
      expect(trip.durationMinutes, 20);
    });
  });

  group('elapsed seconds', () {
    test('counts from the start the server gave', () {
      final trip = TripProgress.fromJson({
        'distance_km': 1.0,
        'duration_minutes': 5,
        'source': 'gps',
        'started_at': '2026-11-17T10:00:00Z',
      })!;

      final now = DateTime.parse('2026-11-17T10:07:30Z');
      expect(trip.elapsedSecondsAt(now), 450);
    });

    /// A courier's clock can sit behind the server's, which would otherwise
    /// render a negative duration.
    test('never goes negative', () {
      final trip = TripProgress.fromJson({
        'distance_km': 1.0,
        'duration_minutes': 5,
        'source': 'gps',
        'started_at': '2026-11-17T10:00:00Z',
      })!;

      expect(trip.elapsedSecondsAt(DateTime.parse('2026-11-17T09:58:00Z')), 0);
    });

    test('with no start time, falls back to the minutes the server counted',
        () {
      final trip = TripProgress.fromJson({
        'distance_km': 1.0,
        'duration_minutes': 5,
        'source': 'gps',
      })!;

      expect(trip.elapsedSecondsAt(DateTime.now()), 300);
    });
  });

  group('formatElapsed', () {
    test('reads as a clock', () {
      expect(TripProgress.formatElapsed(0), '0:00');
      expect(TripProgress.formatElapsed(9), '0:09');
      expect(TripProgress.formatElapsed(90), '1:30');
      expect(TripProgress.formatElapsed(740), '12:20');
      expect(TripProgress.formatElapsed(3909), '1:05:09');
      expect(TripProgress.formatElapsed(-5), '0:00');
    });
  });

  group('DriverCurrentStatus.trip', () {
    test('is read off the active service', () {
      final status = DriverCurrentStatus.fromJson({
        'has_active_service': true,
        'active_service': {
          'type': 'delivery',
          'data': {'id': 235, 'status': 'at_dropoff'},
          'trip': {
            'distance_km': 3.33,
            'duration_minutes': 15,
            'source': 'gps',
            'started_at': '2026-11-17T10:00:00Z',
          },
        },
      });

      expect(status.trip, isNotNull);
      expect(status.trip!.distanceKm, closeTo(3.33, 0.001));
      expect(status.trip!.isMeasured, isTrue);
    });

    test('is null on a response that does not carry one', () {
      final status = DriverCurrentStatus.fromJson({
        'has_active_service': true,
        'active_service': {
          'type': 'delivery',
          'data': {'id': 235, 'status': 'at_dropoff'},
        },
      });

      expect(status.trip, isNull);
    });
  });
}
