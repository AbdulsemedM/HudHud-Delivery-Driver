import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';
import 'package:hudhud_delivery_driver/core/utils/payment_idempotency.dart';

void main() {
  group('PaymentIdempotency wallet top-up', () {
    test('reuses key only when fingerprint matches', () {
      const fp = 'ebirr_coop|100.00|ETB|2519|';
      final reused = PaymentIdempotency.resolveWalletTopUpKey(
        fingerprint: fp,
        storedKey: 'wallet-topup-same',
        storedFingerprint: fp,
      );
      expect(reused, 'wallet-topup-same');

      final rotated = PaymentIdempotency.resolveWalletTopUpKey(
        fingerprint: 'ebirr_coop|200.00|ETB|2519|',
        storedKey: 'wallet-topup-same',
        storedFingerprint: fp,
      );
      expect(rotated, isNot('wallet-topup-same'));
      expect(rotated, startsWith('wallet-topup-'));
    });

    test('detects idempotency conflict messages', () {
      expect(
        PaymentIdempotency.isIdempotencyConflict(
          ConflictException(
            'Idempotency key already used for a different payment request',
          ),
        ),
        isTrue,
      );
      expect(
        PaymentIdempotency.isIdempotencyConflict(
          BadRequestException('Invalid amount'),
        ),
        isFalse,
      );
    });
    test('resolveDeliveryQpayKey reuses stored key', () {
      const stored = 'delivery-qpay-165-existing';
      final key = PaymentIdempotency.resolveDeliveryQpayKey(
        deliveryId: 165,
        storedKey: stored,
      );
      expect(key, stored);
    });

    test('deliveryQpayKey uses delivery id prefix', () {
      final key = PaymentIdempotency.deliveryQpayKey(deliveryId: 165);
      expect(key, startsWith('delivery-qpay-165-'));
    });
  });

  group('WithdrawalAttemptKey', () {
    test('reuses the key for a retried cash-out, new key after reset', () {
      final attempt = WithdrawalAttemptKey();
      final first = attempt.keyFor(150, 'ETB');
      expect(first, startsWith('wallet-withdraw-'));
      expect(attempt.keyFor(150, 'ETB'), first);
      expect(attempt.keyFor(150, 'USD'), isNot(first));
      final usd = attempt.keyFor(150, 'USD');
      attempt.reset();
      expect(attempt.keyFor(150, 'USD'), isNot(usd));
    });
  });
}
