import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/models/payment_initiate_result.dart';

void main() {
  group('PaymentInitiateResult', () {
    test('shouldPoll for USSD next_action', () {
      final result = PaymentInitiateResult.fromJson({
        'success': true,
        'data': {
          'next_action': 'approve_ussd',
          'payment': {'id': 10, 'status': 'pending'},
        },
      });
      expect(result.shouldPoll, isTrue);
      expect(result.paymentId, 10);
    });

    test('isCompleted when status completed', () {
      final result = PaymentInitiateResult.fromJson({
        'success': true,
        'data': {
          'payment': {'id': 1, 'status': 'completed'},
        },
      });
      expect(result.isCompleted, isTrue);
      expect(result.shouldPoll, isFalse);
    });

    test('await_admin_cash_confirmation', () {
      final result = PaymentInitiateResult.fromJson({
        'success': true,
        'data': {
          'next_action': 'await_admin_cash_confirmation',
          'payment': {'id': 401, 'status': 'pending'},
        },
      });
      expect(result.awaitAdminCashConfirmation, isTrue);
    });
  });
}
