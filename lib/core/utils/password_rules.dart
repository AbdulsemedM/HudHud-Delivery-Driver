/// Shared client-side password rules for login, sign-up, and reset flows.
class PasswordRules {
  PasswordRules._();

  static const int minLength = 6;

  static String? validate(
    String? value, {
    String emptyMessage = 'Please enter a password',
  }) {
    if (value == null || value.isEmpty) return emptyMessage;
    if (value.length < minLength) {
      return 'Password must be at least $minLength characters';
    }
    return null;
  }
}
