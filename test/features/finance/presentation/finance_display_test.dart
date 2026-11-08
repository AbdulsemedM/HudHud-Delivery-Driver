import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/constants/limit_status.dart';
import 'package:hudhud_delivery_driver/core/models/driver_wallet.dart';
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

  group('wallet balance display', () {
    test('negative balance reads as owed to HudHud', () {
      expect(isWalletBalanceOwed(-120.5), isTrue);
      expect(walletDisplayAmount(-120.5), 120.5);
      expect(walletBalanceTitle(-120.5), walletOwedTitle);
      expect(formatWalletBalance(-120.5, 'ETB'), 'You owe HudHud ETB 120.50');
    });

    test('zero and positive balances are unchanged', () {
      expect(isWalletBalanceOwed(0), isFalse);
      expect(walletBalanceTitle(0), 'Wallet balance');
      expect(formatWalletBalance(50, 'ETB'), 'ETB 50.00');
      expect(formatWalletBalance(null, 'ETB'), financeNotAvailableText);
      expect(walletDisplayAmount(null), isNull);
    });
  });

  group('wallet transaction display', () {
    test('COD cash collected row', () {
      const tx = WalletTransaction(
        type: 'debit',
        amount: 420,
        description:
            'Cash collected for order #ORD-1 (vendor + platform share)',
      );
      expect(walletTransactionTitle(tx), codCashCollectedLabel);
      expect(walletTransactionDetail(tx), 'Order #ORD-1 · vendor + platform share');
      expect(formatWalletTransactionAmount(tx), '−ETB 420.00');
    });

    test('earnings row', () {
      const tx = WalletTransaction(
        type: 'credit',
        amount: 85,
        description: 'Delivery earnings for Order #A100',
      );
      expect(walletTransactionTitle(tx), deliveryEarningsLabel);
      expect(walletTransactionDetail(tx), 'Order #A100');
      expect(formatWalletTransactionAmount(tx), '+ETB 85.00');
    });

    test('other rows keep their description and unsigned amount', () {
      const tx = WalletTransaction(description: 'Adjustment', amount: 5);
      expect(walletTransactionTitle(tx), 'Adjustment');
      expect(walletTransactionDetail(tx), isNull);
      expect(formatWalletTransactionAmount(tx), 'ETB 5.00');
      expect(walletTransactionTitle(const WalletTransaction()), 'Transaction');
    });
  });
}
