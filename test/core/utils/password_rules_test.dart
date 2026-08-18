import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/utils/password_rules.dart';

void main() {
  group('PasswordRules.validate', () {
    test('accepts any 6+ character password', () {
      expect(PasswordRules.validate('123456'), isNull);
      expect(PasswordRules.validate('abcdef'), isNull);
      expect(PasswordRules.validate('pass12'), isNull);
    });

    test('rejects empty and short passwords', () {
      expect(
        PasswordRules.validate(''),
        'Please enter a password',
      );
      expect(
        PasswordRules.validate('12345'),
        'Password must be at least 6 characters',
      );
    });

    test('uses custom empty message', () {
      expect(
        PasswordRules.validate('', emptyMessage: 'Required'),
        'Required',
      );
    });
  });
}
