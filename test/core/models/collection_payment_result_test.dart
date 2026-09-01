import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/models/collection_payment_result.dart';

void main() {
  group('CollectionPaymentResult QPay', () {
    test('parses driver collect-payment QR response', () {
      final result = CollectionPaymentResult.fromJson({
        'success': true,
        'message': 'QPay QR is ready.',
        'next_action': 'show_qr_code',
        'payment': {
          'id': 901,
          'status': 'processing',
          'method': 'qpay',
          'amount': 122.76,
          'currency': 'ETB',
          'qr_code': 'qpay-token-value',
          'qr_id': 'ref-1',
          'expires_at': '2026-08-22T10:15:00.000000Z',
        },
      });

      expect(result.shouldShowQpayQr, isTrue);
      expect(result.paymentId, 901);
      expect(result.qrCode, 'qpay-token-value');
      expect(result.isPending, isTrue);
      expect(result.isSettled, isFalse);
    });

    test('complete_delivery with settled state is success', () {
      final result = CollectionPaymentResult.fromJson({
        'success': true,
        'next_action': 'complete_delivery',
        'settlement': {'state': 'settled'},
      });

      expect(result.isSettled, isTrue);
      expect(result.isCollectionComplete, isTrue);
    });

    test('complete_delivery without settled settlement is not success', () {
      final result = CollectionPaymentResult.fromJson({
        'success': true,
        'next_action': 'complete_delivery',
        'settlement': {'state': 'pending'},
      });

      expect(result.isSettled, isFalse);
      expect(result.isCollectionComplete, isFalse);
    });

    test('select_collection_method is terminal failure', () {
      final result = CollectionPaymentResult.fromJson({
        'success': false,
        'next_action': 'select_collection_method',
        'qpay_status': 'EXPIRED',
      });

      expect(result.isTerminalFailure, isTrue);
    });

    test('approve_ussd is a pollable USSD action, not a QPay QR', () {
      final result = CollectionPaymentResult.fromJson({
        'success': true,
        'next_action': 'approve_ussd',
        'message': 'Approve the USSD prompt on the recipient phone.',
        'payment': {'id': 132, 'status': 'pending'},
      });

      expect(result.isUssdAction, isTrue);
      expect(result.shouldPoll, isTrue);
      expect(result.shouldShowQpayQr, isFalse);
    });
  });
}
