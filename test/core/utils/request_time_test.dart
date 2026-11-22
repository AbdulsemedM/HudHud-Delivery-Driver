import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/models/driver_food_order.dart';
import 'package:hudhud_delivery_driver/core/utils/request_time.dart';

void main() {
  group('RequestTime.of', () {
    test('prefers requested_at over created_at', () {
      final at = RequestTime.of({
        'requested_at': '2026-11-19T10:00:00Z',
        'created_at': '2026-11-19T09:00:00Z',
      });
      expect(at, DateTime.utc(2026, 11, 19, 10).toLocal());
    });

    test('falls back to created_at, then placed_at', () {
      expect(
        RequestTime.of({'created_at': '2026-11-19T09:00:00Z'}),
        DateTime.utc(2026, 11, 19, 9).toLocal(),
      );
      expect(
        RequestTime.of({'placed_at': '2026-11-19T08:00:00Z'}),
        DateTime.utc(2026, 11, 19, 8).toLocal(),
      );
    });

    test('null when absent or unparseable', () {
      expect(RequestTime.of(null), isNull);
      expect(RequestTime.of({'id': 1}), isNull);
      expect(RequestTime.of({'created_at': 'not a date'}), isNull);
      expect(RequestTime.of({'created_at': null}), isNull);
    });
  });

  group('RequestTime.minutesAgo', () {
    final now = DateTime(2026, 11, 19, 14, 30);

    test('whole minutes', () {
      expect(RequestTime.minutesAgo(DateTime(2026, 11, 19, 14, 25), now), 5);
      expect(RequestTime.minutesAgo(DateTime(2026, 11, 19, 12, 30), now), 120);
    });

    test('future time (clock skew) is 0, not negative', () {
      expect(RequestTime.minutesAgo(DateTime(2026, 11, 19, 14, 40), now), 0);
    });
  });

  group('RequestTime.daysAgo', () {
    final now = DateTime(2026, 11, 19, 0, 10);

    test('calendar days, not 24 h blocks', () {
      expect(RequestTime.daysAgo(DateTime(2026, 11, 19, 0, 1), now), 0);
      expect(RequestTime.daysAgo(DateTime(2026, 11, 18, 23, 59), now), 1);
      expect(RequestTime.daysAgo(DateTime(2026, 11, 16, 12), now), 3);
    });

    test('future day is 0', () {
      expect(RequestTime.daysAgo(DateTime(2026, 11, 20, 1), now), 0);
    });
  });

  test('DriverFoodOrder reads created_at and keeps it through withStatus', () {
    final order = DriverFoodOrder.fromJson({
      'id': 7,
      'status': 'ready_for_pickup',
      'created_at': '2026-11-19T09:00:00Z',
    })!;
    expect(order.requestedAt, DateTime.utc(2026, 11, 19, 9).toLocal());
    expect(
      order.withStatus('in_transit').requestedAt,
      order.requestedAt,
    );
    expect(DriverFoodOrder.fromJson({'id': 8})!.requestedAt, isNull);
  });
}
