import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';
import 'package:hudhud_delivery_driver/core/utils/json_parse.dart';

/// Safe OTP state from driver delivery APIs. Never stores plaintext code or hash.
class DeliveryOtp {
  const DeliveryOtp({
    this.required = false,
    this.generated = false,
    this.verified = false,
    this.digitLength = 6,
    this.channel,
    this.attempts = 0,
    this.maxAttempts = 5,
    this.attemptsRemaining = 5,
    this.locked = false,
    this.supportRequired = false,
    this.validUntilDeliveryCloses = true,
  });

  static const defaultDigitLength = 6;

  final bool required;
  final bool generated;
  final bool verified;
  final int digitLength;
  final String? channel;
  final int attempts;
  final int maxAttempts;
  final int attemptsRemaining;
  final bool locked;
  final bool supportRequired;
  final bool validUntilDeliveryCloses;

  bool get isPending => required && !verified && !locked;

  static DeliveryOtp? fromJson(dynamic raw) {
    final map = JsonParse.toMap(raw);
    if (map == null) return null;

    final digitLength =
        JsonParse.toInt(map['digit_length']) ?? defaultDigitLength;

    return DeliveryOtp(
      required: JsonParse.toBool(map['required']),
      generated: JsonParse.toBool(map['generated']),
      verified: JsonParse.toBool(map['verified']),
      digitLength: digitLength.clamp(4, 8),
      channel: map['channel']?.toString(),
      attempts: JsonParse.toInt(map['attempts']) ?? 0,
      maxAttempts: JsonParse.toInt(map['max_attempts']) ?? 5,
      attemptsRemaining: JsonParse.toInt(map['attempts_remaining']) ?? 5,
      locked: JsonParse.toBool(map['locked']),
      supportRequired: JsonParse.toBool(map['support_required']),
      validUntilDeliveryCloses:
          JsonParse.toBool(map['valid_until_delivery_closes'], defaultValue: true),
    );
  }

  /// Reads nested `delivery.otp` or top-level `otp` from detail/accept payloads.
  static DeliveryOtp? fromDelivery(dynamic delivery) {
    final map = JsonParse.toMap(delivery);
    if (map == null) return null;

    final nested = fromJson(map['otp']);
    if (nested != null) return nested;

    if (map['otp_required'] == true || map['identity_verification_required'] == true) {
      return DeliveryOtp(
        required: true,
        verified: map['otp_verified'] == true,
        digitLength: JsonParse.toInt(map['otp_digit_length']) ?? defaultDigitLength,
      );
    }

    return null;
  }

  static bool otpRequiredForDelivery(dynamic delivery) {
    final map = JsonParse.toMap(delivery);
    if (map == null) return false;
    if (map['identity_verification_required'] == true) return true;
    if (map['otp_required'] == true) return true;
    final otp = fromJson(map['otp']);
    return otp?.required == true && otp?.verified != true;
  }
}

/// OTP SMS outcome on accept (`otp_delivery` block).
class DeliveryOtpDeliveryResult {
  const DeliveryOtpDeliveryResult({
    this.success = false,
    this.code,
    this.message,
    this.otp,
  });

  final bool success;
  final String? code;
  final String? message;
  final DeliveryOtp? otp;

  static const sentCode = 'OTP_SENT';
  static const smsFailedCode = 'OTP_SMS_FAILED';
  static const deferredCode = 'OTP_DELIVERY_DEFERRED';

  bool get smsNeedsRetry =>
      code == smsFailedCode || code == deferredCode;

  static DeliveryOtpDeliveryResult? fromAcceptResponse(dynamic raw) {
    final map = JsonParse.toMap(raw);
    if (map == null) return null;

    final otpDelivery = JsonParse.toMap(map['otp_delivery']);
    if (otpDelivery == null) return null;

    return DeliveryOtpDeliveryResult(
      success: JsonParse.toBool(otpDelivery['success']),
      code: otpDelivery['code']?.toString(),
      message: otpDelivery['message']?.toString(),
      otp: DeliveryOtp.fromJson(otpDelivery['otp']),
    );
  }
}

/// Parsed OTP-related API error details.
class DeliveryOtpError {
  DeliveryOtpError({
    required this.httpStatus,
    required this.code,
    required this.message,
    this.attemptsRemaining,
    this.retryAfterSeconds,
    this.supportRequired = false,
  });

  final int httpStatus;
  final String code;
  final String message;
  final int? attemptsRemaining;
  final int? retryAfterSeconds;
  final bool supportRequired;

  static const incorrectCode = 'OTP_INCORRECT';
  static const attemptsExceededCode = 'OTP_ATTEMPTS_EXCEEDED';
  static const resendCooldownCode = 'OTP_RESEND_COOLDOWN';
  static const smsFailedCode = 'OTP_SMS_FAILED';
  static const notAvailableCode = 'OTP_NOT_AVAILABLE';
  static const phoneMissingCode = 'CUSTOMER_PHONE_MISSING';
  static const requiredCode = 'OTP_REQUIRED';
  static const notGeneratedCode = 'OTP_NOT_GENERATED';

  bool get isIncorrect => code == incorrectCode;
  bool get isLockedOut => code == attemptsExceededCode;
  bool get isResendCooldown => code == resendCooldownCode;

  static DeliveryOtpError? fromException(AppException error) {
    final details = error.details;
    Map<String, dynamic>? map;
    if (details is Map<String, dynamic>) {
      map = details;
    } else if (details is Map) {
      map = Map<String, dynamic>.from(details);
    }

    final code = _readCode(error, map);
    if (code == null) return null;

    final otpCodes = {
      incorrectCode,
      attemptsExceededCode,
      resendCooldownCode,
      smsFailedCode,
      notAvailableCode,
      phoneMissingCode,
      requiredCode,
      notGeneratedCode,
      'OTP_VERIFICATION_NOT_READY',
      'OTP_DELIVERY_CLOSED',
      'OTP_EXPIRED',
      'OTP_RESENT',
      'OTP_VERIFIED',
    };
    if (!otpCodes.contains(code)) return null;

    final status = int.tryParse(error.code ?? '') ??
        (error is LockedException
            ? 423
            : error is TooManyRequestsException
                ? 429
                : 422);

    return DeliveryOtpError(
      httpStatus: status,
      code: code,
      message: error.message,
      attemptsRemaining: JsonParse.toInt(map?['attempts_remaining']),
      retryAfterSeconds: JsonParse.toInt(map?['retry_after_seconds']),
      supportRequired: JsonParse.toBool(map?['support_required']),
    );
  }

  static String? _readCode(AppException error, Map<String, dynamic>? map) {
    if (error.code != null &&
        error.code!.isNotEmpty &&
        error.code != '422' &&
        error.code != '423' &&
        error.code != '429') {
      return error.code;
    }
    final bodyCode = map?['code']?.toString();
    if (bodyCode != null && bodyCode.isNotEmpty) return bodyCode;
    return null;
  }
}
