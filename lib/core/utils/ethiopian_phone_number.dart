/// Normalizes Ethiopian mobile numbers to canonical `2519xxxxxxxx`.
///
/// Accepted inputs (spaces, dashes, and other non-digits are ignored):
/// - `09xxxxxxxx`
/// - `9xxxxxxxx` (local number without leading 0)
/// - `+2519xxxxxxxx`
/// - `2519xxxxxxxx`
/// - `+25109xxxxxxxx` / `25109xxxxxxxx` (country code plus leftover local 0)
class EthiopianPhoneNumber {
  EthiopianPhoneNumber._();

  static final RegExp _nonDigits = RegExp(r'\D');
  static final RegExp _localNine = RegExp(r'^9\d{8}$');

  /// Returns `2519xxxxxxxx`, or `null` if [input] is not a valid Ethiopian mobile.
  static String? tryNormalize(String? input) {
    if (input == null) return null;
    final digits = input.replaceAll(_nonDigits, '');
    if (digits.isEmpty) return null;

    String? local;
    if (digits.startsWith('2510') && digits.length == 13) {
      local = digits.substring(4);
    } else if (digits.startsWith('251') && digits.length == 12) {
      local = digits.substring(3);
    } else if (digits.startsWith('0') && digits.length == 10) {
      local = digits.substring(1);
    } else if (digits.length == 9) {
      local = digits;
    }

    if (local == null || !_localNine.hasMatch(local)) return null;
    return '251$local';
  }

  static bool isValid(String? input) => tryNormalize(input) != null;

  /// Canonical form when parseable; otherwise the original string.
  static String normalizeOrOriginal(String phone) =>
      tryNormalize(phone) ?? phone;

  static String? formValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    if (tryNormalize(value) == null) {
      return 'Enter a valid Ethiopian phone number';
    }
    return null;
  }

  /// Login helper: emails pass through; phone values are normalized.
  /// Returns `null` when the value is not an email and not a valid phone.
  static String? normalizeIdentifier(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.contains('@')) return trimmed;
    return tryNormalize(trimmed);
  }

  /// Converts canonical `2519xxxxxxxx` to local display `09xxxxxxxx`.
  static String formatForDisplay(String canonical) {
    if (canonical.startsWith('251') && canonical.length == 12) {
      return '0${canonical.substring(3)}';
    }
    return canonical;
  }

  /// Masks a number as `2519******xx`. Falls back to the raw value if too short.
  static String mask(String? phone) {
    final canonical = tryNormalize(phone) ?? (phone ?? '').trim();
    if (canonical.length <= 6) return canonical;
    return '${canonical.substring(0, 4)}******${canonical.substring(canonical.length - 2)}';
  }
}
