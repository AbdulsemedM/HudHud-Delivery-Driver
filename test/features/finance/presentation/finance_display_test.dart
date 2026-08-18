import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/constants/limit_status.dart';
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

  group('LimitStatus finance visuals', () {
    test('near_limit shows warning only', () {
      const status = LimitStatus.nearLimit;
      expect(status.showWarning, isTrue);
      expect(status.showCritical, isFalse);
      expect(status.showFinanceAlert, isTrue);
    });

    test('at_limit shows critical not warning', () {
      const status = LimitStatus.atLimit;
      expect(status.showWarning, isFalse);
      expect(status.showCritical, isTrue);
      expect(status.blocksAcceptance, isFalse);
    });

    test('finance colors differ for warning and critical', () {
      expect(
        LimitStatus.nearLimit.financeBackgroundColor,
        isA<Color>(),
      );
      expect(
        LimitStatus.atLimit.financeBackgroundColor,
        isA<Color>(),
      );
      expect(
        LimitStatus.nearLimit.financeBackgroundColor,
        isNot(equals(LimitStatus.atLimit.financeBackgroundColor)),
      );
    });
  });
}
