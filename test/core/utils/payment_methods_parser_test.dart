import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/constants/payment_method_codes.dart';
import 'package:hudhud_delivery_driver/core/utils/payment_methods_parser.dart';

void main() {
  group('parsePaymentMethodsList', () {
    test('filters inactive and allowlist', () {
      final methods = parsePaymentMethodsList(
        {
          'data': [
            {
              'code': 'ebirr_kaafi',
              'name': 'eBirr Kaafi',
              'is_active': true,
              'sort_order': 1,
            },
            {
              'code': 'wallet',
              'name': 'Wallet',
              'is_active': true,
            },
            {
              'code': 'ebirr_coop',
              'name': 'Coop',
              'is_active': false,
            },
          ],
        },
        allowedCodes: PaymentMethodCodes.kDropOffElectronicCodes,
      );

      expect(methods.length, 1);
      expect(methods.first.code, 'ebirr_kaafi');
    });

    test('hides methods when can_use is false', () {
      final methods = parsePaymentMethodsList(
        {
          'data': [
            {
              'code': 'qpay',
              'name': 'QPay',
              'is_active': true,
              'can_use': false,
              'availability_code': 'QPAY_NOT_CONFIGURED',
              'requires_qr': true,
              'instant_payment': false,
            },
            {
              'code': 'ebirr',
              'name': 'eBirr',
              'is_active': true,
              'can_use': true,
            },
          ],
        },
        allowedCodes: PaymentMethodCodes.kDropOffElectronicCodes,
      );

      expect(methods.length, 1);
      expect(methods.first.code, 'ebirr');
    });
  });
}
