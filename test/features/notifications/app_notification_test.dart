import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/features/notifications/data/models/app_notification.dart';

void main() {
  group('AppNotification.parseData', () {
    test('accepts an object', () {
      expect(AppNotification.parseData({'event': 'order_status_changed'}), {
        'event': 'order_status_changed',
      });
    });

    test('accepts an array', () {
      expect(AppNotification.parseData(['a', 'b']), {
        'items': ['a', 'b'],
      });
    });

    test('accepts a valid JSON string', () {
      expect(
        AppNotification.parseData('{"delivery_id": 86}'),
        {'delivery_id': 86},
      );
    });

    test('accepts malformed JSON as empty map', () {
      expect(AppNotification.parseData('{not-json'), isEmpty);
    });

    test('accepts null as empty map', () {
      expect(AppNotification.parseData(null), isEmpty);
    });
  });

  group('NotificationsPage.fromResponse', () {
    test('parses list, meta, and item fields', () {
      final page = NotificationsPage.fromResponse({
        'data': [
          {
            'id': 'uuid-1',
            'type': 'OrderStatusChanged',
            'type_class': r'App\Notifications\OrderStatusChanged',
            'title': 'Order delivered',
            'message': 'Your order has been delivered.',
            'data': {},
            'read_at': null,
            'is_read': false,
            'created_at': '2026-08-17T10:42:46.000000Z',
          },
        ],
        'meta': {
          'unread_count': 3,
          'total': 15,
          'per_page': 20,
          'current_page': 1,
          'last_page': 1,
        },
      });

      expect(page.items, hasLength(1));
      expect(page.items.first.title, 'Order delivered');
      expect(page.items.first.isRead, isFalse);
      expect(page.unreadCount, 3);
      expect(page.total, 15);
      expect(page.hasMore, isFalse);
    });

    test('does not treat a 503-shaped empty body as a special success', () {
      final page = NotificationsPage.fromResponse({
        'success': false,
        'message': 'Unable to retrieve notifications at this time.',
        'data': [],
        'meta': {
          'unread_count': 0,
          'total': 0,
          'per_page': 20,
          'current_page': 1,
          'last_page': 1,
        },
      });

      expect(page.items, isEmpty);
      expect(page.unreadCount, 0);
    });
  });
}
