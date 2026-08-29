import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/config/api_config.dart';
import 'package:hudhud_delivery_driver/core/models/branch_handoff.dart';
import 'package:hudhud_delivery_driver/core/models/delivery_reference.dart';

void main() {
  group('BranchHandoff', () {
    test('parses an assigned-driver handoff response', () {
      final handoff = BranchHandoff.fromResponse({
        'branch_handoff': {
          'required': true,
          'status': 'awaiting_driver_and_teller',
          'branch': {
            'name': 'Synthetic Branch',
            'address': 'Synthetic address',
          },
          'otp': 'synthetic-code',
          'otp_digit_length': 6,
        },
      });

      expect(handoff.required, isTrue);
      expect(handoff.isAwaitingTeller, isTrue);
      expect(handoff.isConfirmed, isFalse);
      expect(handoff.branchName, 'Synthetic Branch');
      expect(handoff.branchAddress, 'Synthetic address');
      expect(handoff.otp, 'synthetic-code');
      expect(handoff.otpDigitLength, 6);
    });

    test('normal deliveries do not expose handoff UI', () {
      final handoff = BranchHandoff.fromResponse({
        'branch_handoff': {'required': false},
      });

      expect(handoff.required, isFalse);
      expect(handoff.isAwaitingTeller, isFalse);
      expect(handoff.otp, isNull);
    });

    test('confirmed handoffs stop blocking the delivery', () {
      final handoff = BranchHandoff.fromResponse({
        'branch_handoff': {
          'required': true,
          'status': 'confirmed',
          'confirmed_at': '2026-08-29T12:00:00+03:00',
        },
      });

      expect(handoff.isConfirmed, isTrue);
      expect(handoff.isAwaitingTeller, isFalse);
      expect(handoff.confirmedAt, isNotNull);
    });
  });

  group('BranchHandoffSmsResult', () {
    test('parses only safe resend status fields', () {
      final result = BranchHandoffSmsResult.fromJson({
        'success': false,
        'code': 'HANDOFF_SMS_RESEND_COOLDOWN',
        'retryable': true,
        'retry_after_seconds': 90,
        'message': 'Please wait before requesting another SMS.',
      });

      expect(result.success, isFalse);
      expect(result.code, 'HANDOFF_SMS_RESEND_COOLDOWN');
      expect(result.retryable, isTrue);
      expect(result.retryAfterSeconds, 90);
    });
  });

  group('DeliveryReference', () {
    test('shows the Courier AWB without the integration prefix', () {
      final delivery = {
        'external_order_id': 'HUDHUD-SYNTHETIC-AWB',
        'tracking_number': 'PROVIDER-TRACKING',
        'package_description': 'Synthetic parcel description',
      };

      expect(DeliveryReference.awb(delivery), 'SYNTHETIC-AWB');
      expect(
        DeliveryReference.description(delivery),
        'Synthetic parcel description',
      );
    });

    test('falls back to provider tracking when no partner reference exists',
        () {
      expect(
        DeliveryReference.awb({'tracking_number': 'PROVIDER-TRACKING'}),
        'PROVIDER-TRACKING',
      );
    });
  });

  group('branch handoff API paths', () {
    test('use the authenticated driver delivery namespace', () {
      expect(
        ApiConfig.driverDeliveryBranchHandoffEndpoint(42),
        '/driver/services/delivery/42/branch-handoff',
      );
      expect(
        ApiConfig.driverDeliveryBranchHandoffResendSmsEndpoint(42),
        '/driver/services/delivery/42/branch-handoff/resend-sms',
      );
    });
  });
}
