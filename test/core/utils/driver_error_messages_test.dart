import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/utils/driver_error_messages.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';

Map<String, dynamic> _flatten(Map<String, dynamic> map, [String prefix = '']) {
  final out = <String, dynamic>{};
  map.forEach((key, value) {
    if (value is Map<String, dynamic>) {
      out.addAll(_flatten(value, '$prefix$key.'));
    } else {
      out['$prefix$key'] = value;
    }
  });
  return out;
}

Map<String, dynamic> _lang(String code) => _flatten(
      jsonDecode(File('assets/lang/$code.json').readAsStringSync())
          as Map<String, dynamic>,
    );

void main() {
  group('DriverErrorMessages.codeOf', () {
    test('prefers the body code over the HTTP status code', () {
      final error = ForbiddenException(
        'This request is in Hargeisa.',
        details: {'code': 'DRIVER_CITY_MISMATCH'},
      );
      expect(DriverErrorMessages.codeOf(error), 'DRIVER_CITY_MISMATCH');
    });

    test('reads error_code used by wallet routes', () {
      final error = ApiException('x', details: {'error_code': 'IDEMPOTENCY_CONFLICT'});
      expect(DriverErrorMessages.codeOf(error), 'IDEMPOTENCY_CONFLICT');
    });

    test('maps transport failures', () {
      expect(DriverErrorMessages.codeOf(TimeoutException('t')), 'TIMEOUT');
      expect(
        DriverErrorMessages.codeOf(const SocketException('down')),
        'NETWORK',
      );
      expect(DriverErrorMessages.codeOf(NetworkException('x')), 'NETWORK');
    });
  });

  group('DriverErrorMessages.keyFor', () {
    final cases = <String, String>{
      'DISPATCH_OFFER_REQUIRED': 'errors.dispatch_offer_required',
      'DRIVER_CITY_MISMATCH': 'errors.city_mismatch',
      'INVALID_DELIVERY_OTP': 'gift.code_invalid',
      'DELIVERY_OTP_LOCKED': 'gift.code_locked',
      'PARCEL_STOPS_PENDING': 'errors.parcel_stops_pending',
      'PICKUP_CASH_COLLECTION_REQUIRED': 'errors.pickup_cash_required',
      'EXCHANGE_RATE_MISSING': 'errors.exchange_rate_missing',
      'WITHDRAWALS_ON_HOLD': 'errors.withdrawals_on_hold',
      'DELIVERY_PHOTO_REQUIRED': 'errors.delivery_photo_required',
      'INVALID_PICKUP_OTP': 'dispatch_offer.pickup_code_invalid',
      'LOW_WALLET_BALANCE': 'dispatch_offer.error_low_balance',
      'DRIVER_ACTIVE_JOB_CONFLICT': 'errors.active_job',
    };
    cases.forEach((code, key) {
      test('$code → $key', () {
        expect(
          DriverErrorMessages.keyFor(ApiException('m', details: {'code': code})),
          key,
        );
      });
    });

    test('falls back by exception type', () {
      expect(DriverErrorMessages.keyFor(ServerException('Server error', code: '500')),
          'errors.server');
      expect(DriverErrorMessages.keyFor(TooManyRequestsException('x', code: '429')),
          'errors.too_many');
      expect(DriverErrorMessages.keyFor(BadRequestException('Readable text')), isNull);
    });
  });

  group('DriverErrorMessages.isRetryable', () {
    test('503 EXCHANGE_RATE_MISSING, network and timeouts are retryable', () {
      expect(
        DriverErrorMessages.isRetryable(ServerException(
          'rate missing',
          code: 'EXCHANGE_RATE_MISSING',
          details: {'code': 'EXCHANGE_RATE_MISSING', 'retryable': true},
        )),
        isTrue,
      );
      expect(DriverErrorMessages.isRetryable(NetworkException('x', code: 'TIMEOUT')),
          isTrue);
      expect(DriverErrorMessages.isRetryable(TimeoutException('t')), isTrue);
    });

    test('retryable flag on a 422 is honoured', () {
      expect(
        DriverErrorMessages.isRetryable(BadRequestException(
          'Top up',
          code: 'DRIVER_WALLET_INSUFFICIENT_FOR_COD_SETTLEMENT',
          details: {'retryable': true},
        )),
        isTrue,
      );
    });

    test('validation and OTP errors are not retryable', () {
      expect(
        DriverErrorMessages.isRetryable(
            BadRequestException('x', details: {'code': 'INVALID_DELIVERY_OTP'})),
        isFalse,
      );
      expect(DriverErrorMessages.isRetryable(StateError('bug')), isFalse);
    });
  });

  test('serverMessage hides technical fallbacks only', () {
    expect(DriverErrorMessages.serverMessage(ServerException('Server error')), isNull);
    expect(
      DriverErrorMessages.serverMessage(
          ApiException('Failed to complete request: FormatException')),
      isNull,
    );
    expect(
      DriverErrorMessages.serverMessage(BadRequestException('Serve stop 2 first.')),
      'Serve stop 2 first.',
    );
  });

  test('every mapped key exists in en.json and ar.json', () {
    final en = _lang('en');
    final ar = _lang('ar');
    final keys = {
      ...DriverErrorMessages.codeKeys.values,
      'errors.generic',
      'errors.network',
      'errors.server',
      'errors.too_many',
      'errors.session_expired',
      'errors.finish_before_offline',
    };
    for (final key in keys) {
      expect(en.containsKey(key), isTrue, reason: 'en.json missing $key');
      expect(ar.containsKey(key), isTrue, reason: 'ar.json missing $key');
    }
  });
}
