import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:hudhud_delivery_driver/core/config/app_config.dart';
import 'package:hudhud_delivery_driver/core/config/api_config.dart';
import 'package:hudhud_delivery_driver/core/services/secure_storage_service.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';
import 'package:hudhud_delivery_driver/core/utils/logger.dart';
import 'package:hudhud_delivery_driver/core/utils/device_utils.dart';

enum RequestMethod { get, post, put, delete, patch }

class ApiService {
  final http.Client _client;
  final SecureStorageService _secureStorage;
  final AppLogger _logger;

  ApiService({
    http.Client? client,
    required SecureStorageService secureStorage,
    required AppLogger logger,
  })  : _client = client ?? http.Client(),
        _secureStorage = secureStorage,
        _logger = logger;

  Future<Map<String, String>> _getHeaders() async {
    final token = await _secureStorage.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> request({
    required String endpoint,
    required RequestMethod method,
    Map<String, dynamic>? queryParams,
    dynamic body,
    bool requiresAuth = true,
  }) async {
    final stopwatch = Stopwatch()..start();
    final url = Uri.parse('${AppConfig.baseUrl}$endpoint').replace(
      queryParameters: queryParams,
    );

    final headers = await _getHeaders();
    http.Response response;

    try {
      // Enhanced API request logging
      _logger.logApiRequest(
        method: method.name.toUpperCase(),
        endpoint: url.toString(),
        headers: headers,
        body: body,
      );

      switch (method) {
        case RequestMethod.get:
          response = await _client.get(url, headers: headers);
          break;
        case RequestMethod.post:
          response = await _client.post(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case RequestMethod.put:
          response = await _client.put(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case RequestMethod.delete:
          response = await _client.delete(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case RequestMethod.patch:
          response = await _client.patch(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
      }

      stopwatch.stop();

      // Enhanced API response logging
      dynamic responseBody;
      try {
        responseBody = jsonDecode(response.body);
      } catch (e) {
        responseBody = response.body;
      }

      _logger.logApiResponse(
        method: method.name.toUpperCase(),
        endpoint: url.toString(),
        statusCode: response.statusCode,
        headers: response.headers,
        responseBody: responseBody,
        duration: stopwatch.elapsed,
      );

      return _handleResponse(response);
    } on SocketException catch (e, stackTrace) {
      stopwatch.stop();
      _logger.logApiError(
        method: method.name.toUpperCase(),
        endpoint: url.toString(),
        error: 'No Internet connection',
        stackTrace: stackTrace,
        duration: stopwatch.elapsed,
      );
      throw NetworkException('No Internet connection');
    } catch (e, stackTrace) {
      stopwatch.stop();
      _logger.logApiError(
        method: method.name.toUpperCase(),
        endpoint: url.toString(),
        error: e,
        stackTrace: stackTrace,
        duration: stopwatch.elapsed,
      );
      throw ApiException('Failed to complete request: $e');
    }
  }

  dynamic _handleResponse(http.Response response) {
    switch (response.statusCode) {
      case 200:
      case 201:
        if (response.body.isEmpty) return null;
        return jsonDecode(response.body);
      case 400:
        throw BadRequestException(
          response.body.isNotEmpty
              ? jsonDecode(response.body)['message'] ?? 'Bad request'
              : 'Bad request',
        );
      case 401:
        throw UnauthorizedException(
          response.body.isNotEmpty
              ? jsonDecode(response.body)['message'] ?? 'Unauthorized'
              : 'Unauthorized',
        );
      case 403:
        throw ForbiddenException(
          response.body.isNotEmpty
              ? jsonDecode(response.body)['message'] ?? 'Forbidden'
              : 'Forbidden',
        );
      case 404:
        throw NotFoundException(
          response.body.isNotEmpty
              ? jsonDecode(response.body)['message'] ?? 'Not found'
              : 'Not found',
        );
      case 500:
      case 502:
      case 503:
        throw ServerException(
          response.body.isNotEmpty
              ? jsonDecode(response.body)['message'] ?? 'Server error'
              : 'Server error',
        );
      default:
        throw ApiException(
          'Request failed with status: ${response.statusCode}',
        );
    }
  }

  // Convenience methods
  Future<dynamic> get(
    String endpoint, {
    Map<String, dynamic>? queryParams,
    bool requiresAuth = true,
  }) async {
    return request(
      endpoint: endpoint,
      method: RequestMethod.get,
      queryParams: queryParams,
      requiresAuth: requiresAuth,
    );
  }

  Future<dynamic> post(
    String endpoint, {
    dynamic body,
    Map<String, dynamic>? queryParams,
    bool requiresAuth = true,
  }) async {
    return request(
      endpoint: endpoint,
      method: RequestMethod.post,
      body: body,
      queryParams: queryParams,
      requiresAuth: requiresAuth,
    );
  }

  Future<dynamic> put(
    String endpoint, {
    dynamic body,
    Map<String, dynamic>? queryParams,
    bool requiresAuth = true,
  }) async {
    return request(
      endpoint: endpoint,
      method: RequestMethod.put,
      body: body,
      queryParams: queryParams,
      requiresAuth: requiresAuth,
    );
  }

  Future<dynamic> delete(
    String endpoint, {
    dynamic body,
    Map<String, dynamic>? queryParams,
    bool requiresAuth = true,
  }) async {
    return request(
      endpoint: endpoint,
      method: RequestMethod.delete,
      body: body,
      queryParams: queryParams,
      requiresAuth: requiresAuth,
    );
  }

  Future<dynamic> patch(
    String endpoint, {
    dynamic body,
    Map<String, dynamic>? queryParams,
    bool requiresAuth = true,
  }) async {
    return request(
      endpoint: endpoint,
      method: RequestMethod.patch,
      body: body,
      queryParams: queryParams,
      requiresAuth: requiresAuth,
    );
  }

  // Driver Registration Methods
  static Future<Map<String, dynamic>> registerDriver({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirmation,
    String? deviceToken,
  }) async {
    final logger = AppLogger();
    final stopwatch = Stopwatch()..start();
    
    try {
      // Get device ID if no device token provided
      final finalDeviceToken = deviceToken ?? await DeviceUtils.getDeviceId() ?? 'unknown-device';
      
      final body = {
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'type': 'driver',
        'device_token': finalDeviceToken,
      };

      // Log API request
      logger.logApiRequest(
        method: 'POST',
        endpoint: ApiConfig.registerUrl,
        headers: ApiConfig.defaultHeaders,
        body: body,
      );

      final response = await http.post(
        Uri.parse(ApiConfig.registerUrl),
        headers: ApiConfig.defaultHeaders,
        body: jsonEncode(body),
      );

      stopwatch.stop();
      final responseData = jsonDecode(response.body);

      // Log API response
      logger.logApiResponse(
        method: 'POST',
        endpoint: ApiConfig.registerUrl,
        statusCode: response.statusCode,
        headers: response.headers,
        responseBody: responseData,
        duration: stopwatch.elapsed,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': responseData,
          'message': 'Registration successful',
        };
      } else {
        return {
          'success': false,
          'data': responseData,
          'message': responseData['message'] ?? 'Registration failed',
        };
      }
    } catch (e, stackTrace) {
      stopwatch.stop();
      
      // Log API error
      logger.logApiError(
        method: 'POST',
        endpoint: ApiConfig.registerUrl,
        error: e,
        stackTrace: stackTrace,
        duration: stopwatch.elapsed,
      );
      
      return {
        'success': false,
        'data': null,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> loginDriver({
    required String email,
    required String password,
    String? deviceToken,
  }) async {
    final logger = AppLogger();
    final stopwatch = Stopwatch()..start();
    
    try {
      // Get device ID if no device token provided
      final finalDeviceToken = deviceToken ?? await DeviceUtils.getDeviceId() ?? 'unknown-device';
      
      final body = {
        'email': email,
        'password': password,
        'device_token': finalDeviceToken,
      };

      // Log API request
      logger.logApiRequest(
        method: 'POST',
        endpoint: ApiConfig.loginUrl,
        headers: ApiConfig.defaultHeaders,
        body: body,
      );

      final response = await http.post(
        Uri.parse(ApiConfig.loginUrl),
        headers: ApiConfig.defaultHeaders,
        body: jsonEncode(body),
      );

      stopwatch.stop();
      final responseData = jsonDecode(response.body);

      // Log API response
      logger.logApiResponse(
        method: 'POST',
        endpoint: ApiConfig.loginUrl,
        statusCode: response.statusCode,
        headers: response.headers,
        responseBody: responseData,
        duration: stopwatch.elapsed,
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': responseData,
          'message': 'Login successful',
        };
      } else {
        return {
          'success': false,
          'data': responseData,
          'message': responseData['message'] ?? 'Login failed',
        };
      }
    } catch (e, stackTrace) {
      stopwatch.stop();
      
      // Log API error
      logger.logApiError(
        method: 'POST',
        endpoint: ApiConfig.loginUrl,
        error: e,
        stackTrace: stackTrace,
        duration: stopwatch.elapsed,
      );
      
      return {
        'success': false,
        'data': null,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  // Email verification method
  static Future<Map<String, dynamic>> verifyEmail({
    required String email,
    required String code,
  }) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    final AppLogger logger = AppLogger();

    try {
      final body = {
        'email': email,
        'code': code,
      };

      // Log API request
      logger.logApiRequest(
        method: 'POST',
        endpoint: ApiConfig.verifyEmailUrl,
        headers: ApiConfig.defaultHeaders,
        body: body,
      );

      final response = await http.post(
        Uri.parse(ApiConfig.verifyEmailUrl),
        headers: ApiConfig.defaultHeaders,
        body: jsonEncode(body),
      );

      stopwatch.stop();

      // Parse response
      dynamic responseData;
      try {
        responseData = jsonDecode(response.body);
      } catch (e) {
        responseData = {'message': response.body};
      }

      // Log API response
      logger.logApiResponse(
        method: 'POST',
        endpoint: ApiConfig.verifyEmailUrl,
        statusCode: response.statusCode,
        headers: response.headers,
        responseBody: responseData,
        duration: stopwatch.elapsed,
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': responseData,
          'message': 'Email verification successful',
        };
      } else {
        return {
          'success': false,
          'data': responseData,
          'message': responseData['message'] ?? 'Email verification failed',
        };
      }
    } catch (e, stackTrace) {
      stopwatch.stop();
      
      // Log API error
      logger.logApiError(
        method: 'POST',
        endpoint: ApiConfig.verifyEmailUrl,
        error: e,
        stackTrace: stackTrace,
        duration: stopwatch.elapsed,
      );
      
      return {
        'success': false,
        'data': null,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  // Phone verification method
  static Future<Map<String, dynamic>> verifyPhone({
    required String phone,
    required String code,
  }) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    final AppLogger logger = AppLogger();

    try {
      final body = {
        'phone': phone,
        'code': code,
      };

      // Log API request
      logger.logApiRequest(
        method: 'POST',
        endpoint: ApiConfig.verifyPhoneUrl,
        headers: ApiConfig.defaultHeaders,
        body: body,
      );

      final response = await http.post(
        Uri.parse(ApiConfig.verifyPhoneUrl),
        headers: ApiConfig.defaultHeaders,
        body: jsonEncode(body),
      );

      stopwatch.stop();

      // Parse response
      dynamic responseData;
      try {
        responseData = jsonDecode(response.body);
      } catch (e) {
        responseData = {'message': response.body};
      }

      // Log API response
      logger.logApiResponse(
        method: 'POST',
        endpoint: ApiConfig.verifyPhoneUrl,
        statusCode: response.statusCode,
        headers: response.headers,
        responseBody: responseData,
        duration: stopwatch.elapsed,
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': responseData,
          'message': 'Phone verification successful',
        };
      } else {
        return {
          'success': false,
          'data': responseData,
          'message': responseData['message'] ?? 'Phone verification failed',
        };
      }
    } catch (e, stackTrace) {
      stopwatch.stop();
      
      // Log API error
      logger.logApiError(
        method: 'POST',
        endpoint: ApiConfig.verifyPhoneUrl,
        error: e,
        stackTrace: stackTrace,
        duration: stopwatch.elapsed,
      );
      
      return {
        'success': false,
        'data': null,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
}