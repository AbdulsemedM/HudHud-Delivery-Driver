import 'package:hudhud_delivery_driver/core/utils/json_parse.dart';

class PaymentStatusResult {
  const PaymentStatusResult({
    this.status,
    this.message,
    this.paymentId,
    this.raw = const {},
  });

  final String? status;
  final String? message;
  final int? paymentId;
  final Map<String, dynamic> raw;

  bool get isPending =>
      status == 'pending' || status == 'processing';

  bool get isCompleted => status == 'completed' || status == 'paid';

  bool get isTerminalFailure =>
      status == 'failed' ||
      status == 'cancelled' ||
      status == 'refunded' ||
      status == 'partially_refunded';

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
      raw: map,
    );
  }
}
