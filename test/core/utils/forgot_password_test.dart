import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/utils/forgot_password.dart';

void main() {
  group('ForgotPassword.methodForIdentifier', () {
    test('returns email for an email address', () {
      expect(
        ForgotPassword.methodForIdentifier('user@example.com'),
        ForgotPassword.emailMethod,
      );
    });

    test('returns phone for anything else', () {
      expect(
        ForgotPassword.methodForIdentifier('251911234567'),
        ForgotPassword.phoneMethod,
      );
      expect(
        ForgotPassword.methodForIdentifier('+251911234567'),
        ForgotPassword.phoneMethod,
      );
      expect(
        ForgotPassword.methodForIdentifier('not-an-email'),
        ForgotPassword.phoneMethod,
      );
    });
  });

  group('ForgotPassword.validateNewPassword', () {
    test('accepts a strong password', () {
      expect(ForgotPassword.validateNewPassword('98899889bA!'), isNull);
    });

    test('rejects short, missing case, digit, or special', () {
      expect(ForgotPassword.validateNewPassword(''), isNotNull);
      expect(ForgotPassword.validateNewPassword('Ab1!aa'), isNotNull);
      expect(ForgotPassword.validateNewPassword('abcdefgh1!'), isNotNull);
      expect(ForgotPassword.validateNewPassword('ABCDEFGH1!'), isNotNull);
      expect(ForgotPassword.validateNewPassword('Abcdefgh!'), isNotNull);
      expect(ForgotPassword.validateNewPassword('Abcdefgh1'), isNotNull);
    });
  });

  group('ForgotPassword.errorMessage', () {
    test('maps HTTP 500 to a generic client message', () {
      expect(
        ForgotPassword.errorMessage(500, {'message': 'Server Error'}),
        ForgotPassword.serverErrorFallback,
      );
    });

    test('appends remaining_attempts', () {
      expect(
        ForgotPassword.errorMessage(422, {
          'message': 'Invalid OTP',
          'remaining_attempts': 2,
        }),
        'Invalid OTP (2 attempts left)',
      );
    });

    test('appends locked_until', () {
      expect(
        ForgotPassword.errorMessage(429, {
          'message': 'Too many attempts',
          'locked_until': '2026-05-18T12:00:00Z',
        }),
        'Too many attempts (2026-05-18T12:00:00Z)',
      );
    });

    test('uses 429 fallback when message is empty', () {
      expect(
        ForgotPassword.errorMessage(429, {}),
        ForgotPassword.rateLimitedFallback,
      );
    });

    test('joins field errors and strips prefixes', () {
      expect(
        ForgotPassword.errorMessage(422, {
          'message': 'Validation error: The selected identifier is invalid.',
          'errors': {
            'identifier': ['The selected identifier is invalid.'],
          },
        }),
        'The selected identifier is invalid.',
      );
    });
  });

  group('ForgotPassword.expiresInMinutes', () {
    test('request defaults to 15 when missing', () {
      expect(ForgotPassword.expiresInMinutesForRequest({}), 15);
      expect(ForgotPassword.expiresInMinutesForRequest(null), 15);
      expect(
        ForgotPassword.expiresInMinutesForRequest({'expires_in_minutes': '10'}),
        10,
      );
    });

    test('resend leaves timer unchanged when field is absent on a map', () {
      expect(ForgotPassword.expiresInMinutesForResend({'message': 'ok'}), isNull);
      expect(ForgotPassword.expiresInMinutesForResend('not-a-map'), 15);
      expect(
        ForgotPassword.expiresInMinutesForResend({'expires_in_minutes': 8}),
        8,
      );
    });
  });
}
