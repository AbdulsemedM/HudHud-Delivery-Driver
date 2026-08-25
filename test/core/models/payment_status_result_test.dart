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

    test('next_action complete_delivery is settled', () {
      final settled = PaymentStatusResult.fromJson({
        'success': true,
        'next_action': 'complete_delivery',
        'data': {
          'payment': {'id': 901, 'status': 'processing'},
        },
      });
      expect(settled.isCompleted, isTrue);
    });

    test('completed without settlement still settles non-wallet payments', () {
      final completed = PaymentStatusResult.fromJson({
        'success': true,
        'data': {
          'status': 'completed',
        },
      });
      expect(completed.hasWalletSettlement, isFalse);
      expect(completed.isCompleted, isTrue);
    });

    test('completed with awaiting settlement is not credited', () {
      final pending = PaymentStatusResult.fromJson({
        'success': true,
        'data': {
          'status': 'completed',
          'wallet_topup_settlement': 'awaiting_provider_amount',
        },
      });
      expect(pending.isAwaitingProvider, isTrue);
      expect(pending.isCompleted, isFalse);
      expect(pending.isPending, isTrue);
    });

    test('credited and already_credited settle the wallet', () {
      final credited = PaymentStatusResult.fromJson({
        'success': true,
        'data': {
          'status': 'completed',
          'wallet_topup_settlement': 'credited',
        },
      });
      expect(credited.isWalletSettled, isTrue);
      expect(credited.isCompleted, isTrue);
      expect(credited.isPending, isFalse);

      final replay = PaymentStatusResult.fromJson({
        'success': true,
        'data': {
          'status': 'completed',
          'wallet_topup_settlement': 'already_credited',
        },
      });
      expect(replay.isWalletSettled, isTrue);
      expect(replay.isCompleted, isTrue);
    });

    test('EBIRR_STATUS_RETRY_REQUIRED stays pending, not an error', () {
      final retry = PaymentStatusResult.fromJson({
        'success': false,
        'code': 'EBIRR_STATUS_RETRY_REQUIRED',
        'retryable': true,
        'data': {
          'status': 'pending',
          'wallet_topup_settlement': 'awaiting_provider_confirmation',
        },
      });
      expect(retry.isEbirrRetryRequired, isTrue);
      expect(retry.isAwaitingProvider, isTrue);
      expect(retry.isPending, isTrue);
      expect(retry.isTerminalFailure, isFalse);
      expect(retry.isCompleted, isFalse);
    });
  });
}
