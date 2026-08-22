import 'dart:math';

/// Builds idempotency keys for payment and wallet mutations.
class PaymentIdempotency {
  PaymentIdempotency._();

  static final Random _random = Random.secure();

  static String createUuid() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static String paymentAttemptKey({
    required String type,
    required int entityId,
    String? existingKey,
  }) {
    if (existingKey != null && existingKey.isNotEmpty) return existingKey;
    return '$type-$entityId-attempt-${createUuid()}';
  }

  static String qpayDeliveryScope(int deliveryId) =>
      'qpay-delivery-$deliveryId';

  static String qpayDeliveryKey({
    required int deliveryId,
    String? existingKey,
  }) {
    if (existingKey != null && existingKey.isNotEmpty) return existingKey;
    return 'qpay-delivery-$deliveryId-${createUuid()}';
  }

  static String walletTopUpKey({String? existingKey}) {
    if (existingKey != null && existingKey.isNotEmpty) return existingKey;
    return 'wallet-topup-${createUuid()}';
  }

  static String walletTransferKey({String? existingKey}) {
    if (existingKey != null && existingKey.isNotEmpty) return existingKey;
    return 'wallet-transfer-${createUuid()}';
  }
}
