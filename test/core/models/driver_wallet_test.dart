import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/models/finance_data_source.dart';
import 'package:hudhud_delivery_driver/core/models/driver_wallet.dart';

void main() {
  group('DriverWallet.fromJson', () {
    test('parses top-level balance', () {
      final wallet = DriverWallet.fromJson({
        'balance': 150.0,
        'currency': 'ETB',
      });

      expect(wallet, isNotNull);
      expect(wallet!.balance, 150.0);
      expect(wallet.currency, 'ETB');
    });

    test('parses current_balance variant', () {
      final wallet = DriverWallet.fromJson({
        'current_balance': '175.50',
        'currency': 'ETB',
      });

      expect(wallet, isNotNull);
      expect(wallet!.balance, 175.50);
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

    test('parses data.wallet_balance variant', () {
      final wallet = DriverWallet.fromJson({
        'data': {
          'wallet_balance': 310.0,
          'wallet_currency': 'ETB',
        },
      });

      expect(wallet, isNotNull);
      expect(wallet!.balance, 310.0);
      expect(wallet.currency, 'ETB');
    });

    test('supports fallback source via copyWith', () {
      final wallet = DriverWallet.fromJson({
        'balance': 90,
        'currency': 'ETB',
      })!;
      final fallback = wallet.copyWith(
        source: FinanceDataSource.fallback,
        sourceMessage: 'Wallet endpoint unavailable, showing profile wallet balance.',
      );

      expect(fallback.source, FinanceDataSource.fallback);
      expect(
        fallback.sourceMessage,
        'Wallet endpoint unavailable, showing profile wallet balance.',
      );
      expect(fallback.balance, 90);
    });
  });
}
