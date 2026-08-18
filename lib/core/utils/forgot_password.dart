/// Unauthenticated password-reset helpers: identifier method, strength rules,
/// and API error / expiry parsing.
import 'package:hudhud_delivery_driver/core/utils/password_rules.dart';

class ForgotPassword {
  ForgotPassword._();

  static const String emailMethod = 'email';
  static const String phoneMethod = 'phone';
  static const int defaultOtpMinutes = 15;
  static const String successFallback =
      'Password has been reset successfully!';
  static const String invalidServerResponse = 'Invalid server response';
  static const String rateLimitedFallback =
      'Too many attempts. Please try again later.';
  static const String serverErrorFallback =
      'Something went wrong on our side. Please try again later.';
  static const String codeExpiredMessage =
      'Code expired. Please resend a new code.';

  static final RegExp emailRegex =
      RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

  /// Same heuristic as login: email regex → `email`, otherwise `phone`.
  static String methodForIdentifier(String trimmed) {
    if (emailRegex.hasMatch(trimmed.trim())) return emailMethod;
    return phoneMethod;
  }

  static String? validateEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Please enter your email';
    if (!emailRegex.hasMatch(trimmed)) return 'Please enter a valid email';
    return null;
  }

  /// Minimum 6 characters; letters, digits, or any mix.
  static String? validateNewPassword(String? value) {
    return PasswordRules.validate(
      value,
      emptyMessage: 'Please enter a new password',
    );
  }

  static String? requiredString(dynamic data, String key) {
    if (data is! Map) return null;
    final value = data[key]?.toString().trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static String errorMessage(int statusCode, dynamic data) {
    if (statusCode == 500) return serverErrorFallback;

    Map<String, dynamic>? map;
    var message = '';
    if (data is Map) {
      map = Map<String, dynamic>.from(data);
      message = map['message']?.toString().trim() ?? '';
      if (message.isEmpty && map['errors'] is Map) {
        final parts = <String>[];
        for (final value in (map['errors'] as Map).values) {
          if (value is List) {
            parts.addAll(value.map((e) => e.toString()));
          } else if (value != null) {
            parts.add(value.toString());
          }
        }
        message = parts.join(' ');
      }
    } else if (data != null) {
      message = data.toString().trim();
    }

    message = message.replaceFirst(RegExp(r'^Validation error:\s*'), '');
    message = message.replaceFirst(RegExp(r'^HTTP \d+:\s*'), '');

    if (statusCode == 429 && message.isEmpty) {
      message = rateLimitedFallback;
    }
    if (message.isEmpty) message = 'Request failed';

    if (map != null) {
      final remaining = map['remaining_attempts'];
      if (remaining != null) {
        message = '$message ($remaining attempts left)';
      }
      final locked = map['locked_until'];
      if (locked != null && locked.toString().trim().isNotEmpty) {
        message = '$message ($locked)';
      }
    }
    return message;
  }

  /// Step 1: missing field defaults to [defaultOtpMinutes].
  static int expiresInMinutesForRequest(dynamic data) {
    if (data is! Map) return defaultOtpMinutes;
    final parsed = _parseMinutes(data['expires_in_minutes']);
    return parsed ?? defaultOtpMinutes;
  }

  /// Step 2b: non-map body → 15; missing field on a map → null (leave timer).
  static int? expiresInMinutesForResend(dynamic data) {
    if (data is! Map) return defaultOtpMinutes;
    if (!data.containsKey('expires_in_minutes')) return null;
    return _parseMinutes(data['expires_in_minutes']);
  }

  static int? _parseMinutes(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString());
  }
}
