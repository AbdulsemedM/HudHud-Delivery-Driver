import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/models/location_update_result.dart';
import 'package:hudhud_delivery_driver/core/utils/logger.dart';

void main() {
  group('LocationUpdatePayload', () {
    test('clamps values and includes recorded_at and source', () {
      final body = LocationUpdatePayload.build(
        latitude: 120,
        longitude: -200,
        accuracy: 9000,
        speed: -4,
        heading: 400,
        altitude: 20000,
        recordedAt: '2026-08-17T08:40:00Z',
        source: 'fused',
      );

      expect(body['latitude'], 90);
      expect(body['longitude'], -180);
      expect(body['accuracy'], 5000);
      expect(body['speed'], 0);
      expect(body['heading'], 360);
      expect(body['altitude'], 10000);
      expect(body['recorded_at'], '2026-08-17T08:40:00Z');
      expect(body['source'], 'fused');
    });

    test('omits invalid heading', () {
      final body = LocationUpdatePayload.build(
        latitude: 9,
        longitude: 38,
        heading: -1,
      );
      expect(body.containsKey('heading'), isFalse);
    });
  });

  group('LocationUpdateResult', () {
    test('parses a stale 409 body instead of treating it as a job conflict', () {
      final result = LocationUpdateResult.tryFromStaleConflict({
        'message': 'Stale location ignored.',
        'stale': true,
        'location': {
          'latitude': 9.0321,
          'longitude': 38.7468,
        },
      });

      expect(result, isNotNull);
      expect(result!.stale, isTrue);
      expect(result.message, 'Stale location ignored.');
      expect(result.location?['latitude'], 9.0321);
    });

    test('returns null for a non-stale 409 job conflict', () {
      expect(
        LocationUpdateResult.tryFromStaleConflict({
          'message': 'This job is no longer available.',
        }),
        isNull,
      );
    });
  });

  group('AppLogger.redactSensitive', () {
    test('redacts otp keys in nested maps', () {
      final redacted = AppLogger.redactSensitive({
        'otp': '4821',
        'delivery_id': '123',
        'nested': {'otp': '9999'},
      }) as Map;

      expect(redacted['otp'], '[REDACTED]');
      expect(redacted['delivery_id'], '123');
      expect((redacted['nested'] as Map)['otp'], '[REDACTED]');
    });
  });

  group('AppLogger.truncate', () {
    test('leaves short strings unchanged', () {
      expect(AppLogger.truncate('ok'), 'ok');
    });

    test('clips long strings and reports omitted length', () {
      final clipped = AppLogger.truncate('abcdefghij', maxChars: 4);
      expect(clipped.startsWith('abcd'), isTrue);
      expect(clipped, contains('truncated 6 chars'));
    });
  });
}
