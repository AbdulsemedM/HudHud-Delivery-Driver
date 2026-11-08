import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/utils/app_currency.dart';

void main() {
  group('AppCurrency', () {
    test('defaults empty to ETB and keeps USD', () {
      expect(AppCurrency.resolve(null), 'ETB');
      expect(AppCurrency.resolve(''), 'ETB');
      expect(AppCurrency.resolve('etb'), 'ETB');
      expect(AppCurrency.resolve('USD'), 'USD');
      expect(AppCurrency.resolve('usd'), 'USD');
      expect(AppCurrency.resolve(r'$'), 'USD');
      expect(AppCurrency.isUsd('USD'), isTrue);
      expect(AppCurrency.isUsd(null), isFalse);
    });

    test('prefix is a dollar sign for USD, the code otherwise', () {
      expect(AppCurrency.prefix('USD'), r'$');
      expect(AppCurrency.prefix(null), 'ETB ');
      expect(AppCurrency.prefix('ETB'), 'ETB ');
    });

    test('formats USD (Hargeisa) amounts with a dollar sign', () {
      expect(AppCurrency.format(12.5, currency: 'USD'), r'$12.50');
      expect(AppCurrency.format('12.5', currency: 'usd'), r'$12.50');
      expect(AppCurrency.format(r'$4', currency: 'USD'), r'$4.00');
      expect(AppCurrency.format('ETB 3.456', currency: 'USD'), r'$3.46');
      expect(AppCurrency.format(-3, currency: 'USD'), r'-$3.00');
    });

    test('a dollar sign without a currency is still shown as ETB', () {
      expect(AppCurrency.format('12.50'), 'ETB 12.50');
      expect(AppCurrency.format(r'$12.50'), 'ETB 12.50');
      expect(AppCurrency.format('USD 12.50'), 'ETB 12.50');
      expect(AppCurrency.format('—'), '—');
    });

    test('rounds numeric amounts to two decimal places', () {
      expect(AppCurrency.format(98.591234), 'ETB 98.59');
      expect(AppCurrency.format('12.5'), 'ETB 12.50');
      expect(AppCurrency.format('98.591234'), 'ETB 98.59');
      expect(AppCurrency.format('ETB 98.591234'), 'ETB 98.59');
    });
  });

  group('AppCurrency.formatDecimal', () {
    test('rounds to two decimal places', () {
      expect(AppCurrency.formatDecimal(1.9876), '1.99');
      expect(AppCurrency.formatDecimal(4.5), '4.50');
      expect(AppCurrency.formatDecimal(null), '—');
    });
  });
}
