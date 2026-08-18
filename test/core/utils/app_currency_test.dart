import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/utils/app_currency.dart';

void main() {
  group('AppCurrency', () {
    test('defaults empty and USD to ETB', () {
      expect(AppCurrency.resolve(null), 'ETB');
      expect(AppCurrency.resolve(''), 'ETB');
      expect(AppCurrency.resolve('USD'), 'ETB');
      expect(AppCurrency.resolve(r'$'), 'ETB');
    });

    test('formats amounts without a dollar sign', () {
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
