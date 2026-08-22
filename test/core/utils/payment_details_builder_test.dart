import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/constants/payment_method_codes.dart';
import 'package:hudhud_delivery_driver/core/utils/payment_details_builder.dart';

void main() {
  group('PaymentDetailsBuilder', () {
    test('normalizes Sahay/eBirr phone to 2519xxxxxxxx', () {
      final details = PaymentDetailsBuilder.build(
        methodCode: PaymentMethodCodes.sahay,
        phone: '0911234567',
      );
      expect(details['phone'], '251911234567');
    });

    test('legacy ebirr includes provider kaafi', () {
      final details = PaymentDetailsBuilder.build(
        methodCode: PaymentMethodCodes.ebirr,
        phone: '251911234567',
      );
      expect(details['provider'], 'kaafi');
      expect(details['phone'], '251911234567');
    });

    test('qpay includes a non-empty QR channel', () {
      final details = PaymentDetailsBuilder.build(
        methodCode: PaymentMethodCodes.qpay,
      );
      expect(details['channel'], 'qr');
      expect(details, isNotEmpty);
    });

    test('cash includes receipt note', () {
      final details = PaymentDetailsBuilder.build(
        methodCode: PaymentMethodCodes.cash,
        cashReceiptNote: 'Paid at office',
      );
      expect(details['cash_receipt_note'], 'Paid at office');
    });
  });
}
