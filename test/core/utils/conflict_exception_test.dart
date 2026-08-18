import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';

void main() {
  group('ConflictException', () {
    test('detects DRIVER_ACTIVE_JOB_CONFLICT and keeps the offer', () {
      final error = ConflictException(
        'Complete or cancel your active job before accepting another request.',
        code: 'DRIVER_ACTIVE_JOB_CONFLICT',
        details: {
          'success': false,
          'code': 'DRIVER_ACTIVE_JOB_CONFLICT',
          'message':
              'Complete or cancel your active job before accepting another request.',
          'active_job': {
            'type': 'delivery',
            'id': 95,
            'status': 'en_route_dropoff',
          },
        },
      );

      expect(error.isActiveJobConflict, isTrue);
      expect(error.isUnavailable, isFalse);
      expect(error.activeJob?.id, 95);
      expect(error.activeJob?.type.name, 'delivery');
    });

    test('detects reason unavailable so the card can be removed', () {
      final error = ConflictException(
        'This delivery is no longer available.',
        details: {
          'success': false,
          'message': 'This delivery is no longer available.',
          'reason': 'unavailable',
        },
      );

      expect(error.isActiveJobConflict, isFalse);
      expect(error.isUnavailable, isTrue);
      expect(error.activeJob, isNull);
    });

    test('reads conflict code from details when exception code is 409', () {
      final error = ConflictException(
        'Complete or cancel your active job before accepting another request.',
        code: '409',
        details: {
          'code': 'DRIVER_ACTIVE_JOB_CONFLICT',
          'active_job': {'type': 'ride', 'id': 3},
        },
      );

      expect(error.isActiveJobConflict, isTrue);
      expect(error.isUnavailable, isFalse);
      expect(error.activeJob?.id, 3);
    });
  });
}
