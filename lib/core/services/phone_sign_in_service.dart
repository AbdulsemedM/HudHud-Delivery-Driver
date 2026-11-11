import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../constants/application_status.dart';
import '../services/api_service.dart';
import '../services/secure_storage_service.dart';
import '../utils/ethiopian_phone_number.dart';

/// Typed failure from the passwordless sign-in endpoints.
///
/// [code] mirrors the backend's `code` field verbatim, because the UI must
/// branch on it. Only `CODE_INVALID` should keep the rider on the code screen;
/// everything else needs a fresh code or a different action entirely.
class PhoneSignInException implements Exception {
  PhoneSignInException(
    this.message, {
    required this.code,
    this.statusCode,
    this.retryAfterSeconds,
  });

  final String message;
  final String code;
  final int? statusCode;
  final int? retryAfterSeconds;

  /// The only failure recoverable without requesting a new code.
  bool get isRetryableOnCodeScreen => code == 'CODE_INVALID';

  /// The number exists but is not a rider account. Signing in never promotes
  /// anyone — they must go through rider onboarding, which is a separate flow.
  bool get isNotARider => code == 'NOT_A_RIDER';

  @override
  String toString() => message;
}

class PhoneSignInRequestResult {
  const PhoneSignInRequestResult({
    required this.phone,
    required this.expiresInSeconds,
    required this.resendAfterSeconds,
    required this.message,
  });

  /// Canonical number. Send this SAME value to verify — a differently
  /// formatted one fails with NO_CODE.
  final String phone;

  final int expiresInSeconds;

  /// Drive the resend countdown from this rather than a hardcoded 60, so the
  /// app and server cannot disagree about when a resend is allowed.
  final int resendAfterSeconds;

  final String message;
}

class PhoneSignInVerifyResult {
  const PhoneSignInVerifyResult({
    required this.token,
    required this.user,
    required this.created,
    required this.onboardingRequired,
  });

  final String token;
  final Map<String, dynamic> user;

  /// True when this phone had no account and one was just created.
  final bool created;

  /// The rider is SIGNED IN with a valid token but cannot accept jobs until an
  /// admin approves onboarding. Never treat this as a login failure — route to
  /// the onboarding flow (documents, vehicle, licence) instead.
  final bool onboardingRequired;
}

/// Passwordless phone sign-in for the driver app.
///
/// Uses `http.post` with [ApiConfig.defaultHeaders] directly, exactly as
/// `ApiService.login` does, rather than going through `ApiService`'s
/// authenticated request path. These endpoints are public, and that path would
/// attach a stale Bearer from a previous session to a call whose entire purpose
/// is to establish a new one.
class PhoneSignInService {
  PhoneSignInService({SecureStorageService? secureStorage})
      : _secureStorage = secureStorage ?? SecureStorageService();

  final SecureStorageService _secureStorage;

  /// The driver app always identifies as `rider`, which selects the backend's
  /// rider rules: a new number is created PENDING_VERIFICATION, and a number
  /// registered as anything else is refused outright.
  static const String _app = 'rider';

