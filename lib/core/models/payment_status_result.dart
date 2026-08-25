import 'package:hudhud_delivery_driver/core/constants/payment_method_codes.dart';
import 'package:hudhud_delivery_driver/core/utils/json_parse.dart';

class PaymentStatusResult {
  const PaymentStatusResult({
    this.status,
    this.message,
    this.paymentId,
    this.qpayStatus,
    this.retryable,
    this.nextAction,
    this.code,
    this.walletTopupSettlement,
    this.raw = const {},
  });

  final String? status;
  final String? message;
  final int? paymentId;
  final String? qpayStatus;
  final bool? retryable;
  final String? nextAction;
  final String? code;
  final String? walletTopupSettlement;
  final Map<String, dynamic> raw;

  String? get _qpayNormalized => qpayStatus?.toUpperCase();

  String? get _settlementNormalized =>
      walletTopupSettlement?.trim().toLowerCase();

  bool get isExpired =>
      status == 'expired' || _qpayNormalized == 'EXPIRED';

  bool get hasWalletSettlement {
    final settlement = _settlementNormalized;
    return settlement != null && settlement.isNotEmpty;
  }

  bool get isWalletSettled {
    final settlement = _settlementNormalized;
    return settlement == 'credited' || settlement == 'already_credited';
  }

  bool get isAwaitingProvider {
    final settlement = _settlementNormalized;
    return settlement == 'awaiting_provider_confirmation' ||
        settlement == 'awaiting_provider_amount';
  }

  bool get isEbirrRetryRequired =>
      (code ?? '').toUpperCase() ==
          PaymentMethodCodes.ebirrStatusRetryRequired ||
      (retryable == true && isAwaitingProvider);

  bool get isPending {
    if (isCompleted || isTerminalFailure) return false;
    if (isAwaitingProvider || isEbirrRetryRequired) return true;
    if (retryable == true &&
        (status == 'pending' || status == 'processing' || status == null)) {
      return true;
    }
    return status == 'pending' ||
        status == 'processing' ||
        _qpayNormalized == 'PENDING';
  }

  bool get isCompleted {
    if (isAwaitingProvider || isEbirrRetryRequired) return false;
    if (hasWalletSettlement) return isWalletSettled;
    return status == 'completed' ||
        status == 'paid' ||
        status == 'settled' ||
        nextAction == 'complete_delivery';
  }

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

    bool? retryable;
    if (map.containsKey('retryable')) {
      retryable = JsonParse.toBool(map['retryable']);
    } else if (data.containsKey('retryable')) {
      retryable = JsonParse.toBool(data['retryable']);
    }

    return PaymentStatusResult(
      status: payment['status']?.toString() ?? data['status']?.toString(),
      message: map['message']?.toString() ?? data['message']?.toString(),
      paymentId: JsonParse.toInt(payment['id']) ?? JsonParse.toInt(data['id']),
      qpayStatus: data['qpay_status']?.toString() ??
          payment['qpay_status']?.toString(),
      retryable: retryable,
      nextAction: data['next_action']?.toString() ??
          map['next_action']?.toString(),
      code: map['code']?.toString() ?? data['code']?.toString(),
      walletTopupSettlement: data['wallet_topup_settlement']?.toString() ??
          payment['wallet_topup_settlement']?.toString() ??
          map['wallet_topup_settlement']?.toString(),
      raw: map,
    );
  }
}
