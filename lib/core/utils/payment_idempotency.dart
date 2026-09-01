import 'dart:math';

import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';

/// Builds idempotency keys for payment and wallet mutations.
class PaymentIdempotency {
  PaymentIdempotency._();

  static const walletTopUpScope = 'wallet-topup';
  static const walletTopUpFingerprintScope = 'wallet-topup-fp';

  static String deliveryQpayScope(int deliveryId) =>
      'delivery-qpay-$deliveryId';

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

  static String walletTopUpKey({String? existingKey}) {
    if (existingKey != null && existingKey.isNotEmpty) return existingKey;
    return 'wallet-topup-${createUuid()}';
  }

  static String deliveryQpayKey({
    required int deliveryId,
    String? existingKey,
  }) {
    if (existingKey != null && existingKey.isNotEmpty) return existingKey;
    return 'delivery-qpay-$deliveryId-${createUuid()}';
  }

  static String resolveDeliveryQpayKey({
    required int deliveryId,
    String? storedKey,
  }) {
    if (storedKey != null && storedKey.isNotEmpty) return storedKey;
    return deliveryQpayKey(deliveryId: deliveryId);
  }

  static String walletTopUpFingerprint({
    required String methodCode,
    required double amount,
    required String currency,
    String phone = '',
    String cashNote = '',
  }) {
    return '${methodCode.trim().toLowerCase()}|'
        '${amount.toStringAsFixed(2)}|'
        '${currency.trim().toUpperCase()}|'
        '${phone.trim()}|'
        '${cashNote.trim()}';
  }

  /// Reuses [storedKey] only when the payment intent fingerprint still matches.
  static String resolveWalletTopUpKey({
    required String fingerprint,
    String? storedKey,
    String? storedFingerprint,
  }) {
    if (storedKey != null &&
        storedKey.isNotEmpty &&
        storedFingerprint == fingerprint) {
      return storedKey;
    }
    return walletTopUpKey();
  }

  static bool isIdempotencyConflict(AppException error) {
    if (error is ConflictException) return true;
    final code = error.code?.toUpperCase() ?? '';
    if (code.contains('IDEMPOTENCY')) return true;
    final message = error.message.toLowerCase();
    return message.contains('idempotency') &&
        (message.contains('already used') || message.contains('different'));
  }

  static String walletTransferKey({String? existingKey}) {
    if (existingKey != null && existingKey.isNotEmpty) return existingKey;
    return 'wallet-transfer-${createUuid()}';
  }
}
