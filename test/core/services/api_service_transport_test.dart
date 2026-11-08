import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hudhud_delivery_driver/core/config/api_config.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/services/secure_storage_service.dart';
import 'package:hudhud_delivery_driver/core/utils/driver_error_messages.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';
import 'package:hudhud_delivery_driver/core/utils/logger.dart';

/// No platform channel: the tests never sign in.
class _NoTokenStorage extends SecureStorageService {
  _NoTokenStorage() : super(secureStorage: const FlutterSecureStorage());

  @override
  Future<String?> getToken() async => null;
}

ApiService _api(MockClient client) => ApiService(
      client: client,
      secureStorage: _NoTokenStorage(),
      logger: AppLogger(),
    );

http.Response _json(int status, Map<String, dynamic> body) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

void main() {
  test('403 DRIVER_CITY_MISMATCH keeps its code', () async {
    final api = _api(MockClient((_) async => _json(403, {
          'success': false,
          'code': 'DRIVER_CITY_MISMATCH',
          'message': 'This request is in Hargeisa. You can only take requests in Addis Ababa.',
        })));
    await expectLater(
      api.acceptFoodOrder(41),
      throwsA(isA<ForbiddenException>()
          .having((e) => e.code, 'code', 'DRIVER_CITY_MISMATCH')),
    );
  });

  test('409 DISPATCH_OFFER_REQUIRED on the legacy accept', () async {
    late http.Request sent;
    final api = _api(MockClient((request) async {
      sent = request;
      return _json(409, {
        'success': false,
        'code': 'DISPATCH_OFFER_REQUIRED',
        'message': 'HudHud assigns this order. Wait for an order offer on your screen.',
      });
    }));
    Object? error;
    try {
      await api.acceptFoodOrder(41, pickupOtp: '1234');
    } catch (e) {
      error = e;
    }
    expect(sent.url.path, endsWith(ApiConfig.driverOrderAcceptEndpoint(41)));
    expect(jsonDecode(sent.body), {'pickup_otp': '1234'});
    expect(DriverErrorMessages.codeOf(error!), 'DISPATCH_OFFER_REQUIRED');
  });

  test('503 EXCHANGE_RATE_MISSING is a retryable ServerException', () async {
    final api = _api(MockClient((_) async => _json(503, {
          'success': false,
          'code': 'EXCHANGE_RATE_MISSING',
          'message': 'This order cannot be settled right now.',
          'retryable': true,
        })));
    Object? error;
    try {
      await api.completeFoodOrder(41);
    } catch (e) {
      error = e;
    }
    expect(error, isA<ServerException>());
    expect(DriverErrorMessages.isRetryable(error!), isTrue);
    expect(DriverErrorMessages.keyFor(error), 'errors.exchange_rate_missing');
  });

  test('a dropped connection becomes a retryable NetworkException', () async {
    final api = _api(MockClient((_) async {
      throw http.ClientException('Connection closed before full header');
    }));
    Object? error;
    try {
      await api.completeFoodOrder(41);
    } catch (e) {
      error = e;
    }
    expect(error, isA<NetworkException>());
    expect(DriverErrorMessages.isRetryable(error!), isTrue);
  });

  test('cancel uses the real route with a reason', () async {
    late http.Request sent;
    final api = _api(MockClient((request) async {
      sent = request;
      return _json(200, {'success': true});
    }));
    await api.cancelDeliveryRequest(77);
    expect(sent.url.path, endsWith('/driver/services/delivery/cancel'));
    final body = jsonDecode(sent.body) as Map<String, dynamic>;
    expect(body['delivery_id'], 77);
    expect(body['cancellation_reason'], isNotEmpty);
    expect(body['cancelled_by'], 'driver');
  });

  test('requests have an upper time bound', () {
    expect(ApiService.defaultRequestTimeout, const Duration(seconds: 30));
    expect(DriverErrorMessages.isRetryable(TimeoutException('x')), isTrue);
  });
}
