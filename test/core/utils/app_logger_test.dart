import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/utils/logger.dart';

void main() {
  group('AppLogger QPay response logging', () {
    test('redactSensitive masks qr_code by default', () {
      final redacted = AppLogger.redactSensitive({
        'success': true,
        'payment': {
          'qr_code': 'provider-qr-value',
        },
      });

      expect(
        (redacted['payment'] as Map)['qr_code'],
        '[REDACTED]',
      );
    });

    test('truncate limits long payloads unless disabled', () {
      final long = 'x' * 2500;
      expect(AppLogger.truncate(long).contains('[truncated'), isTrue);
      expect(AppLogger.truncate(long, maxChars: 5000), long);
    });
  });
}
