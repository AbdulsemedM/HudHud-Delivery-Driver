import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';
import 'package:hudhud_delivery_driver/core/utils/json_parse.dart';

/// One place that turns rider-facing API errors into clear, localized text.
///
/// The API answers with `{code, message, retryable?}`; [ApiService] keeps the
/// code on [AppException.code] (or in [AppException.details]). Screens call
/// [message] for the snackbar text and [isRetryable] to decide whether to
/// offer "Try again" (completion endpoints are idempotent server side, so a
/// retry after a lost response is safe).
class DriverErrorMessages {
  DriverErrorMessages._();

  /// Codes for transport problems raised by the app itself.
  static const String networkCode = 'NETWORK';
  static const String timeoutCode = 'TIMEOUT';

  // Server codes the rider app handles explicitly.
  static const String exchangeRateMissing = 'EXCHANGE_RATE_MISSING';
  static const String cityMismatch = 'DRIVER_CITY_MISMATCH';
  static const String dispatchOfferRequired = 'DISPATCH_OFFER_REQUIRED';
  static const String withdrawalsOnHold = 'WITHDRAWALS_ON_HOLD';
  static const String parcelStopsPending = 'PARCEL_STOPS_PENDING';
  static const String pickupCashRequired = 'PICKUP_CASH_COLLECTION_REQUIRED';
  static const String deliveryPhotoRequired = 'DELIVERY_PHOTO_REQUIRED';
  static const String parcelStopClosed = 'PARCEL_STOP_CLOSED';
  static const String parcelNotPickedUp = 'PARCEL_NOT_PICKED_UP';

  /// Server code → translation key. Keys live in assets/lang/{en,ar}.json.
  static const Map<String, String> codeKeys = {
    exchangeRateMissing: 'errors.exchange_rate_missing',
    cityMismatch: 'errors.city_mismatch',
    dispatchOfferRequired: 'errors.dispatch_offer_required',
    'DISPATCH_OFFER_EXPIRED': 'dispatch_offer.error_expired',
    'DISPATCH_OFFER_CLOSED': 'errors.job_gone',
    'DISPATCH_OFFER_NOT_FOUND': 'errors.job_gone',
    'ORDER_ALREADY_ASSIGNED': 'dispatch_offer.error_gone',
    'ORDER_NO_LONGER_AVAILABLE': 'errors.job_gone',
    'DRIVER_OFFER_NOT_ACTIVE': 'errors.job_gone',
    'DELIVERY_OFFER_NOT_ACTIVE': 'errors.job_gone',
    'DELIVERY_OFFER_UNAVAILABLE': 'errors.job_gone',
    'DRIVER_NOT_ELIGIBLE': 'errors.not_eligible',
    'LOW_WALLET_BALANCE': 'dispatch_offer.error_low_balance',
    'DRIVER_WALLET_INSUFFICIENT_FOR_COD_SETTLEMENT':
        'errors.cod_settlement_balance',
    'DRIVER_ACTIVE_JOB_CONFLICT': 'errors.active_job',
    'INVALID_PICKUP_OTP': 'dispatch_offer.pickup_code_invalid',
    'INVALID_DELIVERY_OTP': 'gift.code_invalid',
    'DELIVERY_OTP_LOCKED': 'gift.code_locked',
    // OTP_INCORRECT is left to the server text: it carries the attempts left.
    'OTP_ATTEMPTS_EXCEEDED': 'parcel.stop_code_locked',
    'OTP_REQUIRED': 'errors.handover_code_required',
    parcelStopsPending: 'errors.parcel_stops_pending',
    'PARCEL_USE_STOP_HANDOVER': 'errors.parcel_use_stops',
    'PARCEL_USE_STOP_FAIL': 'errors.parcel_use_stops',
    'PARCEL_STOP_OUT_OF_ORDER': 'errors.parcel_stop_out_of_order',
    parcelStopClosed: 'errors.status_changed',
    deliveryPhotoRequired: 'errors.delivery_photo_required',
    pickupCashRequired: 'errors.pickup_cash_required',
    'PROOF_LIMIT_REACHED': 'errors.proof_limit',
    'PROOF_NOT_ALLOWED_NOW': 'errors.proof_not_now',
    'PROOF_STORAGE_UNAVAILABLE': 'errors.proof_unavailable',
    'PARCEL_FAIL_NOT_ALLOWED': 'errors.parcel_fail_not_allowed',
    'PARCEL_RETURN_NOT_ALLOWED': 'errors.parcel_return_not_allowed',
    'COLLECTION_REQUIRED': 'errors.collection_required',
    withdrawalsOnHold: 'errors.withdrawals_on_hold',
    'POST_PICKUP_EXCEPTION_REQUIRES_SUPPORT': 'errors.cancel_needs_support',
    'INVALID_ORDER_TRANSITION': 'errors.status_changed',
    'INVALID_DELIVERY_TRANSITION': 'errors.status_changed',
    'DELIVERY_TERMINAL_STATE': 'errors.status_changed',
    'UNAUTHENTICATED': 'errors.session_expired',
    networkCode: 'errors.network',
    timeoutCode: 'errors.timeout',
  };

