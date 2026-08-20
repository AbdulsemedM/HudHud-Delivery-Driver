import 'package:hudhud_delivery_driver/core/utils/json_parse.dart';

/// Result of POST collect-payment or GET collection-payment-status.
class CollectionPaymentResult {
  const CollectionPaymentResult({
    this.success = false,
    this.status,
    this.message,
    this.paymentReference,
    this.cashFallbackAllowed = false,
    this.nextAction,
    this.raw = const {},
  });

  final bool success;
  final String? status;
  final String? message;
  final String? paymentReference;
  final bool cashFallbackAllowed;
  final String? nextAction;
  final Map<String, dynamic> raw;

  static const statusSettled = 'settled';
  static const statusPaymentPending = 'payment_pending';
  static const statusPending = 'pending';
  static const statusFailed = 'failed';
  static const statusExpired = 'expired';

  bool get isSettled {
    final s = status?.toLowerCase();
    return s == statusSettled ||
        s == 'completed' ||
        s == 'paid' ||
        s == 'success';
  }

  bool get isPending {
    final s = status?.toLowerCase();
    return s == statusPaymentPending ||
        s == statusPending ||
        s == 'processing' ||
        s == 'initiated';
  }

  bool get isTerminalFailure {
    final s = status?.toLowerCase();
    return s == statusFailed ||
        s == statusExpired ||
        s == 'cancelled' ||
        s == 'canceled';
  }

  bool get shouldPoll => isPending && !isSettled && !isTerminalFailure;

  factory CollectionPaymentResult.fromJson(dynamic raw) {
    if (raw is! Map) return const CollectionPaymentResult();
    final map = Map<String, dynamic>.from(raw);
    final data = map['data'] is Map
        ? Map<String, dynamic>.from(map['data'] as Map)
        : map;
    final payment = data['payment'] is Map
        ? Map<String, dynamic>.from(data['payment'] as Map)
        : <String, dynamic>{};
    final collection = data['collection'] is Map
        ? Map<String, dynamic>.from(data['collection'] as Map)
        : <String, dynamic>{};

    final status = collection['status']?.toString() ??
        payment['status']?.toString() ??
        data['status']?.toString() ??
        map['status']?.toString();

    final reference = collection['payment_reference']?.toString() ??
        data['payment_reference']?.toString() ??
        payment['reference']?.toString() ??
        data['reference']?.toString() ??
        payment['transaction_id']?.toString();

    return CollectionPaymentResult(
      success: JsonParse.toBool(map['success']) ||
          JsonParse.toBool(data['success']) ||
          status != null,
      status: status,
      message: map['message']?.toString() ?? data['message']?.toString(),
      paymentReference: reference,
      cashFallbackAllowed: JsonParse.toBool(data['cash_fallback_allowed']) ||
          JsonParse.toBool(collection['cash_fallback_allowed']) ||
          JsonParse.toBool(map['cash_fallback_allowed']),
      nextAction: data['next_action']?.toString() ??
          map['next_action']?.toString(),
      raw: map,
    );
  }
}
