import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/models/finance_data_source.dart';
import 'package:hudhud_delivery_driver/core/models/driver_wallet.dart';

void main() {
  group('DriverWallet.fromJson', () {
    test('parses WALLET_READY payload with nested wallet', () {
      final wallet = DriverWallet.fromJson({
        'success': true,
        'code': 'WALLET_READY',
        'wallet': {
          'id': 12,
          'type': 'driver',
          'balance': 20.00,
          'currency': 'ETB',
          'is_active': true,
        },
        'balance': 99.00,
        'total_income': 20.00,
        'total_expenses': 0.00,
        'currency': 'ETB',
      });

      expect(wallet, isNotNull);
      expect(wallet!.id, 12);
      expect(wallet.type, 'driver');
      expect(wallet.isActive, true);
      expect(wallet.balance, 20.0);
      expect(wallet.totalIncome, 20.0);
      expect(wallet.totalExpenses, 0.0);
      expect(wallet.currency, 'ETB');
    });

    test('accepts zero balance as valid', () {
      final wallet = DriverWallet.fromJson({
        'success': true,
        'code': 'WALLET_READY',
        'wallet': {
          'id': 12,
          'type': 'driver',
          'balance': 0.00,
          'currency': 'ETB',
          'is_active': true,
        },
        'balance': 0.00,
        'total_income': 0.00,
        'total_expenses': 0.00,
        'currency': 'ETB',
      });

      expect(wallet, isNotNull);
      expect(wallet!.balance, 0.0);
    });

    test('parses top-level balance', () {
      final wallet = DriverWallet.fromJson({
        'balance': 150.0,
        'currency': 'ETB',
      });

      expect(wallet, isNotNull);
      expect(wallet!.balance, 150.0);
      expect(wallet.currency, 'ETB');
    });

    test('parses nested data.wallet.balance', () {
      final wallet = DriverWallet.fromJson({
        'data': {
          'wallet': {
            'balance': 220.25,
            'currency': 'ETB',
          },
        },
      });

      expect(wallet, isNotNull);
      expect(wallet!.balance, 220.25);
      expect(wallet.currency, 'ETB');
    });

    test('supports fallback source via copyWith', () {
      final wallet = DriverWallet.fromJson({
        'balance': 90,
        'currency': 'ETB',
      })!;
      final fallback = wallet.copyWith(
        source: FinanceDataSource.fallback,
        sourceMessage:
            'Wallet endpoint unavailable, showing profile wallet balance.',
      );

      expect(fallback.source, FinanceDataSource.fallback);
      expect(fallback.balance, 90);
    });
  });

  group('WalletTransaction.listFromJson', () {
    test('parses paginated data.data transactions', () {
      final transactions = WalletTransaction.listFromJson({
        'success': true,
        'code': 'WALLET_TRANSACTIONS_READY',
        'wallet': {
          'id': 12,
          'type': 'driver',
          'balance': 20.00,
          'currency': 'ETB',
        },
        'data': {
          'current_page': 1,
          'data': [
            {
              'id': 1,
              'amount': 20.0,
              'description': 'Credit',
              'created_at': '2026-08-18T10:00:00+00:00',
              'type': 'credit',
              'currency': 'ETB',
            },
          ],
          'per_page': 20,
          'total': 1,
          'last_page': 1,
        },
      });

      expect(transactions, hasLength(1));
      expect(transactions.first.amount, 20.0);
      expect(transactions.first.description, 'Credit');
    });
  });

  group('WalletTransactionsPage.fromJson', () {
    test('parses pagination metadata', () {
      final page = WalletTransactionsPage.fromJson({
        'data': {
          'current_page': 2,
          'data': [],
          'per_page': 20,
          'total': 0,
          'last_page': 1,
        },
      });

      expect(page.currentPage, 2);
      expect(page.perPage, 20);
      expect(page.transactions, isEmpty);
    });
  });

  group('WalletTransaction.isDriverWalletReward', () {
    test('detects driver wallet reward from type/description', () {
      final reward = WalletTransaction(
        type: 'driver_wallet_reward',
        description: 'Delivery settlement reward',
        amount: 2.5,
      );
      expect(reward.isDriverWalletReward, isTrue);

      final normal = WalletTransaction(
        type: 'earning',
        description: 'Delivery fee',
        amount: 80,
      );
      expect(normal.isDriverWalletReward, isFalse);
    });
  });
}