  /// The API error code of [error], from the body (`details.code`) first,
  /// then [AppException.code]. Transport failures map to [networkCode] /
  /// [timeoutCode]. Null when unknown.
  static String? codeOf(Object error) {
    if (error is TimeoutException) return timeoutCode;
    if (error is SocketException) return networkCode;
    if (error is! AppException) return null;
    final details = JsonParse.toMap(error.details);
    final fromBody = details?['code']?.toString().trim();
    if (fromBody != null && fromBody.isNotEmpty) return fromBody;
    final errorCode = details?['error_code']?.toString().trim();
    if (errorCode != null && errorCode.isNotEmpty) return errorCode;
    final code = error.code?.trim();
    if (code != null && code.isNotEmpty) return code;
    if (error is NetworkException) return networkCode;
    return null;
  }

  static bool hasCode(Object error, String code) => codeOf(error) == code;

  /// Translation key for [error], or null when the server message (or the
  /// caller's fallback) should be shown instead.
  static String? keyFor(Object error) {
    final code = codeOf(error);
    final mapped = code == null ? null : codeKeys[code];
    if (mapped != null) return mapped;
    if (error is NetworkException) return 'errors.network';
    if (error is TimeoutException || error is SocketException) {
      return 'errors.network';
    }
    if (error is UnauthorizedException) return 'errors.session_expired';
    if (error is TooManyRequestsException) return 'errors.too_many';
    if (error is ServerException) return 'errors.server';
    return null;
  }

  /// True when the same request can simply be sent again: transport
  /// failures, 5xx, `retryable: true`, or a missing exchange rate.
  static bool isRetryable(Object error) {
    if (error is TimeoutException || error is SocketException) return true;
    if (error is NetworkException || error is ServerException) return true;
    if (error is! AppException) return false;
    final details = JsonParse.toMap(error.details);
    if (JsonParse.toBool(details?['retryable'])) return true;
    return codeOf(error) == exchangeRateMissing;
  }

  /// Localized text for [error]. Falls back to the server's `message`
  /// (already human readable), then to [fallbackKey].
  static String message(
    Object error, {
    String fallbackKey = 'errors.generic',
  }) {
    final key = keyFor(error);
    if (key != null) return key.tr();
    final server = serverMessage(error);
    if (server != null) return server;
    return fallbackKey.tr();
  }

  /// The server's message when it is safe to show (not a raw transport or
  /// framework error).
  static String? serverMessage(Object error) {
    if (error is! AppException) return null;
    final text = error.message.trim();
    if (text.isEmpty) return null;
    const technical = [
      'Failed to complete request',
      'Request failed with status',
      'Server error',
      'Bad request',
      'Not found',
      'Forbidden',
      'Invalid request',
    ];
    for (final prefix in technical) {
      if (text.startsWith(prefix)) return null;
    }
    return text;
  }
}
