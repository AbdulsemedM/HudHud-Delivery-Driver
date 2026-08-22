import 'package:hudhud_delivery_driver/core/utils/json_parse.dart';

class PaymentStatusResult {
  const PaymentStatusResult({
    this.status,
    this.message,
    this.paymentId,
    this.qpayStatus,
    this.retryable,
    this.nextAction,
    this.raw = const {},
  });

  final String? status;
  final String? message;
  final int? paymentId;
  final String? qpayStatus;
  final bool? retryable;
  final String? nextAction;
  final Map<String, dynamic> raw;

  String? get _qpayNormalized => qpayStatus?.toUpperCase();

  bool get isExpired =>
      status == 'expired' || _qpayNormalized == 'EXPIRED';

  bool get isPending {
    if (isCompleted || isTerminalFailure) return false;
    return status == 'pending' ||
        status == 'processing' ||
        _qpayNormalized == 'PENDING';
  }

  bool get isCompleted =>
      status == 'completed' ||
      status == 'paid' ||
      status == 'settled' ||
      nextAction == 'complete_delivery';

  bool get isTerminalFailure =>
      status == 'failed' ||
      status == 'cancelled' ||
      status == 'refunded' ||
      status == 'partially_refunded' ||
      status == 'expired' ||
      _qpayNormalized == 'FAILED' ||
      _qpayNormalized == 'EXPIRED';

  factory PaymentStatusResult.fromJson(dynamic raw) {
    if (raw is! Map) return const PaymentStatusResult();
    final map = Map<String, dynamic>.from(raw);
    final data = map['data'] is Map
        ? Map<String, dynamic>.from(map['data'] as Map)
        : map;
    final payment = data['payment'] is Map
        ? Map<String, dynamic>.from(data['payment'] as Map)
        : data;

    return PaymentStatusResult(
      status: payment['status']?.toString() ?? data['status']?.toString(),
      message: map['message']?.toString() ?? data['message']?.toString(),
      paymentId: JsonParse.toInt(payment['id']) ?? JsonParse.toInt(data['id']),
      qpayStatus: data['qpay_status']?.toString() ??
          payment['qpay_status']?.toString(),
      retryable: data.containsKey('retryable')
          ? JsonParse.toBool(data['retryable'])
          : null,
      nextAction: data['next_action']?.toString() ??
          map['next_action']?.toString(),
      raw: map,
    );
  }
}
