import 'package:hudhud_delivery_driver/core/constants/payment_method_codes.dart';
import 'package:hudhud_delivery_driver/core/utils/json_parse.dart';

class PaymentMethod {
  const PaymentMethod({
    required this.code,
    this.name,
    this.description,
    this.icon,
    this.enabled = true,
    this.sortOrder = 0,
    this.canUse = true,
    this.availabilityCode,
    this.requiresQr = false,
    this.supportsQrPayment = false,
    this.instantPayment = false,
  });

  final String code;
  final String? name;
  final String? description;
  final String? icon;
  final bool enabled;
  final int sortOrder;
  final bool canUse;
  final String? availabilityCode;
  final bool requiresQr;
  final bool supportsQrPayment;
  final bool instantPayment;

  bool get isQpay => code == PaymentMethodCodes.qpay;

  /// QPay is offered only when the registry explicitly allows it.
  bool get canInitiateQpay =>
      isQpay &&
      canUse &&
      availabilityCode != PaymentMethodCodes.qpayNotConfigured;

  factory PaymentMethod.fromJson(Map<String, dynamic> map) {
    final code = map['code']?.toString().trim().toLowerCase() ?? '';
    final isQpay = code == PaymentMethodCodes.qpay;
    return PaymentMethod(
      code: code,
      name: map['name']?.toString(),
      description: map['description']?.toString(),
      icon: map['icon']?.toString(),
      enabled: JsonParse.toBool(map['is_active'], defaultValue: true),
      sortOrder: JsonParse.toInt(map['sort_order']) ?? 0,
      canUse: JsonParse.toBool(
        map['can_use'],
        defaultValue: !isQpay,
      ),
      availabilityCode: map['availability_code']?.toString(),
      requiresQr: JsonParse.toBool(map['requires_qr']) ||
          JsonParse.toBool(map['supports_qr_payment']),
      supportsQrPayment: JsonParse.toBool(map['supports_qr_payment']) ||
          JsonParse.toBool(map['requires_qr']),
      instantPayment: JsonParse.toBool(map['instant_payment']),
    );
  }
}
