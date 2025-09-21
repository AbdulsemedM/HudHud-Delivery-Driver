import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:hudhud_delivery_driver/core/config/app_config.dart';
import 'package:hudhud_delivery_driver/core/services/secure_storage_service.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';
import 'package:hudhud_delivery_driver/core/utils/logger.dart';

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
    final url = Uri.parse('${AppConfig.baseUrl}$endpoint').replace(
      queryParameters: queryParams,
    );

    final headers = await _getHeaders();
    http.Response response;

    try {
      _logger.info('API Request: ${method.name.toUpperCase()} $url');
      if (body != null) {
        _logger.debug('Request Body: $body');
      }

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

      _logger.info('API Response: ${response.statusCode}');
      _logger.debug('Response Body: ${response.body}');

      return _handleResponse(response);
    } on SocketException {
      _logger.error('No Internet connection');
      throw NetworkException('No Internet connection');
    } catch (e) {
      _logger.error('API Request Error: $e');
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
}