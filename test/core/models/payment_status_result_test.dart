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
  });
}
