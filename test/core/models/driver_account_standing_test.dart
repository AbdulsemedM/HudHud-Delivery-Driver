import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/constants/limit_status.dart';
import 'package:hudhud_delivery_driver/core/models/driver_account_standing.dart';
import 'package:hudhud_delivery_driver/core/models/finance_data_source.dart';

void main() {
  group('DriverAccountStanding.fromJson', () {
    test('parses direct fields', () {
      final standing = DriverAccountStanding.fromJson({
        'currency': 'ETB',
        'wallet_balance': 220.0,
        'amount_driver_owes_platform': 15.5,
        'available_acceptance_limit': 100.0,
        'limit_status': 'near_limit',
      });

      expect(standing, isNotNull);
      expect(standing!.walletBalance, 220.0);
      expect(standing.displayAmountOwed, 15.5);
      expect(standing.limitStatus, LimitStatus.nearLimit);
    });

    test('parses account nested fields', () {
      final standing = DriverAccountStanding.fromJson({
        'data': {
          'account': {
            'currency': 'ETB',
            'current_balance': 300.0,
            'driver_owes_platform': 20.0,
            'available_limit': 80.0,
            'limit_status': 'blocked',
          },
        },
      });

      expect(standing, isNotNull);
      expect(standing!.walletBalance, 300.0);
      expect(standing.displayAmountOwed, 20.0);
      expect(standing.availableAcceptanceLimit, 80.0);
      expect(standing.limitStatus, LimitStatus.blocked);
    });

    test('parses summary/wallet variants', () {
      final standing = DriverAccountStanding.fromJson({
        'data': {
          'summary': {
            'amount_owed': '11.0',
            'warning_threshold': 50,
          },
          'wallet': {
            'balance': 145.75,
            'wallet_currency': 'ETB',
          },
        },
      });

      expect(standing, isNotNull);
      expect(standing!.walletBalance, 145.75);
      expect(standing.amountOwedToPlatform, 11.0);
      expect(standing.limitWarningThreshold, 50.0);
      expect(standing.currency, 'ETB');
    });

    test('parses profile statistics fields', () {
      final standing = DriverAccountStanding.fromJson({
        'data': {
          'summary': {
            'total_deliveries': 87,
            'total_earnings': 4900.75,
            'completion_rate': 96.3,
          },
        },
      });

      expect(standing, isNotNull);
      expect(standing!.totalDeliveries, 87);
      expect(standing.totalEarnings, 4900.75);
      expect(standing.completionRate, 96.3);
      expect(standing.source, FinanceDataSource.primary);
    });

    test('supports fallback source via copyWith', () {
      final standing = DriverAccountStanding.fromJson({
        'data': {'wallet': {'balance': 100}},
      })!;
      final fallback = standing.copyWith(
        source: FinanceDataSource.fallback,
        sourceMessage: 'Account standing details are not available yet.',
      );

      expect(fallback.source, FinanceDataSource.fallback);
      expect(
        fallback.sourceMessage,
        'Account standing details are not available yet.',
      );
      expect(fallback.walletBalance, 100);
    });
  });
}
