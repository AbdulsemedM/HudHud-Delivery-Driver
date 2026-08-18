import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/notifications/legacy_notification_mapper.dart';

void main() {
  group('LegacyNotificationMapper.isForgotPasswordOtp', () {
    test('matches event name', () {
      expect(
        LegacyNotificationMapper.isForgotPasswordOtp('forgot_password_otp', {}),
        isTrue,
      );
    });

    test('matches legacy type without skipping OTP entry', () {
      expect(
        LegacyNotificationMapper.isForgotPasswordOtp('', {
          'type': 'PasswordResetOtpNotification',
        }),
        isTrue,
      );
    });

    test('does not match other OTP events', () {
      expect(
        LegacyNotificationMapper.isForgotPasswordOtp('login_otp', {}),
        isFalse,
      );
    });
  });
}
