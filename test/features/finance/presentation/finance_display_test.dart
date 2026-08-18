import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/features/finance/presentation/finance_display.dart';

void main() {
  group('finance display helpers', () {
    test('returns no-dash placeholder for null amount', () {
      final text = formatFinanceAmount(null, 'ETB');
      expect(text, financeNotAvailableText);
      expect(text, isNot('—'));
    });

    test('returns no-dash placeholder for null percent', () {
      final text = formatFinancePercent(null);
      expect(text, financeNotAvailableText);
      expect(text, isNot('—'));
    });
  });
}

