import 'package:hudhud_delivery_driver/core/constants/payment_method_codes.dart';
import 'package:hudhud_delivery_driver/core/utils/ethiopian_phone_number.dart';

class PaymentDetailsBuilder {
  PaymentDetailsBuilder._();

  /// Builds `payment_details` for initiate / top-up requests.
  static Map<String, dynamic> build({
    required String methodCode,
    String? phone,
    bool useHpp = false,
    String? cashReceiptNote,
  }) {
    final code = methodCode.trim().toLowerCase();
    final details = <String, dynamic>{};

    switch (code) {
      case PaymentMethodCodes.waafi:
        final normalized = _waafiPhone(phone);
        if (normalized != null) details['phone'] = normalized;
        details['use_hpp'] = useHpp;
        break;
      case PaymentMethodCodes.edahab:
        final edahab = _edahabPhone(phone);
        if (edahab != null) details['phone'] = edahab;
        break;
      case PaymentMethodCodes.sahay:
      case PaymentMethodCodes.ebirr:
      case PaymentMethodCodes.ebirrKaafi:
      case PaymentMethodCodes.ebirrCoop:
        final eth = EthiopianPhoneNumber.tryNormalize(phone);
        if (eth != null) details['phone'] = eth;
        if (code == PaymentMethodCodes.ebirr) {
          details['provider'] = 'kaafi';
        }
        break;
      case PaymentMethodCodes.cash:
        if (cashReceiptNote != null && cashReceiptNote.trim().isNotEmpty) {
          details['cash_receipt_note'] = cashReceiptNote.trim();
        }
        break;
      case PaymentMethodCodes.qpay:
        details['channel'] = 'qr';
        break;
    }

    return details;
  }

  static String? _waafiPhone(String? phone) {
    final digits = phone?.replaceAll(RegExp(r'\D'), '') ?? '';
    if (digits.startsWith('254') && digits.length == 12) return digits;
    final eth = EthiopianPhoneNumber.tryNormalize(phone);
    if (eth == null || eth.length < 9) return null;
    final local = eth.substring(3);
    return '254$local';
  }

  static String? _edahabPhone(String? phone) {
    final digits = phone?.replaceAll(RegExp(r'\D'), '') ?? '';
    if (digits.startsWith('65')) return digits;
    final eth = EthiopianPhoneNumber.tryNormalize(phone);
    if (eth == null) return null;
    final local = eth.substring(3);
    if (local.startsWith('65')) return local;
    return null;
  }
}
