import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/models/delivery_otp.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';

void main() {
  group('DeliveryOtp.fromJson', () {
    test('parses safe OTP state without storing plaintext code', () {
      final otp = DeliveryOtp.fromJson({
        'required': true,
        'generated': true,
        'verified': false,
        'digit_length': 6,
        'channel': 'sms',
        'attempts': 1,
        'max_attempts': 5,
        'attempts_remaining': 4,
        'locked': false,
        'support_required': false,
        'valid_until_delivery_closes': true,
        'otp': '482913',
        'hash': 'secret',
      });

      expect(otp, isNotNull);
      expect(otp!.digitLength, 6);
      expect(otp.attemptsRemaining, 4);
      expect(otp.isPending, isTrue);
    });

    test('defaults digit length to 6', () {
      expect(DeliveryOtp.fromJson({'required': true})!.digitLength, 6);
    });

    test('supports legacy 4-digit length', () {
      expect(DeliveryOtp.fromJson({'digit_length': 4})!.digitLength, 4);
    });
  });

  group('DeliveryOtp.fromDelivery', () {
    test('reads nested delivery.otp', () {
      final otp = DeliveryOtp.fromDelivery({
        'otp': {'required': true, 'verified': false, 'digit_length': 6},
      });
      expect(otp?.required, isTrue);
      expect(otp?.verified, isFalse);
    });

    test('falls back to identity_verification_required', () {
      expect(
        DeliveryOtp.otpRequiredForDelivery({
          'identity_verification_required': true,
        }),
        isTrue,
      );
    });

    test('returns false when OTP already verified', () {
      expect(
        DeliveryOtp.otpRequiredForDelivery({
          'otp': {'required': true, 'verified': true},
        }),
        isFalse,
      );
    });
  });

  group('DeliveryOtpDeliveryResult.fromAcceptResponse', () {
    test('parses OTP_SENT accept payload', () {
      final result = DeliveryOtpDeliveryResult.fromAcceptResponse({
        'message': 'Delivery accepted successfully!',
        'otp_delivery': {
          'success': true,
          'code': 'OTP_SENT',
          'message': 'Delivery OTP sent to the customer by SMS.',
          'otp': {'required': true, 'digit_length': 6},
        },
      });

      expect(result, isNotNull);
      expect(result!.code, 'OTP_SENT');
      expect(result.smsNeedsRetry, isFalse);
      expect(result.otp?.digitLength, 6);
    });

    test('flags SMS retry codes', () {
      final failed = DeliveryOtpDeliveryResult.fromAcceptResponse({
        'otp_delivery': {'code': 'OTP_SMS_FAILED'},
      });
      expect(failed?.smsNeedsRetry, isTrue);

      final deferred = DeliveryOtpDeliveryResult.fromAcceptResponse({
        'otp_delivery': {'code': 'OTP_DELIVERY_DEFERRED'},
      });
      expect(deferred?.smsNeedsRetry, isTrue);
    });
  });

  group('DeliveryOtpError.fromException', () {
    test('maps OTP_INCORRECT with attempts remaining', () {
      final error = DeliveryOtpError.fromException(
        BadRequestException(
          'Incorrect code. Please try again.',
          code: 'OTP_INCORRECT',
          details: {
            'code': 'OTP_INCORRECT',
            'attempts_remaining': 4,
          },
        ),
      );

      expect(error, isNotNull);
      expect(error!.isIncorrect, isTrue);
      expect(error.attemptsRemaining, 4);
    });

    test('maps OTP_ATTEMPTS_EXCEEDED lockout', () {
      final error = DeliveryOtpError.fromException(
        LockedException(
          'OTP attempts are locked. Contact support for assistance.',
          code: 'OTP_ATTEMPTS_EXCEEDED',
          details: {
            'code': 'OTP_ATTEMPTS_EXCEEDED',
            'support_required': true,
            'attempts_remaining': 0,
          },
        ),
      );

      expect(error?.isLockedOut, isTrue);
      expect(error?.supportRequired, isTrue);
    });

    test('maps OTP_RESEND_COOLDOWN retry_after_seconds', () {
      final error = DeliveryOtpError.fromException(
        TooManyRequestsException(
          'Please wait before resending.',
          code: 'OTP_RESEND_COOLDOWN',
          details: {
            'code': 'OTP_RESEND_COOLDOWN',
            'retry_after_seconds': 60,
          },
        ),
      );

      expect(error?.isResendCooldown, isTrue);
      expect(error?.retryAfterSeconds, 60);
    });
  });
}
