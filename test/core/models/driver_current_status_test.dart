import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/models/active_job.dart';
import 'package:hudhud_delivery_driver/core/models/driver_current_status.dart';
import 'package:hudhud_delivery_driver/core/models/trip_progress.dart';

void main() {
  // The shape production returned for delivery 237 on 2026-11-18: the job
  // sits under active_service.data, the trip beside it.
  Map<String, dynamic> prodShape() => {
        'has_active_service': true,
        'active_service': {
          'type': 'delivery',
          'data': {
            'id': 237,
            'status': 'picked_up',
            'assigned_at': '2026-11-17T22:33:22.000000Z',
            'pickup_completed_at': '2026-11-17T22:33:53.000000Z',
          },
          'service_type': 'same_day',
          'navigation': null,
          'trip': {
            'distance_km': 12.45,
            'duration_minutes': 9,
            'points': 0,
            'rejected': 44,
            'source': 'estimate',
            'started_at': '2026-11-17T22:33:52+00:00',
          },
        },
        'next_action': null,
        'driver_status': 'busy',
        'is_available': false,
      };

  test('reads the delivery id from active_service.data', () {
    final status = DriverCurrentStatus.fromJson(prodShape());
    expect(status.activeJob?.type, ActiveJobType.delivery);
    expect(status.activeJob?.id, 237);
    expect(status.deliveryId, 237);
    expect(status.activeJob?.status, 'picked_up');
  });

  test('serves the trip, with its start time, for that delivery', () {
    final trip = DriverCurrentStatus.fromJson(prodShape()).trip;
    expect(trip, isNotNull);
    expect(trip!.source, TripProgress.sourceEstimate);
    expect(trip.startedAt, isNotNull);
    expect(trip.points, 0);
  });

  test('a typed job without any id does not hide a delivery id elsewhere', () {
    final status = DriverCurrentStatus.fromJson({
      'active_service': {'type': 'delivery'},
      'delivery_id': 41,
    });
    expect(status.deliveryId, 41);
  });

  test('flat active_job is unchanged', () {
    final status = DriverCurrentStatus.fromJson({
      'active_job': {'type': 'delivery', 'id': 95},
    });
    expect(status.deliveryId, 95);
  });
}
