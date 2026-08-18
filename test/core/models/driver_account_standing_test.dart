import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/constants/limit_status.dart';
import 'package:hudhud_delivery_driver/core/models/driver_account_standing.dart';
import 'package:hudhud_delivery_driver/core/models/finance_data_source.dart';

void main() {
  group('DriverAccountStanding.fromJson', () {
    test('parses ACCOUNT_STANDING_READY payload', () {
      final standing = DriverAccountStanding.fromJson({
        'success': true,
        'code': 'ACCOUNT_STANDING_READY',
        'data': {
          'currency': 'ETB',
          'wallet': {
            'id': 12,
            'type': 'driver',
            'balance': 20.00,
            'currency': 'ETB',
            'auto_provisioned': false,
          },
          'held_collateral': 0.00,
          'active_platform_fee_commitment': 0.00,
          'amount_owed_to_platform': 0.00,
          'amount_driver_owes_platform': 0.00,
          'available_acceptance_limit': 20.00,
          'limit_warning_threshold': 100.00,
          'limit_block_threshold': 0.00,
          'limit_status': 'near_limit',
          'application_status': 'accepted',
          'can_accept_cod': true,
          'risk_level': 'warning',
          'commitments': {
            'food_and_vendor_cod': [],
            'package_delivery_platform_fees': [],
          },
          'outstanding_settlements': [],
          'recommended_actions': [
            'Top up the driver wallet to increase the available acceptance limit.',
          ],
          'calculation_basis': {
            'wallet_balance':
                'completed wallet credits minus completed wallet debits',
          },
          'as_of': '2026-08-18T10:00:00+00:00',
        },
      });

      expect(standing, isNotNull);
      expect(standing!.walletId, 12);
      expect(standing.walletType, 'driver');
      expect(standing.walletAutoProvisioned, false);
      expect(standing.walletBalance, 20.0);
      expect(standing.availableAcceptanceLimit, 20.0);
      expect(standing.limitStatus, LimitStatus.nearLimit);
      expect(standing.riskLevel, 'warning');
      expect(standing.applicationStatus, 'accepted');
      expect(standing.canAcceptCod, true);
      expect(standing.actions, hasLength(1));
      expect(standing.debtAsOf, isNotNull);
      expect(standing.calculationBasis['wallet_balance'], isNotEmpty);
      expect(standing.source, FinanceDataSource.primary);
    });

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
