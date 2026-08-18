import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/constants/limit_status.dart';
import 'package:hudhud_delivery_driver/core/models/driver_financial_preview.dart';

void main() {
  group('DriverFinancialPreview', () {
    test('parses full preview JSON', () {
      final preview = DriverFinancialPreview.fromJson({
        'success': true,
        'currency': 'ETB',
        'delivery_id': 123,
        'expires_at': '2026-08-18T10:05:00Z',
        'pricing': {'customer_total': 98.59},
        'driver_earning': {
          'expected_net_earning': 78.87,
          'platform_commission': 19.72,
        },
        'driver_account': {
          'wallet_balance': 150.0,
          'amount_driver_owes_platform': 0.0,
          'available_acceptance_limit': 100.0,
          'limit_after_acceptance': 50.0,
          'limit_status': 'within_limit',
        },
        'cod': {'can_accept': true, 'required_collateral': 0.0},
        'acceptance': {'can_accept': true, 'blocking_reasons': []},
      });

      expect(preview, isNotNull);
      expect(preview!.pricing.customerTotal, 98.59);
      expect(preview.driverEarning.expectedNetEarning, 78.87);
      expect(preview.account.limitStatus, LimitStatus.withinLimit);
      expect(preview.canAccept, isTrue);
    });

    test('blocks accept when overdue', () {
      final preview = DriverFinancialPreview.fromJson({
        'driver_account': {'limit_status': 'overdue'},
        'cod': {'can_accept': true},
        'acceptance': {'can_accept': true},
      });
      expect(preview!.canAccept, isFalse);
    });

    test('ignores unknown JSON keys', () {
      final preview = DriverFinancialPreview.fromJson({
        'future_field': 'value',
        'driver_earning': {'expected_net_earning': 10.0},
        'cod': {'can_accept': true},
        'acceptance': {'can_accept': true},
      });
      expect(preview?.driverEarning.expectedNetEarning, 10.0);
    });
  });
}
