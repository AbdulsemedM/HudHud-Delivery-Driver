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
  });
}
