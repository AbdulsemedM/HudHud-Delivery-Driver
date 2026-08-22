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

    test('parses QPay show_qr_code payload', () {
      final result = PaymentInitiateResult.fromJson({
        'success': true,
        'message': 'Scan the QR code',
        'data': {
          'next_action': 'show_qr_code',
          'qr_code': 'payload-value',
          'qr_id': 'ref-1',
          'awb': 'AWB1',
          'expires_at': '2026-08-22T10:15:00.000000Z',
          'payment': {'id': 901, 'status': 'pending'},
        },
      });
      expect(result.shouldPoll, isTrue);
      expect(result.paymentId, 901);
      expect(result.qrCode, 'payload-value');
      expect(result.qrId, 'ref-1');
      expect(result.awb, 'AWB1');
      expect(result.expiresAt, isNotNull);
    });
  });
}
