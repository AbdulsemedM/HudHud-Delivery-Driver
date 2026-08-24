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

    test('ebirr_coop uses the coop USSD provider, not QR', () {
      final details = PaymentDetailsBuilder.build(
        methodCode: PaymentMethodCodes.ebirrCoop,
        phone: '251911234567',
      );
      expect(details['provider'], 'coop');
      expect(details['phone'], '251911234567');
      expect(details.containsKey('channel'), isFalse);
    });

    test('ebirr_kaafi uses the kaafi USSD provider', () {
      final details = PaymentDetailsBuilder.build(
        methodCode: PaymentMethodCodes.ebirrKaafi,
        phone: '251911234567',
      );
      expect(details['provider'], 'kaafi');
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

  group('PaymentMethodCodes eBirr routing', () {
    test('Coop maps to ebirr collection_method with coop provider', () {
      expect(
        PaymentMethodCodes.collectionMethodFor(PaymentMethodCodes.ebirrCoop),
        PaymentMethodCodes.ebirr,
      );
      expect(PaymentMethodCodes.ebirrProvider(PaymentMethodCodes.ebirrCoop), 'coop');
      expect(PaymentMethodCodes.isQpay(PaymentMethodCodes.ebirrCoop), isFalse);
    });

    test('QPay maps to qpay collection_method', () {
      expect(
        PaymentMethodCodes.collectionMethodFor(PaymentMethodCodes.qpay),
        PaymentMethodCodes.qpay,
      );
    });
  });
}
