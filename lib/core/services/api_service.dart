import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:hudhud_delivery_driver/core/config/app_config.dart';
import 'package:hudhud_delivery_driver/core/config/api_config.dart';
import 'package:hudhud_delivery_driver/core/services/secure_storage_service.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';
import 'package:hudhud_delivery_driver/core/utils/ethiopian_phone_number.dart';
import 'package:hudhud_delivery_driver/core/utils/logger.dart';
import 'package:hudhud_delivery_driver/core/models/user_model.dart';
import 'package:hudhud_delivery_driver/core/models/handyman_profile_model.dart';
import 'package:hudhud_delivery_driver/core/models/location_update_result.dart';
import 'package:hudhud_delivery_driver/features/notifications/data/models/app_notification.dart';

enum RequestMethod { get, post, put, delete, patch }

class ApiService {
  final http.Client _client;
  final SecureStorageService _secureStorage;
  final AppLogger _logger;

  ApiService({
    http.Client? client,
    required SecureStorageService secureStorage,
    required AppLogger logger,
  }) : _client = client ?? http.Client(),
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
    bool acceptStaleLocation409 = false,
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

      return _handleResponse(
        response,
        acceptStaleLocation409: acceptStaleLocation409,
      );
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
    } on AppException {
      rethrow;
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

  Map<String, dynamic>? _parseErrorBody(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  String _errorMessage(String body, String fallback) {
    final map = _parseErrorBody(body);
    final message = map?['message']?.toString();
    if (message != null && message.isNotEmpty) return message;
    return fallback;
  }

  dynamic _errorDetails(String body) {
    final map = _parseErrorBody(body);
    if (map == null) return null;
    final reason = map['reason'];
    if (reason == null) return map;
    return map;
  }

  dynamic _handleResponse(
    http.Response response, {
    bool acceptStaleLocation409 = false,
  }) {
    switch (response.statusCode) {
      case 200:
      case 201:
        if (response.body.isEmpty) return null;
        return jsonDecode(response.body);
      case 400:
        throw BadRequestException(
          _errorMessage(response.body, 'Bad request'),
          details: _errorDetails(response.body),
        );
      case 401:
        throw UnauthorizedException(
          _errorMessage(response.body, 'Unauthorized'),
          details: _errorDetails(response.body),
        );
      case 403:
        throw ForbiddenException(
          _errorMessage(response.body, 'Forbidden'),
          details: _errorDetails(response.body),
        );
      case 404:
        throw NotFoundException(
          _errorMessage(response.body, 'Not found'),
          details: _errorDetails(response.body),
        );
      case 409:
        if (acceptStaleLocation409) {
          final stale = LocationUpdateResult.tryFromStaleConflict(
            _parseErrorBody(response.body),
          );
          if (stale != null) {
            return {
              'message': stale.message ?? 'Stale location ignored.',
              'stale': true,
              if (stale.location != null) 'location': stale.location,
            };
          }
        }
        throw ConflictException(
          _errorMessage(response.body, 'This job is no longer available.'),
          details: _errorDetails(response.body),
        );
      case 410:
        throw GoneException(
          _errorMessage(response.body, 'This delivery is no longer available.'),
          details: _errorDetails(response.body),
        );
      case 422:
        throw BadRequestException(
          _errorMessage(response.body, 'Invalid request'),
          code: '422',
          details: _errorDetails(response.body),
        );
      case 500:
      case 502:
      case 503:
        throw ServerException(
          _errorMessage(response.body, 'Server error'),
          details: _errorDetails(response.body),
        );
      default:
        throw ApiException(
          _errorMessage(
            response.body,
            'Request failed with status: ${response.statusCode}',
          ),
          code: '${response.statusCode}',
          details: _errorDetails(response.body),
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
    bool acceptStaleLocation409 = false,
  }) async {
    return request(
      endpoint: endpoint,
      method: RequestMethod.post,
      body: body,
      queryParams: queryParams,
      requiresAuth: requiresAuth,
      acceptStaleLocation409: acceptStaleLocation409,
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

  // --- Admin API: users by type, get/update user, handyman profile ---

  /// List users filtered by type (driver, courier, handyman). Returns list of UserModel.
  /// Backend may return { data: [...] } or { users: [...] }; we accept both.
  Future<List<UserModel>> listUsersByType(String type, {String? status}) async {
    final queryParams = <String, dynamic>{'type': type};
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    final res = await get(ApiConfig.adminUsersEndpoint, queryParams: queryParams);
    if (res == null) return [];
    final raw = res['data'] ?? res['users'] ?? res;
    if (raw is! List) return [];
    return raw
        .map((e) => UserModel.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Get a single user by id.
  Future<UserModel?> getUserById(int userId) async {
    final res = await get('${ApiConfig.userByIdEndpoint}/$userId');
    if (res == null) return null;
    final userMap = res['data'] ?? res['user'] ?? res;
    if (userMap is! Map) return null;
    return UserModel.fromMap(Map<String, dynamic>.from(userMap));
  }

  /// Create user with given type (driver, courier, handyman). Backend may expect name, email, phone, password.
  Future<Map<String, dynamic>> createUser({
    required String name,
    required String email,
    required String phone,
    required String type,
    String? password,
    String? passwordConfirmation,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'email': email,
      'phone': EthiopianPhoneNumber.normalizeOrOriginal(phone),
      'type': type,
    };
    if (password != null && password.isNotEmpty) {
      body['password'] = password;
      body['password_confirmation'] = passwordConfirmation ?? password;
    }
    final res = await post(ApiConfig.adminUsersEndpoint, body: body);
    return Map<String, dynamic>.from(res as Map);
  }

  /// Update user status (e.g. active, suspended). Uses PATCH /api/users/:id.
  Future<Map<String, dynamic>> updateUserStatus(int userId, String status) async {
    final res = await patch('${ApiConfig.userByIdEndpoint}/$userId', body: {'status': status});
    return Map<String, dynamic>.from(res as Map);
  }

  /// Update user fields (name, email, phone, status). Partial update.
  Future<Map<String, dynamic>> updateUser(int userId, Map<String, dynamic> fields) async {
    final res = await patch('${ApiConfig.userByIdEndpoint}/$userId', body: fields);
    return Map<String, dynamic>.from(res as Map);
  }

  /// Get handyman profile by user id. Backend may use GET /api/handyman-profile?user_id=X or GET /api/users/:id with nested profile.
  Future<HandymanProfileModel?> getHandymanProfileByUserId(int userId) async {
    try {
      final res = await get('${ApiConfig.handymanProfileEndpoint}/$userId');
      if (res == null) return null;
      final profileMap = res['data'] ?? res['handyman_profile'] ?? res;
      if (profileMap is! Map) return null;
      return HandymanProfileModel.fromMap(Map<String, dynamic>.from(profileMap));
    } catch (_) {
      return null;
    }
  }

  /// Update handyman profile. Backend may use PUT /api/handyman-profile/:id or PATCH.
  Future<Map<String, dynamic>> updateHandymanProfile(
    int profileId,
    Map<String, dynamic> fields,
  ) async {
    final res = await put('${ApiConfig.handymanProfileEndpoint}/$profileId', body: fields);
    return Map<String, dynamic>.from(res as Map);
  }

  /// Create handyman profile for a user (if backend supports POST handyman-profile with user_id).
  Future<Map<String, dynamic>> createHandymanProfile({
    required int userId,
    Map<String, dynamic>? fields,
  }) async {
    final body = <String, dynamic>{'user_id': userId};
    if (fields != null) body.addAll(fields);
    final res = await post(ApiConfig.handymanProfileEndpoint, body: body);
    return Map<String, dynamic>.from(res as Map);
  }

  /// Get driver profile (GET /api/driver/driver/profile).
  /// Returns full response including user, driver_profile, verification_status.
  /// verification_status contains license_verified, vehicle_registration_verified, etc.
  Future<Map<String, dynamic>?> getDriverProfile() async {
    try {
      final res = await get(ApiConfig.driverProfileEndpoint);
      if (res == null) return null;
      return Map<String, dynamic>.from(res as Map);
    } catch (_) {
      return null;
    }
  }

  /// Get handyman profile (GET /api/handyman/profile).
  /// Returns the full handyman user object including:
  /// id, name, email, phone, status, avatar_url, average_rating, ratings_count,
  /// skills (array), service_type, hourly_rate, experience_years, service_radius,
  /// address, latitude, longitude, is_verified, is_available, bio,
  /// nested handyman_profile, and recent_services.
  Future<Map<String, dynamic>?> getHandymanProfile() async {
    try {
      final res = await get(ApiConfig.handymanAuthProfileEndpoint);
      if (res == null) return null;
      return Map<String, dynamic>.from(res as Map);
    } catch (_) {
      return null;
    }
  }

  /// Get available service requests for handyman (GET /api/handyman/service-requests/available).
  Future<List<Map<String, dynamic>>> getHandymanServiceRequests() async {
    try {
      final res = await get(ApiConfig.handymanServiceRequestsEndpoint);
      if (res == null) return [];
      if (res is List) {
        return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      if (res is Map && res['data'] != null) {
        final data = res['data'];
        if (data is List) {
          return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Get handyman earnings (GET /api/handyman/earnings).
  Future<Map<String, dynamic>?> getHandymanEarnings() async {
    try {
      final res = await get(ApiConfig.handymanEarningsEndpoint);
      if (res == null) return null;
      return Map<String, dynamic>.from(res as Map);
    } catch (_) {
      return null;
    }
  }

  /// Accept a service request (POST /api/handyman/service-requests/:id/accept).
  Future<Map<String, dynamic>> acceptHandymanServiceRequest(int requestId) async {
    final res = await post(
      '${ApiConfig.handymanServiceRequestsEndpoint.replaceAll('/available', '')}/$requestId/accept',
      body: <String, dynamic>{},
    );
    return res == null ? <String, dynamic>{} : Map<String, dynamic>.from(res as Map);
  }

  /// Decline a service request (POST /api/handyman/service-requests/:id/decline).
  Future<Map<String, dynamic>> declineHandymanServiceRequest(int requestId) async {
    final res = await post(
      '${ApiConfig.handymanServiceRequestsEndpoint.replaceAll('/available', '')}/$requestId/decline',
      body: <String, dynamic>{},
    );
    return res == null ? <String, dynamic>{} : Map<String, dynamic>.from(res as Map);
  }

  /// Start a service request (POST /api/handyman/service-requests/:id/start).
  Future<Map<String, dynamic>> startHandymanServiceRequest(int requestId) async {
    final res = await post(
      '${ApiConfig.handymanServiceRequestsEndpoint.replaceAll('/available', '')}/$requestId/start',
      body: <String, dynamic>{},
    );
    return res == null ? <String, dynamic>{} : Map<String, dynamic>.from(res as Map);
  }

  /// Complete a service request (POST /api/handyman/service-requests/:id/complete).
  Future<Map<String, dynamic>> completeHandymanServiceRequest(int requestId) async {
    final res = await post(
      '${ApiConfig.handymanServiceRequestsEndpoint.replaceAll('/available', '')}/$requestId/complete',
      body: <String, dynamic>{},
    );
    return res == null ? <String, dynamic>{} : Map<String, dynamic>.from(res as Map);
  }

  /// Cancel a service request (POST /api/handyman/service-requests/:id/cancel).
  Future<Map<String, dynamic>> cancelHandymanServiceRequest(int requestId) async {
    final res = await post(
      '${ApiConfig.handymanServiceRequestsEndpoint.replaceAll('/available', '')}/$requestId/cancel',
      body: <String, dynamic>{},
    );
    return res == null ? <String, dynamic>{} : Map<String, dynamic>.from(res as Map);
  }

  /// Get driver ride history (GET /api/driver/driver/history).
  /// Returns paginated response: current_page, data (list of orders), total, last_page, per_page, etc.
  /// Each order has order_number, total_amount, status, delivery_address, delivered_at, customer, vendor, etc.
  Future<Map<String, dynamic>?> getDriverHistory({int page = 1}) async {
    try {
      final res = await get(
        ApiConfig.driverHistoryEndpoint,
        queryParams: {'page': page.toString()},
      );
      if (res == null) return null;
      return Map<String, dynamic>.from(res as Map);
    } catch (_) {
      return null;
    }
  }

  /// Get driver earnings (GET /api/driver/driver/earnings).
  /// Returns total_earnings, weekly_earnings, current_balance, transactions (list with amount, description, date, from, status, etc.).
  Future<Map<String, dynamic>?> getDriverEarnings() async {
    try {
      final res = await get(ApiConfig.driverEarningsEndpoint);
      if (res == null) return null;
      return Map<String, dynamic>.from(res as Map);
    } catch (_) {
      return null;
    }
  }

  /// Get driver available orders (GET /api/driver/driver/orders/available).
  /// Returns a list of orders (ready_for_pickup, etc.) with order_number, total_amount, delivery_address, vendor, items, etc.
  Future<List<Map<String, dynamic>>> getDriverAvailableOrders() async {
    try {
      final res = await get(ApiConfig.driverAvailableOrdersEndpoint);
      if (res == null) return [];
      if (res is List) {
        return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      if (res is Map && res['data'] != null) {
        final data = res['data'];
        if (data is List) {
          return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Get available delivery requests (GET /api/driver/services/available-requests).
  /// Returns the `deliveries` array from the response.
  Future<List<Map<String, dynamic>>> getAvailableDeliveryRequests() async {
    try {
      final res = await get(ApiConfig.driverServicesAvailableRequestsEndpoint);
      if (res == null) return [];
      if (res is Map) {
        final deliveries = res['deliveries'];
        if (deliveries is List) {
          return deliveries.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Delivery detail for the authenticated driver (GET /api/driver/services/delivery/:id).
  Future<Map<String, dynamic>> getDeliveryDetail(int deliveryId) async {
    final res = await get(ApiConfig.driverDeliveryDetailEndpoint(deliveryId));
    if (res is Map) {
      final delivery = res['delivery'];
      if (delivery is Map) {
        return Map<String, dynamic>.from(delivery);
      }
      return Map<String, dynamic>.from(res);
    }
    return <String, dynamic>{};
  }

  /// Accept a delivery request (POST /api/driver/services/delivery/:id/accept).
  Future<Map<String, dynamic>> acceptDeliveryRequest(int deliveryId) async {
    final res = await post(
      '/driver/services/delivery/$deliveryId/accept',
      body: <String, dynamic>{},
    );
    return res == null ? <String, dynamic>{} : Map<String, dynamic>.from(res as Map);
  }

  /// Arrive at pickup location (POST /api/driver/services/delivery/arrive-pickup).
  Future<Map<String, dynamic>> arriveAtPickup({
    required int deliveryId,
    required double latitude,
    required double longitude,
  }) async {
    final res = await post(
      '/driver/services/delivery/arrive-pickup',
      body: {
        'delivery_id': deliveryId,
        'current_latitude': latitude,
        'current_longitude': longitude,
      },
    );
    return res == null ? <String, dynamic>{} : Map<String, dynamic>.from(res as Map);
  }

  /// Start a delivery trip (POST /api/driver/services/delivery/start).
  Future<Map<String, dynamic>> startDeliveryRequest(int deliveryId) async {
    final res = await post(
      '/driver/services/delivery/start',
      body: {'delivery_id': deliveryId},
    );
    return res == null ? <String, dynamic>{} : Map<String, dynamic>.from(res as Map);
  }

  /// Complete a delivery (POST /api/driver/services/delivery/complete).
  Future<Map<String, dynamic>> completeDeliveryRequest({
    required int deliveryId,
    required double actualDistance,
    required int actualDuration,
    required double finalFare,
    String? notes,
    String? signatureData,
    List<String>? photos,
  }) async {
    final body = <String, dynamic>{
      'delivery_id': deliveryId,
      'actual_distance': actualDistance,
      'actual_duration': actualDuration,
      'final_fare': finalFare,
    };
    if (notes != null && notes.isNotEmpty) body['notes'] = notes;
    if (signatureData != null && signatureData.isNotEmpty) body['signature_data'] = signatureData;
    if (photos != null && photos.isNotEmpty) body['photos'] = photos;
    final res = await post('/driver/services/delivery/complete', body: body);
    return res == null ? <String, dynamic>{} : Map<String, dynamic>.from(res as Map);
  }

  /// Verify delivery OTP (POST /api/driver/services/delivery/:id/verify-otp).
  Future<Map<String, dynamic>> verifyDeliveryOtp(int deliveryId, String otp) async {
    final res = await post(
      '/driver/services/delivery/$deliveryId/verify-otp',
      body: {'otp': otp},
    );
    return res == null ? <String, dynamic>{} : Map<String, dynamic>.from(res as Map);
  }

  /// Accept an order (POST /api/driver/driver/orders/:id/accept).
  /// Returns { "message": "Order accepted successfully" } on success.
  Future<Map<String, dynamic>> acceptDriverOrder(int orderId) async {
    final res = await post(
      '/driver/driver/orders/$orderId/accept',
      body: <String, dynamic>{},
    );
    return res == null ? <String, dynamic>{} : Map<String, dynamic>.from(res as Map);
  }

  /// Start a delivery (POST /api/driver/driver/orders/:id/start).
  /// Returns { "message": "Delivery started successfully" } on success.
  Future<Map<String, dynamic>> startDriverOrder(int orderId) async {
    final res = await post(
      '/driver/driver/orders/$orderId/start',
      body: <String, dynamic>{},
    );
    return res == null ? <String, dynamic>{} : Map<String, dynamic>.from(res as Map);
  }

  /// Complete an order (POST /api/driver/driver/orders/:id/complete).
  /// Returns { "message": "Delivery completed successfully" } on success.
  Future<Map<String, dynamic>> completeDriverOrder(int orderId) async {
    final res = await post(
      '/driver/driver/orders/$orderId/complete',
      body: <String, dynamic>{},
    );
    return res == null ? <String, dynamic>{} : Map<String, dynamic>.from(res as Map);
  }

  /// Cancel an order (POST /api/driver/driver/orders/:id/cancel).
  /// Returns { "message": "Delivery cancelled successfully" } on success.
  Future<Map<String, dynamic>> cancelDriverOrder(int orderId) async {
    final res = await post(
      '/driver/driver/orders/$orderId/cancel',
      body: <String, dynamic>{},
    );
    return res == null ? <String, dynamic>{} : Map<String, dynamic>.from(res as Map);
  }

  /// Upload a driver profile document (POST /api/driver/profile/documents).
  /// form-data: document_type, document (file), description.
  Future<Map<String, dynamic>> uploadDriverDocument({
    required File file,
    required String documentType,
    required String description,
  }) async {
    final token = await _secureStorage.getToken();
    final url = Uri.parse('${AppConfig.baseUrl}${ApiConfig.driverProfileDocumentsEndpoint}');
    final request = http.MultipartRequest('POST', url);
    request.headers['Accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.fields['document_type'] = documentType;
    request.fields['description'] = description;
    request.files.add(await http.MultipartFile.fromPath('document', file.path));
    final streamedResponse = await _client.send(request);
    final body = await streamedResponse.stream.bytesToString();
    final response = http.Response(body, streamedResponse.statusCode);
    final res = _handleResponse(response);
    return res == null ? <String, dynamic>{} : Map<String, dynamic>.from(res as Map);
  }

 /// Update driver availability (POST /api/driver/availability).
  /// Body: { "is_available": true/false, "reason": "..." }.
  /// Returns response with "message" on success.
  Future<Map<String, dynamic>> updateDriverAvailability({
    required bool isAvailable,
    required String reason,
  }) async {
    final res = await post(
      ApiConfig.driverAvailabilityEndpoint,
      body: {
        'is_available': isAvailable,
        'reason': reason,
      },
    );
    return Map<String, dynamic>.from(res as Map);
  }

  /// Update driver location (POST /api/driver/update-location).
  /// 409 with `stale: true` is non-fatal and returned rather than thrown.
  Future<LocationUpdateResult> updateDriverLocation({
    required double latitude,
    required double longitude,
    double? accuracy,
    double? speed,
    int? heading,
    double? altitude,
    String? recordedAt,
    String? source,
  }) async {
    final token = await _secureStorage.getToken();
    if (token == null || token.isEmpty) {
      return const LocationUpdateResult(
        message: 'Skipped: no authenticated session',
        skipped: true,
      );
    }
    final body = LocationUpdatePayload.build(
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      speed: speed,
      heading: heading,
      altitude: altitude,
      recordedAt: recordedAt,
      source: source ?? 'fused',
    );
    final res = await post(
      ApiConfig.driverUpdateLocationEndpoint,
      body: body,
      acceptStaleLocation409: true,
    );
    if (res is Map<String, dynamic>) {
      return LocationUpdateResult.fromJson(res);
    }
    if (res is Map) {
      return LocationUpdateResult.fromJson(Map<String, dynamic>.from(res));
    }
    return const LocationUpdateResult(message: 'Location updated successfully.');
  }

  /// Update idle-driver location (POST /api/driver/driver/location).
  /// Body: latitude, longitude, order_id (optional).
  /// Skips the request when there is no authenticated session.
  Future<Map<String, dynamic>> updateDriverDriverLocation({
    required double latitude,
    required double longitude,
    int? orderId,
  }) async {
    final token = await _secureStorage.getToken();
    if (token == null || token.isEmpty) {
      return {'message': 'Skipped: no authenticated session'};
    }
    final body = <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
    };
    if (orderId != null) body['order_id'] = orderId;
    final res = await post(ApiConfig.driverDriverLocationEndpoint, body: body);
    return Map<String, dynamic>.from(res as Map);
  }

  // Driver Registration Methods
  static Future<Map<String, dynamic>> registerDriver({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirmation,
    required String driverLicenseNumber,
    required String vehicleType,
    required String vehiclePlateNumber,
    required String vehicleMake,
    required String vehicleModel,
    required int vehicleYear,
    required String vehicleColor,
    required List<String> serviceAreas,
    String? deviceToken,
  }) async {
    final logger = AppLogger();
    final stopwatch = Stopwatch()..start();

    try {
      final body = <String, dynamic>{
        'name': name,
        'email': email,
        'phone': EthiopianPhoneNumber.normalizeOrOriginal(phone),
        'password': password,
        'password_confirmation': passwordConfirmation,
        'driver_license_number': driverLicenseNumber,
        'vehicle_type': vehicleType,
        'vehicle_plate_number': vehiclePlateNumber,
        'vehicle_make': vehicleMake,
        'vehicle_model': vehicleModel,
        'vehicle_year': vehicleYear,
        'vehicle_color': vehicleColor,
        'service_areas': serviceAreas,
      };
      if (deviceToken != null && deviceToken.isNotEmpty) {
        body['device_token'] = deviceToken;
      }

      logger.logApiRequest(
        method: 'POST',
        endpoint: ApiConfig.driverRegisterUrl,
        headers: ApiConfig.defaultHeaders,
        body: body,
      );

      final response = await http.post(
        Uri.parse(ApiConfig.driverRegisterUrl),
        headers: ApiConfig.defaultHeaders,
        body: jsonEncode(body),
      );

      stopwatch.stop();
      final responseData = jsonDecode(response.body);

      logger.logApiResponse(
        method: 'POST',
        endpoint: ApiConfig.driverRegisterUrl,
        statusCode: response.statusCode,
        headers: response.headers,
        responseBody: responseData,
        duration: stopwatch.elapsed,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': responseData,
          'message': responseData['message'] ?? 'Registration successful',
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

      logger.logApiError(
        method: 'POST',
        endpoint: ApiConfig.driverRegisterUrl,
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

  static Future<Map<String, dynamic>> registerHandyman({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirmation,
    required List<String> skills,
    required String serviceType,
    required double hourlyRate,
    required int experienceYears,
    required int serviceRadius,
    required String address,
    required double latitude,
    required double longitude,
    required String bio,
    String? deviceToken,
  }) async {
    final logger = AppLogger();
    final stopwatch = Stopwatch()..start();

    try {
      final body = <String, dynamic>{
        'name': name,
        'email': email,
        'phone': EthiopianPhoneNumber.normalizeOrOriginal(phone),
        'password': password,
        'password_confirmation': passwordConfirmation,
        'skills': skills,
        'service_type': serviceType,
        'hourly_rate': hourlyRate,
        'experience_years': experienceYears,
        'service_radius': serviceRadius,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'bio': bio,
      };
      if (deviceToken != null && deviceToken.isNotEmpty) {
        body['device_token'] = deviceToken;
      }

      logger.logApiRequest(
        method: 'POST',
        endpoint: ApiConfig.handymanRegisterUrl,
        headers: ApiConfig.defaultHeaders,
        body: body,
      );

      final response = await http.post(
        Uri.parse(ApiConfig.handymanRegisterUrl),
        headers: ApiConfig.defaultHeaders,
        body: jsonEncode(body),
      );

      stopwatch.stop();
      final responseData = jsonDecode(response.body);

      logger.logApiResponse(
        method: 'POST',
        endpoint: ApiConfig.handymanRegisterUrl,
        statusCode: response.statusCode,
        headers: response.headers,
        responseBody: responseData,
        duration: stopwatch.elapsed,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': responseData,
          'message': responseData['message'] ?? 'Handyman registration successful',
        };
      } else {
        return {
          'success': false,
          'data': responseData,
          'message': responseData['message'] ?? 'Handyman registration failed',
        };
      }
    } catch (e, stackTrace) {
      stopwatch.stop();

      logger.logApiError(
        method: 'POST',
        endpoint: ApiConfig.handymanRegisterUrl,
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
    final secureStorage = SecureStorageService();
    final stopwatch = Stopwatch()..start();
    
    try {
      final identifier =
          EthiopianPhoneNumber.normalizeIdentifier(email) ?? email;
      final body = <String, dynamic>{
        'email': identifier,
        'password': password,
      };
      if (deviceToken != null && deviceToken.isNotEmpty) {
        body['device_token'] = deviceToken;
      }

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
        print('🔍 Debug: Full response data: $responseData');
        
        // Store token and user data securely
        if (responseData['token'] != null) {
          await secureStorage.saveToken(responseData['token']);
          print('🔐 Token stored successfully: ${responseData['token']}');
        } else {
          print('❌ Token not found in response data');
        }
        
        if (responseData['user'] != null) {
          final userData = responseData['user'];
          print('🔍 Debug: User data found: $userData');
          
          // Store complete user data as JSON
          await secureStorage.saveUserData(jsonEncode(userData));
          
          // Store individual user fields
          if (userData['id'] != null) {
            await secureStorage.saveUserId(userData['id'].toString());
          }
          if (userData['name'] != null) {
            await secureStorage.saveUserName(userData['name']);
          }
          if (userData['email'] != null) {
            await secureStorage.saveUserEmail(userData['email']);
          }
          if (userData['phone'] != null) {
            await secureStorage.saveUserPhone(
              EthiopianPhoneNumber.normalizeOrOriginal(
                userData['phone'].toString(),
              ),
            );
          }
          if (userData['referral_code'] != null) {
            await secureStorage.saveUserReferralCode(userData['referral_code']);
          }
          
          // Store verification status
          await secureStorage.saveUserEmailVerified(userData['email_verified_at'] != null);
          await secureStorage.saveUserPhoneVerified(userData['phone_verified_at'] != null);
          if (userData['type'] != null) {
            await secureStorage.saveUserType(userData['type'].toString());
          }
          
          print('👤 User data stored: ID=${userData['id']}, Name=${userData['name']}, Email=${userData['email']}');
        } else {
          print('❌ User data not found in response');
        }
        
        // Store permissions
        if (responseData['permissions'] != null) {
          await secureStorage.saveUserPermissions(jsonEncode(responseData['permissions']));
          print('🔑 Permissions stored: ${responseData['permissions'].length} permissions');
        } else {
          print('❌ Permissions not found in response');
        }
        
        return {
          'success': true,
          'data': responseData,
          'message': responseData['message'] ?? 'Login successful',
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

  // Send email verification code method
  Future<Map<String, dynamic>> sendEmailVerificationCode(String email) async {
    final Stopwatch stopwatch = Stopwatch()..start();

    try {
      final body = {
        'email': email,
      };

      // Log API request
      _logger.logApiRequest(
        method: 'POST',
        endpoint: 'https://hudapi.mbitrix.com/api/send-email-verification',
        headers: await _getHeaders(),
        body: body,
      );

      final response = await http.post(
        Uri.parse(ApiConfig.sendEmailVerificationUrl),
        headers: await _getHeaders(),
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
      _logger.logApiResponse(
        method: 'POST',
        endpoint: '/api/send-email-verification',
        statusCode: response.statusCode,
        headers: response.headers,
        responseBody: responseData,
        duration: stopwatch.elapsed,
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': responseData,
          'message': responseData['message'] ?? 'Verification code sent successfully',
        };
      } else {
        return {
          'success': false,
          'data': responseData,
          'message': responseData['message'] ?? 'Failed to send verification code',
        };
      }
    } catch (e, stackTrace) {
      stopwatch.stop();
      
      // Log API error
      _logger.logApiError(
        method: 'POST',
        endpoint: '/api/send-email-verification',
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

  // Verify email code method
  Future<Map<String, dynamic>> verifyEmailCode(String email, String code) async {
    final Stopwatch stopwatch = Stopwatch()..start();

    try {
      final body = {
        'email': email,
        'code': code,
      };

      // Log API request
      _logger.logApiRequest(
        method: 'POST',
        endpoint: 'https://hudapi.mbitrix.com/api/verify-email',
        headers: await _getHeaders(),
        body: body,
      );

      final response = await http.post(
        Uri.parse(ApiConfig.verifyEmailUrl),
        headers: await _getHeaders(),
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
      _logger.logApiResponse(
        method: 'POST',
        endpoint: '/api/verify-email',
        statusCode: response.statusCode,
        headers: response.headers,
        responseBody: responseData,
        duration: stopwatch.elapsed,
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': responseData,
          'message': responseData['message'] ?? 'Email verified successfully',
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
      _logger.logApiError(
        method: 'POST',
        endpoint: '/api/verify-email',
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

  // Send phone verification code method
  Future<Map<String, dynamic>> sendPhoneVerificationCode(String phone) async {
    final Stopwatch stopwatch = Stopwatch()..start();

    try {
      final body = {
        'phone': EthiopianPhoneNumber.normalizeOrOriginal(phone),
      };

      // Log API request
      _logger.logApiRequest(
        method: 'POST',
        endpoint: 'https://hudapi.mbitrix.com/api/send-phone-verification-code',
        headers: await _getHeaders(),
        body: body,
      );

      final response = await http.post(
        Uri.parse(ApiConfig.sendPhoneVerificationUrl),
        headers: await _getHeaders(),
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
      _logger.logApiResponse(
        method: 'POST',
        endpoint: '/api/send-phone-verification',
        statusCode: response.statusCode,
        headers: response.headers,
        responseBody: responseData,
        duration: stopwatch.elapsed,
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': responseData,
          'message': responseData['message'] ?? 'Verification code sent successfully',
        };
      } else {
        return {
          'success': false,
          'data': responseData,
          'message': responseData['message'] ?? 'Failed to send verification code',
        };
      }
    } catch (e, stackTrace) {
      stopwatch.stop();
      
      // Log API error
      _logger.logApiError(
        method: 'POST',
        endpoint: '/api/send-phone-verification',
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

  // Verify phone code method
  Future<Map<String, dynamic>> verifyPhoneCode(String phone, String code) async {
    final Stopwatch stopwatch = Stopwatch()..start();

    try {
      final body = {
        'phone': EthiopianPhoneNumber.normalizeOrOriginal(phone),
        'code': code,
      };

      // Log API request
      _logger.logApiRequest(
        method: 'POST',
        endpoint: 'https://hudapi.mbitrix.com/api/verify-phone',
        headers: await _getHeaders(),
        body: body,
      );

      final response = await http.post(
        Uri.parse(ApiConfig.verifyPhoneUrl),
        headers: await _getHeaders(),
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
      _logger.logApiResponse(
        method: 'POST',
        endpoint: '/api/verify-phone',
        statusCode: response.statusCode,
        headers: response.headers,
        responseBody: responseData,
        duration: stopwatch.elapsed,
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': responseData,
          'message': responseData['message'] ?? 'Phone verified successfully',
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
      _logger.logApiError(
        method: 'POST',
        endpoint: '/api/verify-phone',
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
        'phone': EthiopianPhoneNumber.normalizeOrOriginal(phone),
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

  /// Register or refresh the FCM device token for the authenticated user.
  Future<void> updateDeviceToken(String deviceToken) async {
    await post(
      ApiConfig.deviceTokenEndpoint,
      body: {'device_token': deviceToken},
    );
  }

  /// Remove an FCM device token on logout.
  Future<void> removeDeviceToken(String deviceToken) async {
    await delete(
      ApiConfig.deviceTokenEndpoint,
      body: {'device_token': deviceToken},
    );
  }

  Map<String, dynamic> _mapResponse(dynamic res) {
    if (res == null) return <String, dynamic>{};
    if (res is Map) return Map<String, dynamic>.from(res);
    return <String, dynamic>{'data': res};
  }

  List<Map<String, dynamic>> _listFromResponse(dynamic res, {List<String> keys = const []}) {
    if (res == null) return [];
    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    if (res is Map) {
      for (final key in ['data', 'conversations', ...keys]) {
        final value = res[key];
        if (value is List) {
          return value.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    }
    return [];
  }

  /// GET /api/chat/package-delivery/conversations
  Future<List<Map<String, dynamic>>> getDeliveryConversations() async {
    try {
      final res = await get(ApiConfig.chatPackageDeliveryConversations);
      return _listFromResponse(res);
    } catch (_) {
      return [];
    }
  }

  /// GET /api/chat/package-delivery/unread-count
  Future<int> getDeliveryUnreadCount() async {
    try {
      final res = await get(ApiConfig.chatPackageDeliveryUnreadCount);
      final map = _mapResponse(res);
      final count = map['unread_count'] ?? map['count'] ?? map['data'];
      if (count is int) return count;
      if (count is Map) {
        final nested = count['unread_count'] ?? count['count'];
        if (nested is int) return nested;
      }
      if (count != null) return int.tryParse(count.toString()) ?? 0;
      return int.tryParse(map['unread_count']?.toString() ?? '') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// GET /api/chat/package-delivery/{id}/conversation
  /// Creates the conversation only when it does not exist (404), not on server errors.
  Future<Map<String, dynamic>> getOrCreateDeliveryConversation(int deliveryId) async {
    try {
      final res = await get(ApiConfig.chatPackageDeliveryConversation(deliveryId));
      return _mapResponse(res);
    } on NotFoundException {
      return createDeliveryConversation(deliveryId);
    }
  }

  /// POST /api/chat/package-delivery/{id}/conversation
  Future<Map<String, dynamic>> createDeliveryConversation(int deliveryId) async {
    final res = await post(
      ApiConfig.chatPackageDeliveryConversation(deliveryId),
      body: <String, dynamic>{},
    );
    return _mapResponse(res);
  }

  /// POST /api/chat/package-delivery/{id}/messages
  Future<Map<String, dynamic>> sendDeliveryMessage(int deliveryId, String message) async {
    final res = await post(
      ApiConfig.chatPackageDeliveryMessages(deliveryId),
      body: {'message': message, 'type': 'text'},
    );
    return _mapResponse(res);
  }

  /// POST /api/chat/package-delivery/{id}/mark-read
  Future<void> markDeliveryConversationRead(int deliveryId) async {
    await post(
      ApiConfig.chatPackageDeliveryMarkRead(deliveryId),
      body: <String, dynamic>{},
    );
  }

  /// POST /api/chat/support
  Future<Map<String, dynamic>> openSupportConversation() async {
    final res = await post(ApiConfig.chatSupport, body: <String, dynamic>{});
    return _mapResponse(res);
  }

  /// GET /api/chat/conversations/{id}
  Future<Map<String, dynamic>> getConversation(int conversationId) async {
    final res = await get(ApiConfig.chatConversation(conversationId));
    return _mapResponse(res);
  }

  /// POST /api/chat/conversations/{id}/messages
  Future<Map<String, dynamic>> sendConversationMessage(
    int conversationId,
    String message,
  ) async {
    final res = await post(
      ApiConfig.chatConversationMessages(conversationId),
      body: {'message': message, 'type': 'text'},
    );
    return _mapResponse(res);
  }

  /// POST /api/chat/conversations/{id}/read
  Future<void> markConversationRead(int conversationId) async {
    await post(
      ApiConfig.chatConversationRead(conversationId),
      body: <String, dynamic>{},
    );
  }

  static int _clampNotificationPageSize(int? perPage) {
    final size = perPage ?? 20;
    if (size < 1) return 1;
    if (size > 100) return 100;
    return size;
  }

  /// GET /api/notifications
  Future<NotificationsPage> getNotifications({
    int page = 1,
    int perPage = 20,
    bool unreadOnly = false,
    String? type,
  }) async {
    final query = <String, dynamic>{
      'page': '$page',
      'per_page': '${_clampNotificationPageSize(perPage)}',
    };
    if (unreadOnly) query['unread_only'] = 'true';
    if (type != null && type.isNotEmpty) query['type'] = type;

    final res = await get(
      ApiConfig.notificationsEndpoint,
      queryParams: query,
    );
    return NotificationsPage.fromResponse(_mapResponse(res));
  }

  /// GET /api/notifications/{id}
  Future<AppNotification?> getNotification(String id) async {
    final res = await get(ApiConfig.notificationByIdEndpoint(id));
    final map = _mapResponse(res);
    final data = map['data'];
    if (data is Map) {
      return AppNotification.fromJson(Map<String, dynamic>.from(data));
    }
    if (map.containsKey('id')) {
      return AppNotification.fromJson(map);
    }
    return null;
  }

  /// POST /api/notifications/read
  Future<void> markNotificationRead(String notificationId) async {
    await post(
      ApiConfig.notificationsReadEndpoint,
      body: {'notification_id': notificationId},
    );
  }

  /// POST /api/notifications/read-all
  Future<void> markAllNotificationsRead() async {
    await post(
      ApiConfig.notificationsReadAllEndpoint,
      body: <String, dynamic>{},
    );
  }
}