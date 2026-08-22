import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/models/payment_status_result.dart';

void main() {
  group('PaymentStatusResult', () {
    test('terminal failure stops polling semantics', () {
      final failed = PaymentStatusResult.fromJson({
        'data': {'payment': {'status': 'failed'}},
      });
      expect(failed.isTerminalFailure, isTrue);
      expect(failed.isPending, isFalse);

      final pending = PaymentStatusResult.fromJson({
        'data': {'payment': {'status': 'processing'}},
      });
      expect(pending.isPending, isTrue);
      expect(pending.isTerminalFailure, isFalse);
    });

    test('qpay EXPIRED is terminal even if payment is pending', () {
      final expired = PaymentStatusResult.fromJson({
        'data': {
          'payment': {'id': 901, 'status': 'pending'},
          'status': 'pending',
          'qpay_status': 'EXPIRED',
        },
      });
      expect(expired.isExpired, isTrue);
      expect(expired.isTerminalFailure, isTrue);
      expect(expired.isPending, isFalse);
    });

    test('qpay COMPLETED follows HudHud payment status', () {
      final completed = PaymentStatusResult.fromJson({
        'data': {
          'payment': {'id': 901, 'status': 'completed'},
          'status': 'completed',
          'qpay_status': 'COMPLETED',
        },
      });
      expect(completed.isCompleted, isTrue);
      expect(completed.qpayStatus, 'COMPLETED');
    });
  });
}
