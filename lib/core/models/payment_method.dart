import 'package:hudhud_delivery_driver/core/constants/payment_method_codes.dart';
import 'package:hudhud_delivery_driver/core/utils/json_parse.dart';

/// Server guidance for provider account formatting (client never prepends prefix).
class PhoneNormalization {
  const PhoneNormalization({
    this.phoneInputFormat,
    this.serverAccountPrefix,
    this.prefixAppliedServerSide = false,
  });

  final String? phoneInputFormat;
  final String? serverAccountPrefix;
  final bool prefixAppliedServerSide;

  factory PhoneNormalization.fromJson(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) {
      return const PhoneNormalization();
    }
    return PhoneNormalization(
      phoneInputFormat: map['phone_input_format']?.toString(),
      serverAccountPrefix: map['server_account_prefix']?.toString(),
      prefixAppliedServerSide:
          JsonParse.toBool(map['prefix_applied_server_side']),
    );
  }
}

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
    this.availabilityMessage,
    this.phoneNormalization,
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
  final String? availabilityMessage;
  final PhoneNormalization? phoneNormalization;
  final bool requiresQr;
  final bool supportsQrPayment;
  final bool instantPayment;

  bool get isQpay => code == PaymentMethodCodes.qpay;

  bool get isEbirrKaafi => code == PaymentMethodCodes.ebirrKaafi;

  /// QPay is offered only when the registry explicitly allows it.
  bool get canInitiateQpay =>
      isQpay &&
      canUse &&
      availabilityCode != PaymentMethodCodes.qpayNotConfigured;

  bool get isEbirrKaafiNotConfigured =>
      isEbirrKaafi &&
      availabilityCode == PaymentMethodCodes.ebirrKaafiNotConfigured;

  /// Kaafi is selectable only when the server marks it usable and configured.
  bool get canInitiateEbirrKaafi =>
      isEbirrKaafi && canUse && !isEbirrKaafiNotConfigured;

  factory PaymentMethod.fromJson(Map<String, dynamic> map) {
    final code = map['code']?.toString().trim().toLowerCase() ?? '';
    final isQpay = code == PaymentMethodCodes.qpay;
    final phoneNormRaw = map['phone_normalization'];
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
      availabilityMessage: map['availability_message']?.toString(),
      phoneNormalization: phoneNormRaw is Map
          ? PhoneNormalization.fromJson(
              Map<String, dynamic>.from(phoneNormRaw),
            )
          : null,
      requiresQr: JsonParse.toBool(map['requires_qr']) ||
          JsonParse.toBool(map['supports_qr_payment']),
      supportsQrPayment: JsonParse.toBool(map['supports_qr_payment']) ||
          JsonParse.toBool(map['requires_qr']),
      instantPayment: JsonParse.toBool(map['instant_payment']),
    );
  }
}
