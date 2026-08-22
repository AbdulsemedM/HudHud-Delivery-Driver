import 'package:hudhud_delivery_driver/core/utils/json_parse.dart';

class PaymentInitiateResult {
  const PaymentInitiateResult({
    this.success = false,
    this.message,
    this.nextAction,
    this.paymentId,
    this.paymentStatus,
    this.transactionId,
    this.customerMessage,
    this.redirectUrl,
    this.qrCode,
    this.qrId,
    this.awb,
    this.expiresAt,
    this.retryable,
    this.idempotentReplay = false,
    this.ussdDispatched = false,
    this.awaitAdminCashConfirmation = false,
    this.raw = const {},
  });

  final bool success;
  final String? message;
  final String? nextAction;
  final int? paymentId;
  final String? paymentStatus;
  final String? transactionId;
  final String? customerMessage;
  final String? redirectUrl;
  final String? qrCode;
  final String? qrId;
  final String? awb;
  final DateTime? expiresAt;
  final bool? retryable;
  final bool idempotentReplay;
  final bool ussdDispatched;
  final bool awaitAdminCashConfirmation;
  final Map<String, dynamic> raw;

  static const rcsSuccess = 'RCS_SUCCESS';
  static const nextActionShowQr = 'show_qr_code';
  static const nextActionRedirectHpp = 'redirect_to_hpp';
  static const nextActionPollStatus = 'poll_status';
  static const nextActionAwaitCash = 'await_admin_cash_confirmation';

  bool get isSuccess =>
      success ||
      raw['code']?.toString() == rcsSuccess;

  bool get isCompleted =>
      paymentStatus == 'completed' ||
      paymentStatus == 'paid';

  bool get shouldPoll {
    if (isCompleted) return false;
    final action = nextAction?.toLowerCase();
    if (action == null || action.isEmpty) return false;
    return action == nextActionShowQr ||
        action == nextActionRedirectHpp ||
        action == nextActionPollStatus ||
        action == 'user_action_required' ||
        action == 'ussd' ||
        action == 'approve_ussd' ||
        paymentStatus == 'pending' ||
        paymentStatus == 'processing';
  }

  factory PaymentInitiateResult.fromJson(dynamic raw) {
    if (raw is! Map) {
      return const PaymentInitiateResult();
    }
    final map = Map<String, dynamic>.from(raw);
    final data = map['data'] is Map
        ? Map<String, dynamic>.from(map['data'] as Map)
        : map;

    final payment = data['payment'] is Map
        ? Map<String, dynamic>.from(data['payment'] as Map)
        : <String, dynamic>{};

    final nextAction = data['next_action']?.toString() ??
        map['next_action']?.toString();

    final qr = data['qr_code']?.toString() ??
        data['qpay_qr_code']?.toString() ??
        payment['qr_code']?.toString();

    return PaymentInitiateResult(
      success: JsonParse.toBool(map['success']) || JsonParse.toBool(data['success']),
      message: map['message']?.toString() ?? data['message']?.toString(),
      nextAction: nextAction,
      paymentId: JsonParse.toInt(payment['id']) ?? JsonParse.toInt(data['payment_id']),
      paymentStatus: payment['status']?.toString() ?? data['status']?.toString(),
      transactionId: data['transaction_id']?.toString() ??
          payment['transaction_id']?.toString(),
      customerMessage: data['customer_message']?.toString(),
      redirectUrl: data['redirect_url']?.toString(),
      qrCode: qr,
      qrId: data['qr_id']?.toString(),
      awb: data['awb']?.toString(),
      expiresAt: JsonParse.toDateTime(data['expires_at']),
      retryable: data.containsKey('retryable')
          ? JsonParse.toBool(data['retryable'])
          : null,
      idempotentReplay: JsonParse.toBool(data['idempotent_replay']),
      ussdDispatched: JsonParse.toBool(data['ussd_dispatched']) ||
          JsonParse.toBool(data['ussd_sent']),
      awaitAdminCashConfirmation:
          nextAction == nextActionAwaitCash ||
          data['next_action']?.toString() == nextActionAwaitCash,
      raw: map,
    );
  }
}