  /// Ask for a code.
  ///
  /// The backend returns an identical 200 whether or not the number has an
  /// account — deliberately, so the endpoint cannot be used to discover who is
  /// registered. Do not infer "new rider" from this call;
  /// [PhoneSignInVerifyResult.created] is the only honest signal.
  Future<PhoneSignInRequestResult> requestCode(String inputPhone) async {
    final canonical = EthiopianPhoneNumber.tryNormalize(inputPhone);
    if (canonical == null) {
      throw PhoneSignInException(
        'That does not look like an Ethiopian mobile number.',
        code: 'INVALID_PHONE',
      );
    }

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.phoneSignInRequestUrl),
        headers: ApiConfig.defaultHeaders,
        body: jsonEncode({'phone': canonical, 'app': _app}),
      );
      final data = _decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return PhoneSignInRequestResult(
          phone: canonical,
          expiresInSeconds: _parseInt(data['expires_in']) ?? 300,
          resendAfterSeconds: _parseInt(data['resend_after']) ?? 60,
          message: data['message']?.toString() ??
              'If that number can receive SMS, a code is on its way.',
        );
      }

      throw PhoneSignInException(
        data['message']?.toString() ??
            'Could not send a code. Please try again.',
        code: data['code']?.toString() ?? 'PHONE_SIGNIN_REQUEST_FAILED',
        statusCode: response.statusCode,
        retryAfterSeconds: _parseInt(data['retry_after']),
      );
    } on PhoneSignInException {
      rethrow;
    } catch (_) {
      throw PhoneSignInException(
        'Could not reach HudHud. Check your connection and try again.',
        code: 'PHONE_SIGNIN_NETWORK',
      );
    }
  }

  /// Verify a code and establish the session.
  ///
  /// [phone] must be the SAME value returned by [requestCode].
  ///
  /// The token and user are persisted before this returns, through the same
  /// storage path as password login, so the rest of the app cannot tell how
  /// the session arrived.
  Future<PhoneSignInVerifyResult> verifyCode({
    required String phone,
    required String code,
    String? deviceName,
  }) async {
    final canonical = EthiopianPhoneNumber.tryNormalize(phone);
    if (canonical == null) {
      throw PhoneSignInException(
        'That does not look like an Ethiopian mobile number.',
        code: 'INVALID_PHONE',
      );
    }

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.phoneSignInVerifyUrl),
        headers: ApiConfig.defaultHeaders,
        body: jsonEncode({
          'phone': canonical,
          'code': code.trim(),
          'app': _app,
          if (deviceName != null && deviceName.trim().isNotEmpty)
            'device_name': deviceName.trim(),
        }),
      );
      final data = _decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final token = data['token']?.toString();
        final userRaw = data['user'];

        if (token == null || token.isEmpty || userRaw is! Map) {
          throw PhoneSignInException(
            'Invalid sign-in response.',
            code: 'PHONE_SIGNIN_INVALID_RESPONSE',
            statusCode: response.statusCode,
          );
        }

        final user = Map<String, dynamic>.from(userRaw);

        // Persist before returning: whatever the caller does next will be an
        // authenticated request, and a half-established session is worse than
        // none at all.
        await _secureStorage.saveToken(token);
        await ApiService.persistLoginUser(
          user,
          secureStorage: _secureStorage,
        );

        // Same status bookkeeping as password login, so the post-login gate
        // (pending / suspended screens) behaves identically. A rider the
        // backend flags for onboarding is pending even if no status came back.
        final onboardingRequired = data['onboarding_required'] == true;

        // `driver` distinguishes a rider who still has to apply from one who
        // is waiting on a decision; `onboarding_required` alone cannot, and
        // treating both as pending is what sent new riders to the Application
        // Pending screen without ever being asked for an application.
        final driver = data['driver'] is Map
            ? Map<String, dynamic>.from(data['driver'] as Map)
            : null;
        final status = ApplicationStatus.fromDriverBlock(driver) ??
            ApplicationStatus.fromLoginResponse(data) ??
            (onboardingRequired ? ApplicationStatus.pending : null);
        if (status != null) {
          await _secureStorage.saveApplicationStatus(status);
        }
        await _secureStorage.saveStatusReason(
          ApplicationStatus.reasonFrom(data),
        );

        return PhoneSignInVerifyResult(
          token: token,
          user: user,
          created: data['created'] == true,
          onboardingRequired: onboardingRequired,
        );
      }

      throw PhoneSignInException(
        data['message']?.toString() ??
            'Could not sign you in. Please try again.',
        code: data['code']?.toString() ?? 'PHONE_SIGNIN_VERIFY_FAILED',
        statusCode: response.statusCode,
        retryAfterSeconds: _parseInt(data['retry_after']),
      );
    } on PhoneSignInException {
      rethrow;
    } catch (_) {
      throw PhoneSignInException(
        'Could not reach HudHud. Check your connection and try again.',
        code: 'PHONE_SIGNIN_NETWORK',
      );
    }
  }

  // ------------------------------------------------------------------ parts

  Map<String, dynamic> _decode(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // A non-JSON body (an HTML error page from a proxy, say) is reported by
      // the caller as a generic failure rather than crashing the sign-in.
    }
    return <String, dynamic>{};
  }

  int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
