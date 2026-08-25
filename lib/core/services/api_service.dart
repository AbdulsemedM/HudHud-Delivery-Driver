import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:hudhud_delivery_driver/core/auth/logout_helper.dart';
import 'package:hudhud_delivery_driver/core/config/app_config.dart';
import 'package:hudhud_delivery_driver/core/config/api_config.dart';
import 'package:hudhud_delivery_driver/core/constants/application_status.dart';
import 'package:hudhud_delivery_driver/core/constants/user_type_constants.dart';
import 'package:hudhud_delivery_driver/core/services/secure_storage_service.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';
import 'package:hudhud_delivery_driver/core/utils/ethiopian_phone_number.dart';
import 'package:hudhud_delivery_driver/core/utils/forgot_password.dart';
import 'package:hudhud_delivery_driver/core/utils/logger.dart';
import 'package:hudhud_delivery_driver/core/models/user_model.dart';
import 'package:hudhud_delivery_driver/core/models/handyman_profile_model.dart';
import 'package:hudhud_delivery_driver/core/models/available_driver_requests.dart';
import 'package:hudhud_delivery_driver/core/models/location_update_result.dart';
import 'package:hudhud_delivery_driver/core/models/driver_account_standing.dart';
import 'package:hudhud_delivery_driver/core/models/driver_earnings_summary.dart';
import 'package:hudhud_delivery_driver/core/models/driver_financial_preview.dart';
import 'package:hudhud_delivery_driver/core/models/finance_data_source.dart';
import 'package:hudhud_delivery_driver/core/models/collection_payment_result.dart';
import 'package:hudhud_delivery_driver/core/models/driver_current_status.dart';
import 'package:hudhud_delivery_driver/core/models/driver_wallet.dart';
import 'package:hudhud_delivery_driver/core/models/payment_initiate_result.dart';
import 'package:hudhud_delivery_driver/core/models/payment_method.dart';
import 'package:hudhud_delivery_driver/core/models/payment_status_result.dart';
import 'package:hudhud_delivery_driver/core/models/settlement.dart';
import 'package:hudhud_delivery_driver/core/models/wallet_transfer_lookup.dart';
import 'package:hudhud_delivery_driver/core/constants/payment_method_codes.dart';
import 'package:hudhud_delivery_driver/core/utils/device_utils.dart';
import 'package:hudhud_delivery_driver/core/utils/payment_methods_parser.dart';
import 'package:hudhud_delivery_driver/features/auth/data/models/driver_registration_data.dart';
import 'package:hudhud_delivery_driver/features/notifications/data/models/app_notification.dart';

enum RequestMethod { get, post, put, delete, patch }

class ApiService {
  static const String _accountStandingUnavailableMessage =
      'Account standing is temporarily unavailable. Pull to retry.';
  static const String _walletUnavailableMessage =
      'Wallet details are temporarily unavailable. Pull to retry.';
  static const String _walletFallbackMessage =
      'Showing profile wallet balance while finance data is unavailable.';
  static const String _financeForbiddenMessage =
      'You do not have access to driver finance data.';
  static const String _financeNotFoundMessage =
      'Finance data could not be loaded. Pull to retry.';

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

  bool _useLegacyDriverLocationEndpoint = false;

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
    bool logTraffic = true,
    Map<String, String>? extraHeaders,
    Duration? timeout,
  }) async {
    final stopwatch = Stopwatch()..start();
    final url = Uri.parse('${AppConfig.baseUrl}$endpoint').replace(
      queryParameters: queryParams,
    );

    final headers = await _getHeaders();
    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }
    http.Response response;

    Future<http.Response> sendRequest() async {
      switch (method) {
        case RequestMethod.get:
          return _client.get(url, headers: headers);
        case RequestMethod.post:
          return _client.post(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
        case RequestMethod.put:
          return _client.put(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
        case RequestMethod.delete:
          return _client.delete(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
        case RequestMethod.patch:
          return _client.patch(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
      }
    }

    try {
      if (logTraffic) {
        // Enhanced API request logging
        _logger.logApiRequest(
          method: method.name.toUpperCase(),
          endpoint: url.toString(),
          headers: headers,
          body: body,
        );
      }

      if (timeout != null) {
        response = await sendRequest().timeout(timeout);
      } else {
        response = await sendRequest();
      }

      stopwatch.stop();

      // Enhanced API response logging
      dynamic responseBody;
      try {
        responseBody = jsonDecode(response.body);
      } catch (e) {
        responseBody = response.body;
      }

      if (logTraffic) {
        _logger.logApiResponse(
          method: method.name.toUpperCase(),
          endpoint: url.toString(),
          statusCode: response.statusCode,
          headers: response.headers,
          responseBody: responseBody,
          duration: stopwatch.elapsed,
        );
      }

      return _handleResponse(
        response,
        requiresAuth: requiresAuth,
        acceptStaleLocation409: acceptStaleLocation409,
      );
    } on SocketException catch (e, stackTrace) {
      stopwatch.stop();
      if (logTraffic) {
        _logger.logApiError(
          method: method.name.toUpperCase(),
          endpoint: url.toString(),
          error: 'No Internet connection',
          stackTrace: stackTrace,
          duration: stopwatch.elapsed,
        );
      }
      throw NetworkException('No Internet connection');
    } on AppException {
      rethrow;
    } catch (e, stackTrace) {
      stopwatch.stop();
      if (logTraffic) {
        _logger.logApiError(
          method: method.name.toUpperCase(),
          endpoint: url.toString(),
          error: e,
          stackTrace: stackTrace,
          duration: stopwatch.elapsed,
        );
      }
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

  String? _errorCodeFromBody(String body) {
    final code = _parseErrorBody(body)?['code']?.toString();
    if (code != null && code.isNotEmpty) return code;
    return null;
  }

  String? _errorCodeFromException(AppException error) {
    if (error.code != null && error.code!.isNotEmpty) return error.code;
    final details = error.details;
    if (details is Map) {
      final code = details['code']?.toString();
      if (code != null && code.isNotEmpty) return code;
    }
    return null;
  }

  bool _isFinanceUnavailable(AppException error) {
    final code = _errorCodeFromException(error);
    return error is ServerException ||
        code == 'ACCOUNT_STANDING_UNAVAILABLE' ||
        code == 'WALLET_UNAVAILABLE' ||
        code == 'WALLET_TRANSACTIONS_UNAVAILABLE';
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
    bool requiresAuth = true,
    bool acceptStaleLocation409 = false,
  }) {
    switch (response.statusCode) {
      case 200:
      case 201:
      case 202:
        if (response.body.isEmpty) return null;
        return jsonDecode(response.body);
      case 400:
        throw BadRequestException(
          _errorMessage(response.body, 'Bad request'),
          details: _errorDetails(response.body),
        );
      case 401:
        if (requiresAuth) {
          // Fire-and-forget: clear session and send user to login.
          unawaited(LogoutHelper.handleUnauthenticated());
        }
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
          code: _errorCodeFromBody(response.body) ?? '409',
          details: _errorDetails(response.body),
        );
      case 410:
        throw GoneException(
          _errorMessage(response.body, 'This delivery is no longer available.'),
          code: _errorCodeFromBody(response.body) ?? '410',
          details: _errorDetails(response.body),
        );
      case 422:
        throw BadRequestException(
          _errorMessage(response.body, 'Invalid request'),
          code: _errorCodeFromBody(response.body) ?? '422',
          details: _errorDetails(response.body),
        );
      case 423:
        throw LockedException(
          _errorMessage(response.body, 'Action locked'),
          code: _errorCodeFromBody(response.body) ?? '423',
          details: _errorDetails(response.body),
        );
      case 429:
        throw TooManyRequestsException(
          _errorMessage(response.body, 'Too many requests'),
          code: _errorCodeFromBody(response.body) ?? '429',
          details: _errorDetails(response.body),
        );
      case 500:
      case 502:
      case 503:
        throw ServerException(
          _errorMessage(response.body, 'Server error'),
          code: _errorCodeFromBody(response.body) ?? '${response.statusCode}',
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
    bool logTraffic = true,
    Map<String, String>? extraHeaders,
    Duration? timeout,
  }) async {
    return request(
      endpoint: endpoint,
      method: RequestMethod.get,
      queryParams: queryParams,
      requiresAuth: requiresAuth,
      logTraffic: logTraffic,
      extraHeaders: extraHeaders,
      timeout: timeout,
    );
  }

  Future<dynamic> post(
    String endpoint, {
    dynamic body,
    Map<String, dynamic>? queryParams,
    bool requiresAuth = true,
    bool acceptStaleLocation409 = false,
    bool logTraffic = true,
    Map<String, String>? extraHeaders,
    Duration? timeout,
  }) async {
    return request(
      endpoint: endpoint,
      method: RequestMethod.post,
      body: body,
      queryParams: queryParams,
      requiresAuth: requiresAuth,
      acceptStaleLocation409: acceptStaleLocation409,
      logTraffic: logTraffic,
      extraHeaders: extraHeaders,
      timeout: timeout,
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

  /// Extracts the user object from profile API responses (multiple envelopes).
  Map<String, dynamic>? _extractUserFromProfile(dynamic response) {
    if (response is! Map) return null;

    final user = response['user'];
    if (user is Map) return Map<String, dynamic>.from(user);

    final data = response['data'];
    if (data is Map) {
      final nestedUser = data['user'];
      if (nestedUser is Map) return Map<String, dynamic>.from(nestedUser);
      if (data['id'] != null) return Map<String, dynamic>.from(data);
    }

    if (response['id'] != null) return Map<String, dynamic>.from(response);
    return null;
  }

  /// GET /api/profile — reads phone_verified_at and related user fields.
  /// Falls back to role-specific profile endpoints when /profile is unavailable.
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final res = await get(ApiConfig.profileEndpoint);
      final user = _extractUserFromProfile(res);
      if (user != null) return user;
    } on NotFoundException {
      // Fall through to role-specific profile.
    } catch (_) {
      // Fall through to role-specific profile.
    }

    final userType = await _secureStorage.getUserType();
    final Map<String, dynamic>? profile;
    if (UserTypeConstants.isHandyman(userType)) {
      profile = await getHandymanProfile();
    } else {
      profile = await getDriverProfile();
    }
    return _extractUserFromProfile(profile);
  }

  /// Phone registered on the authenticated account (profile is authoritative).
  Future<String?> getRegisteredPhone() async {
    final user = await getUserProfile();
    final profilePhone = user?['phone']?.toString().trim();
    if (profilePhone != null && profilePhone.isNotEmpty) {
      return profilePhone;
    }

    final stored = await _secureStorage.getUserPhone();
    final trimmed = stored?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    return null;
  }

  /// Phone payload for verification endpoints — must match backend user.phone.
  String _phoneForVerificationApi(String phone) => phone.trim();

  /// Persists user fields from login/profile refresh into secure storage.
  static Future<void> persistLoginUser(
    Map<String, dynamic> userData, {
    SecureStorageService? secureStorage,
  }) async {
    final storage = secureStorage ?? SecureStorageService();

    await storage.saveUserData(jsonEncode(userData));

    final id = userData['id'];
    if (id != null) {
      await storage.saveUserId(id.toString());
    }
    final name = userData['name'];
    if (name != null) {
      await storage.saveUserName(name.toString());
    }
    final email = userData['email'];
    if (email != null) {
      await storage.saveUserEmail(email.toString());
    }
    final phone = userData['phone'];
    if (phone != null) {
      await storage.saveUserPhone(phone.toString().trim());
    }
    final referralCode = userData['referral_code'];
    if (referralCode != null) {
      await storage.saveUserReferralCode(referralCode.toString());
    }

    await storage.saveUserEmailVerified(userData['email_verified_at'] != null);
    await storage.saveUserPhoneVerified(userData['phone_verified_at'] != null);

    final type = userData['type'];
    if (type != null) {
      await storage.saveUserType(type.toString());
    }
  }

  /// Re-fetches profile and updates stored verification timestamps.
  Future<Map<String, dynamic>> refreshVerificationStatus() async {
    final user = await getUserProfile();
    if (user == null) {
      return {
        'success': false,
        'message': 'Failed to load profile',
      };
    }

    await persistLoginUser(user, secureStorage: _secureStorage);

    return {
      'success': true,
      'phoneVerified': user['phone_verified_at'] != null,
      'emailVerified': user['email_verified_at'] != null,
      'user': user,
    };
  }

  Future<Map<String, dynamic>> _handleVerificationHttpResponse(
    http.Response response,
    dynamic responseData,
  ) async {
    if (response.statusCode == 200) {
      final message = responseData is Map
          ? responseData['message']?.toString()
          : null;
      return {
        'success': true,
        'data': responseData,
        'message': message ?? 'Success',
      };
    }

    if (response.statusCode == 401) {
      await _secureStorage.clearAll();
      return {
        'success': false,
        'unauthenticated': true,
        'data': responseData,
        'message': extractApiErrorMessage(
          responseData,
          fallback: 'Unauthenticated.',
        ),
      };
    }

    if (response.statusCode == 422) {
      return {
        'success': false,
        'data': responseData,
        'message': extractApiErrorMessage(
          responseData,
          fallback: 'Validation failed',
        ),
      };
    }

    if (response.statusCode >= 500) {
      return {
        'success': false,
        'data': responseData,
        'message': extractApiErrorMessage(
          responseData,
          fallback: 'Server Error',
        ),
      };
    }

    return {
      'success': false,
      'data': responseData,
      'message': extractApiErrorMessage(responseData),
    };
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

  /// GET /api/driver/driver/application-status
  Future<Map<String, dynamic>?> getDriverApplicationStatus() async {
    try {
      final res = await get(ApiConfig.driverApplicationStatusEndpoint);
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

  /// Financial preview before accepting a delivery.
  Future<DriverFinancialPreview?> getDeliveryFinancialPreview(
    int deliveryId,
  ) async {
    try {
      final res = await get(
        ApiConfig.driverDeliveryFinancialPreviewEndpoint(deliveryId),
      );
      return DriverFinancialPreview.fromJson(res);
    } on NotFoundException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Driver account standing (wallet, limits, amount owed).
  Future<FinanceFetchResult<DriverAccountStanding>> getDriverAccountStanding({
    DriverAccountStanding? cached,
  }) async {
    try {
      final res = await get(ApiConfig.driverAccountStandingEndpoint);
      final standing = DriverAccountStanding.fromJson(res);
      if (standing == null) {
        return FinanceFetchResult(
          data: cached,
          outcome: cached != null
              ? FinanceFetchOutcome.unavailable
              : FinanceFetchOutcome.error,
          source: cached != null
              ? FinanceDataSource.cached
              : FinanceDataSource.primary,
          message: _accountStandingUnavailableMessage,
        );
      }
      return FinanceFetchResult(data: standing);
    } on UnauthorizedException {
      return const FinanceFetchResult(
        outcome: FinanceFetchOutcome.unauthorized,
      );
    } on ForbiddenException {
      return const FinanceFetchResult(
        outcome: FinanceFetchOutcome.forbidden,
        message: _financeForbiddenMessage,
      );
    } on NotFoundException {
      return FinanceFetchResult(
        data: cached,
        outcome: FinanceFetchOutcome.notFound,
        source: cached != null
            ? FinanceDataSource.cached
            : FinanceDataSource.primary,
        message: cached != null
            ? _accountStandingUnavailableMessage
            : _financeNotFoundMessage,
      );
    } on AppException catch (e) {
      if (_isFinanceUnavailable(e)) {
        if (cached != null) {
          return FinanceFetchResult(
            data: cached,
            outcome: FinanceFetchOutcome.unavailable,
            source: FinanceDataSource.cached,
            message: _accountStandingUnavailableMessage,
          );
        }
        final fallback = await _fallbackAccountStandingFromProfile(
          _walletFallbackMessage,
        );
        if (fallback != null) {
          return FinanceFetchResult(
            data: fallback,
            source: FinanceDataSource.fallback,
            message: _walletFallbackMessage,
          );
        }
        return const FinanceFetchResult(
          outcome: FinanceFetchOutcome.unavailable,
          message: _accountStandingUnavailableMessage,
        );
      }
      return FinanceFetchResult(
        data: cached,
        outcome: cached != null
            ? FinanceFetchOutcome.unavailable
            : FinanceFetchOutcome.error,
        source: cached != null
            ? FinanceDataSource.cached
            : FinanceDataSource.primary,
        message: _accountStandingUnavailableMessage,
      );
    } catch (_) {
      if (cached != null) {
        return FinanceFetchResult(
          data: cached,
          outcome: FinanceFetchOutcome.unavailable,
          source: FinanceDataSource.cached,
          message: _accountStandingUnavailableMessage,
        );
      }
      final fallback = await _fallbackAccountStandingFromProfile(
        _walletFallbackMessage,
      );
      if (fallback != null) {
        return FinanceFetchResult(
          data: fallback,
          source: FinanceDataSource.fallback,
          message: _walletFallbackMessage,
        );
      }
      return const FinanceFetchResult(
        outcome: FinanceFetchOutcome.error,
        message: _accountStandingUnavailableMessage,
      );
    }
  }

  /// Settlement summary for a date range.
  Future<SettlementSummary?> getSettlementSummary({
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final params = <String, String>{};
      if (from != null) {
        params['from'] = _formatDateParam(from);
      }
      if (to != null) {
        params['to'] = _formatDateParam(to);
      }
      final res = await get(
        ApiConfig.driverSettlementSummaryEndpoint,
        queryParams: params.isEmpty ? null : params,
      );
      return SettlementSummary.fromJson(res);
    } catch (_) {
      return null;
    }
  }

  /// Paginated settlement batches.
  Future<({List<SettlementBatch> batches, SettlementListMeta meta})>
      getSettlements({int page = 1, int perPage = 20}) async {
    try {
      final res = await get(
        ApiConfig.driverSettlementsEndpoint,
        queryParams: {
          'page': page.toString(),
          'per_page': perPage.toString(),
        },
      );
      return (
        batches: SettlementBatch.listFromJson(res),
        meta: SettlementListMeta.fromJson(res),
      );
    } catch (_) {
      return (
        batches: const <SettlementBatch>[],
        meta: const SettlementListMeta(),
      );
    }
  }

  /// Single settlement batch detail.
  Future<SettlementBatch?> getSettlementDetail(String id) async {
    try {
      final res = await get(ApiConfig.driverSettlementDetailEndpoint(id));
      return SettlementBatch.detailFromJson(res);
    } catch (_) {
      return null;
    }
  }

  /// Driver wallet balance. Prefers GET /wallet (handbook), falls back to legacy.
  Future<FinanceFetchResult<DriverWallet>> getDriverWallet({
    DriverWallet? cached,
  }) async {
    try {
      dynamic res;
      try {
        res = await get(ApiConfig.walletEndpoint);
      } on NotFoundException {
        res = await get(ApiConfig.driverWalletEndpoint);
      } on AppException catch (e) {
        if (e is ForbiddenException || e is UnauthorizedException) rethrow;
        res = await get(ApiConfig.driverWalletEndpoint);
      }
      final parsed = DriverWallet.fromJson(res);
      if (parsed == null) {
        return FinanceFetchResult(
          data: cached,
          outcome: cached != null
              ? FinanceFetchOutcome.unavailable
              : FinanceFetchOutcome.error,
          source: cached != null ? FinanceDataSource.cached : FinanceDataSource.primary,
          message: _walletUnavailableMessage,
        );
      }
      return FinanceFetchResult(data: parsed);
    } on UnauthorizedException {
      return const FinanceFetchResult(
        outcome: FinanceFetchOutcome.unauthorized,
      );
    } on ForbiddenException {
      return const FinanceFetchResult(
        outcome: FinanceFetchOutcome.forbidden,
        message: _financeForbiddenMessage,
      );
    } on NotFoundException {
      return FinanceFetchResult(
        data: cached,
        outcome: FinanceFetchOutcome.notFound,
        source: cached != null ? FinanceDataSource.cached : FinanceDataSource.primary,
        message: cached != null ? _walletUnavailableMessage : _financeNotFoundMessage,
      );
    } on AppException catch (e) {
      if (_isFinanceUnavailable(e)) {
        if (cached != null) {
          return FinanceFetchResult(
            data: cached,
            outcome: FinanceFetchOutcome.unavailable,
            source: FinanceDataSource.cached,
            message: _walletUnavailableMessage,
          );
        }
        final fallback = await _driverWalletFromProfileFallback();
        if (fallback != null) {
          return FinanceFetchResult(
            data: fallback,
            source: FinanceDataSource.fallback,
            message: _walletFallbackMessage,
          );
        }
        return const FinanceFetchResult(
          outcome: FinanceFetchOutcome.unavailable,
          message: _walletUnavailableMessage,
        );
      }
      return FinanceFetchResult(
        data: cached,
        outcome: cached != null
            ? FinanceFetchOutcome.unavailable
            : FinanceFetchOutcome.error,
        source: cached != null ? FinanceDataSource.cached : FinanceDataSource.primary,
        message: _walletUnavailableMessage,
      );
    } catch (_) {
      if (cached != null) {
        return FinanceFetchResult(
          data: cached,
          outcome: FinanceFetchOutcome.unavailable,
          source: FinanceDataSource.cached,
          message: _walletUnavailableMessage,
        );
      }
      final fallback = await _driverWalletFromProfileFallback();
      if (fallback != null) {
        return FinanceFetchResult(
          data: fallback,
          source: FinanceDataSource.fallback,
          message: _walletFallbackMessage,
        );
      }
      return const FinanceFetchResult(
        outcome: FinanceFetchOutcome.error,
        message: _walletUnavailableMessage,
      );
    }
  }

  Future<DriverWallet?> _driverWalletFromProfileFallback() async {
    final profile = await getDriverProfile();
    if (profile == null) return null;
    final fallback = _driverWalletFromProfile(profile);
    return fallback?.copyWith(
      source: FinanceDataSource.fallback,
      sourceMessage: _walletFallbackMessage,
    );
  }

  Future<DriverAccountStanding?> _fallbackAccountStandingFromProfile(
    String message,
  ) async {
    final profile = await getDriverProfile();
    if (profile == null) return null;
    final standing = _driverAccountStandingFromProfile(profile);
    return standing?.copyWith(
      source: FinanceDataSource.fallback,
      sourceMessage: message,
    );
  }

  DriverWallet? _driverWalletFromProfile(Map<String, dynamic> profile) {
    final wallet = profile['wallet'];
    if (wallet is! Map) return null;
    return DriverWallet.fromJson({
      'data': {'wallet': Map<String, dynamic>.from(wallet)},
    });
  }

  DriverAccountStanding? _driverAccountStandingFromProfile(
    Map<String, dynamic> profile,
  ) {
    final walletMap = profile['wallet'];
    final statsMap = profile['statistics'];
    return DriverAccountStanding.fromJson({
      'data': {
        if (walletMap is Map)
          'wallet': {
            'balance': walletMap['balance'],
            'currency': walletMap['currency'],
          },
        if (statsMap is Map)
          'summary': {
            'total_deliveries': statsMap['total_deliveries'],
            'total_earnings': statsMap['total_earnings'],
            'completion_rate': statsMap['completion_rate'],
          },
      },
    });
  }

  /// Wallet transaction history.
  Future<FinanceFetchResult<WalletTransactionsPage>> getWalletTransactions({
    int page = 1,
    int perPage = 20,
    WalletTransactionsPage? cached,
  }) async {
    final safePerPage = perPage.clamp(1, 100);
    try {
      final res = await get(
        ApiConfig.driverWalletTransactionsEndpoint,
        queryParams: {
          'page': page.toString(),
          'per_page': safePerPage.toString(),
        },
      );
      final parsed = WalletTransactionsPage.fromJson(res);
      return FinanceFetchResult(data: parsed);
    } on UnauthorizedException {
      return const FinanceFetchResult(
        outcome: FinanceFetchOutcome.unauthorized,
      );
    } on ForbiddenException {
      return const FinanceFetchResult(
        outcome: FinanceFetchOutcome.forbidden,
        message: _financeForbiddenMessage,
      );
    } on AppException catch (e) {
      if (_isFinanceUnavailable(e)) {
        if (cached != null) {
          return FinanceFetchResult(
            data: cached,
            outcome: FinanceFetchOutcome.unavailable,
            source: FinanceDataSource.cached,
            message: _walletUnavailableMessage,
          );
        }
      }
      return FinanceFetchResult(
        data: cached,
        outcome: cached != null
            ? FinanceFetchOutcome.unavailable
            : FinanceFetchOutcome.error,
        source: cached != null ? FinanceDataSource.cached : FinanceDataSource.primary,
        message: _walletUnavailableMessage,
      );
    } catch (_) {
      if (cached != null) {
        return FinanceFetchResult(
          data: cached,
          outcome: FinanceFetchOutcome.unavailable,
          source: FinanceDataSource.cached,
          message: _walletUnavailableMessage,
        );
      }
      return const FinanceFetchResult(
        outcome: FinanceFetchOutcome.error,
        message: _walletUnavailableMessage,
      );
    }
  }

  static const Duration _paymentRequestTimeout = Duration(minutes: 3);

  /// Request wallet withdrawal / cash out (handbook: POST /wallet/withdraw).
  Future<Map<String, dynamic>> postWalletWithdraw({
    required double amount,
    String currency = 'ETB',
    String? paymentMethodCode,
    Map<String, dynamic>? paymentDetails,
    String? idempotencyKey,
  }) async {
    final body = <String, dynamic>{
      'amount': amount,
      'currency': currency,
    };
    if (paymentMethodCode != null && paymentMethodCode.isNotEmpty) {
      body['payment_method_code'] = paymentMethodCode;
    }
    if (paymentDetails != null && paymentDetails.isNotEmpty) {
      body['payment_details'] = paymentDetails;
    }
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      body['idempotency_key'] = idempotencyKey;
    }

    dynamic res;
    try {
      res = await post(
        ApiConfig.walletWithdrawEndpoint,
        body: body,
        extraHeaders: idempotencyKey != null && idempotencyKey.isNotEmpty
            ? {'Idempotency-Key': idempotencyKey}
            : null,
      );
    } on NotFoundException {
      res = await post(
        ApiConfig.driverWalletWithdrawEndpoint,
        body: {'amount': amount},
      );
    }
    return res == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(res as Map);
  }

  /// GET /api/payments/methods?type=&currency= when [type] is set;
  /// falls back to GET /api/payment-methods on 404 or empty list.
  Future<List<PaymentMethod>> getPaymentMethods({
    Set<String>? allowedCodes,
    String? type,
    String? currency,
  }) async {
    final query = <String, dynamic>{};
    if (type != null && type.isNotEmpty) query['type'] = type;
    if (currency != null && currency.isNotEmpty) query['currency'] = currency;

    if (query.isNotEmpty) {
      try {
        final res = await get(
          ApiConfig.paymentsMethodsEndpoint,
          queryParams: query,
        );
        final parsed = parsePaymentMethodsList(
          res,
          allowedCodes: allowedCodes,
        );
        if (parsed.isNotEmpty) return parsed;
      } on NotFoundException {
        // Older backends only expose /payment-methods.
      } catch (_) {}
    }

    try {
      final res = await get(ApiConfig.paymentMethodsEndpoint);
      return parsePaymentMethodsList(
        res,
        allowedCodes: allowedCodes,
      );
    } catch (_) {
      return const [];
    }
  }

  /// POST /api/payments/initiate
  Future<PaymentInitiateResult> initiatePayment({
    required String paymentMethodCode,
    required String type,
    required double amount,
    required Map<String, dynamic> paymentDetails,
    String? currency,
    int? packageDeliveryId,
    int? orderId,
    int? rideId,
    required String idempotencyKey,
  }) async {
    final body = <String, dynamic>{
      'payment_method_code': paymentMethodCode,
      'type': type,
      'amount': amount,
      'payment_details': paymentDetails,
    };
    if (currency != null && currency.isNotEmpty) body['currency'] = currency;
    if (packageDeliveryId != null) {
      body['package_delivery_id'] = packageDeliveryId;
    }
    if (orderId != null) body['order_id'] = orderId;
    if (rideId != null) body['ride_id'] = rideId;

    final res = await post(
      ApiConfig.paymentsInitiateEndpoint,
      body: body,
      extraHeaders: {'Idempotency-Key': idempotencyKey},
      timeout: _paymentRequestTimeout,
    );
    return PaymentInitiateResult.fromJson(res);
  }

  /// GET /api/payments/{id}/status
  Future<PaymentStatusResult> getPaymentStatus(int paymentId) async {
    final res = await get(
      ApiConfig.paymentStatusEndpoint(paymentId),
    );
    return PaymentStatusResult.fromJson(res);
  }

  /// POST /api/services/delivery/{id}/retry-payment
  Future<PaymentInitiateResult> retryDeliveryPayment({
    required int deliveryId,
    required String paymentMethod,
    String? paymentPhone,
  }) async {
    final body = <String, dynamic>{
      'payment_method': paymentMethod,
    };
    if (paymentPhone != null && paymentPhone.isNotEmpty) {
      body['payment_phone'] = paymentPhone;
    }
    final res = await post(
      ApiConfig.deliveryRetryPaymentEndpoint(deliveryId),
      body: body,
      timeout: _paymentRequestTimeout,
    );
    return PaymentInitiateResult.fromJson(res);
  }

  /// POST /api/wallet/topup
  Future<PaymentInitiateResult> postWalletTopUp({
    required String paymentMethodCode,
    required double amount,
    required String currency,
    required Map<String, dynamic> paymentDetails,
    required String idempotencyKey,
  }) async {
    final res = await post(
      ApiConfig.walletTopUpEndpoint,
      body: {
        'payment_method_code': paymentMethodCode,
        'amount': amount,
        'currency': currency,
        'payment_details': paymentDetails,
      },
      extraHeaders: {'Idempotency-Key': idempotencyKey},
      timeout: _paymentRequestTimeout,
      logTraffic: false,
    );
    return PaymentInitiateResult.fromJson(res);
  }

  /// POST /api/wallet/transfer/lookup
  Future<WalletTransferLookupResult> lookupWalletTransferRecipient(
    String identifier,
  ) async {
    final res = await post(
      ApiConfig.walletTransferLookupEndpoint,
      body: {'identifier': identifier.trim()},
    );
    return WalletTransferLookupResult.fromJson(res);
  }

  /// POST /api/wallet/transfer
  Future<Map<String, dynamic>> postWalletTransfer({
    required int recipientUserId,
    required double amount,
    required String currency,
    String? note,
    required String idempotencyKey,
  }) async {
    final body = <String, dynamic>{
      'recipient_user_id': recipientUserId,
      'amount': amount,
      'currency': currency,
      'idempotency_key': idempotencyKey,
    };
    if (note != null && note.trim().isNotEmpty) body['note'] = note.trim();

    final res = await post(
      ApiConfig.walletTransferEndpoint,
      body: body,
      extraHeaders: {'Idempotency-Key': idempotencyKey},
    );
    return res == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(res as Map);
  }

  /// Default electronic methods when API list is empty.
  List<PaymentMethod> defaultDropOffElectronicMethods() {
    final methods = PaymentMethodCodes.kDropOffElectronicCodes
        .where((code) => code != PaymentMethodCodes.qpay)
        .map(
          (code) => PaymentMethod(
            code: code,
            name: _defaultMethodLabel(code),
            enabled: true,
          ),
        )
        .toList();
    return PaymentMethodCodes.sortDropOffMethods(
      methods,
      codeOf: (m) => m.code,
    );
  }

  List<PaymentMethod> defaultWalletFundingMethods() {
    return PaymentMethodCodes.kWalletFundingMethodCodes.map(
      (code) => PaymentMethod(
        code: code,
        name: _defaultMethodLabel(code),
        enabled: true,
        canUse: true,
        requiresQr: code == PaymentMethodCodes.qpay,
        supportsQrPayment: code == PaymentMethodCodes.qpay,
      ),
    ).toList();
  }

  /// Resolves a usable QPay method from the registry (any type), if available.
  Future<PaymentMethod?> resolveUsableQpay({String? currency}) async {
    Future<PaymentMethod?> fromType(String? type) async {
      final methods = await getPaymentMethods(
        allowedCodes: {PaymentMethodCodes.qpay},
        type: type,
        currency: currency,
      );
      for (final method in methods) {
        if (method.canInitiateQpay) return method;
      }
      return null;
    }

    return await fromType('wallet') ??
        await fromType('delivery') ??
        await fromType(null);
  }

  String _defaultMethodLabel(String code) {
    switch (code) {
      case PaymentMethodCodes.waafi:
        return 'Waafi Pay';
      case PaymentMethodCodes.edahab:
        return 'eDahab';
      case PaymentMethodCodes.sahay:
        return 'Sahay';
      case PaymentMethodCodes.ebirr:
        return 'eBirr';
      case PaymentMethodCodes.ebirrKaafi:
        return 'eBirr (Kaafi)';
      case PaymentMethodCodes.ebirrCoop:
        return 'eBirr (Coop)';
      case PaymentMethodCodes.cash:
        return 'Cash';
      case PaymentMethodCodes.qpay:
        return 'QPay';
      default:
        return code;
    }
  }

  /// Driver earnings statistics (new API).
  Future<DriverEarningsSummary?> getDriverEarningsStats() async {
    try {
      final res = await get(ApiConfig.driverEarningsStatsEndpoint);
      return DriverEarningsSummary.fromStatsJson(res);
    } on NotFoundException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Weekly earnings summary.
  Future<WeeklyEarningsSummary?> getWeeklyEarningsSummary({
    DateTime? weekStart,
  }) async {
    try {
      final params = weekStart != null
          ? <String, String>{'week_start': _formatDateParam(weekStart)}
          : null;
      final res = await get(
        ApiConfig.driverEarningsWeeklySummaryEndpoint,
        queryParams: params,
      );
      return WeeklyEarningsSummary.fromJson(res);
    } on NotFoundException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Earnings breakdown by dimension.
  Future<Map<String, dynamic>?> getEarningsBreakdown({
    String? period,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final params = <String, String>{};
      if (period != null) params['period'] = period;
      if (from != null) params['from'] = _formatDateParam(from);
      if (to != null) params['to'] = _formatDateParam(to);
      final res = await get(
        ApiConfig.driverEarningsBreakdownEndpoint,
        queryParams: params.isEmpty ? null : params,
      );
      if (res is Map) return Map<String, dynamic>.from(res);
      return null;
    } on NotFoundException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Driver performance metrics.
  Future<Map<String, dynamic>?> getDriverPerformance({
    String timeframe = 'month',
  }) async {
    try {
      final res = await get(
        ApiConfig.driverPerformanceEndpoint,
        queryParams: {'timeframe': timeframe},
      );
      if (res is Map) return Map<String, dynamic>.from(res);
      return null;
    } catch (_) {
      return null;
    }
  }

  String _formatDateParam(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Get driver available orders.
  /// Prefers services available-requests (rides); falls back to legacy orders list.
  Future<List<Map<String, dynamic>>> getDriverAvailableOrders() async {
    try {
      final services = await getAvailableDeliveryRequests();
      if (services.rides.isNotEmpty) return services.rides;
      if (services.deliveries.isNotEmpty) return services.deliveries;
    } catch (_) {}
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
    } on ForbiddenException {
      rethrow;
    } catch (_) {
      return [];
    }
  }

  /// Get available delivery requests (GET /api/driver/services/available-requests).
  Future<AvailableDriverRequests> getAvailableDeliveryRequests() async {
    try {
      final res = await get(ApiConfig.driverServicesAvailableRequestsEndpoint);
      return AvailableDriverRequests.fromJson(res);
    } on ForbiddenException {
      rethrow;
    } on UnauthorizedException {
      rethrow;
    } catch (_) {
      return AvailableDriverRequests.empty;
    }
  }

  /// Active job recovery (GET /api/driver/services/current-status).
  Future<DriverCurrentStatus> getDriverCurrentStatus() async {
    final res = await get(
      ApiConfig.driverServicesCurrentStatusEndpoint,
      logTraffic: false,
    );
    return DriverCurrentStatus.fromJson(res);
  }

  /// Support/debug only (GET dispatch-diagnostic).
  Future<Map<String, dynamic>> getDeliveryDispatchDiagnostic(
    int deliveryId,
  ) async {
    final res = await get(
      ApiConfig.driverDeliveryDispatchDiagnosticEndpoint(deliveryId),
    );
    return res == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(res as Map);
  }

  /// Delivery detail for the authenticated driver (GET /api/driver/services/delivery/:id).
  Future<Map<String, dynamic>> getDeliveryDetail(int deliveryId) async {
    final res = await get(
      ApiConfig.driverDeliveryDetailEndpoint(deliveryId),
      logTraffic: false,
    );
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

  /// Accept a ride request (POST /api/driver/services/ride/:id/accept).
  Future<Map<String, dynamic>> acceptRideRequest(int rideId) async {
    final res = await post(
      ApiConfig.driverRideAcceptEndpoint(rideId),
      body: <String, dynamic>{},
    );
    return res == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(res as Map);
  }

  /// Start a ride (POST /api/driver/services/ride/start).
  Future<Map<String, dynamic>> startRideRequest(int rideId) async {
    final res = await post(
      ApiConfig.driverRideStartEndpoint,
      body: {'ride_id': rideId},
    );
    return res == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(res as Map);
  }

  /// Complete a ride (POST /api/driver/services/ride/complete).
  Future<Map<String, dynamic>> completeRideRequest(int rideId) async {
    final res = await post(
      ApiConfig.driverRideCompleteEndpoint,
      body: {'ride_id': rideId},
    );
    return res == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(res as Map);
  }

  /// Cancel an active ride.
  Future<Map<String, dynamic>> cancelRideRequest(int rideId) async {
    final res = await post(
      ApiConfig.driverRideCancelEndpoint(rideId),
      body: <String, dynamic>{},
    );
    return res == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(res as Map);
  }

  /// Decline a ride offer (before accept).
  Future<Map<String, dynamic>> declineRideRequest(int rideId) async {
    final res = await post(
      ApiConfig.driverRideDeclineEndpoint(rideId),
      body: <String, dynamic>{},
    );
    return res == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(res as Map);
  }

  /// Arrive at pickup (POST .../delivery/{id}/arrive-pickup).
  Future<Map<String, dynamic>> arriveAtPickup({
    required int deliveryId,
    required double latitude,
    required double longitude,
  }) async {
    final res = await post(
      ApiConfig.driverDeliveryArrivePickupEndpoint(deliveryId),
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

  /// Collect drop-off payment after OTP (settlement-v2).
  Future<CollectionPaymentResult> collectDeliveryPayment({
    required int deliveryId,
    required String collectionMethod,
    Map<String, dynamic>? paymentDetails,
    String? paymentPhone,
  }) async {
    final body = <String, dynamic>{
      'collection_method': collectionMethod,
    };
    if (paymentDetails != null && paymentDetails.isNotEmpty) {
      body['payment_details'] = paymentDetails;
    }
    final phone = paymentPhone?.trim().isNotEmpty == true
        ? paymentPhone!.trim()
        : paymentDetails?['phone']?.toString();
    if (phone != null && phone.isNotEmpty) {
      body['payment_phone'] = phone;
    }
    final res = await post(
      ApiConfig.driverDeliveryCollectPaymentEndpoint(deliveryId),
      body: body,
      timeout: _paymentRequestTimeout,
    );
    return CollectionPaymentResult.fromJson(res);
  }

  /// Poll electronic collection status for a delivery.
  Future<CollectionPaymentResult> getDeliveryCollectionPaymentStatus(
    int deliveryId, {
    String? paymentReference,
  }) async {
    final query = <String, dynamic>{};
    if (paymentReference != null && paymentReference.isNotEmpty) {
      query['payment_reference'] = paymentReference;
    }
    final res = await get(
      ApiConfig.driverDeliveryCollectionPaymentStatusEndpoint(deliveryId),
      queryParams: query.isEmpty ? null : query,
    );
    return CollectionPaymentResult.fromJson(res);
  }

  /// Complete a delivery (POST /api/driver/services/delivery/complete).
  Future<Map<String, dynamic>> completeDeliveryRequest({
    required int deliveryId,
    required double actualDistance,
    required int actualDuration,
    String? otp,
    double? completionLatitude,
    double? completionLongitude,
    double? completionAccuracy,
    String? completionCapturedAt,
    String? notes,
    String? signatureData,
    List<String>? photos,
  }) async {
    final body = <String, dynamic>{
      'delivery_id': deliveryId,
      'actual_distance': actualDistance,
      'actual_duration': actualDuration,
    };
    if (otp != null && otp.isNotEmpty) body['otp'] = otp;
    if (completionLatitude != null) {
      body['completion_latitude'] = completionLatitude;
    }
    if (completionLongitude != null) {
      body['completion_longitude'] = completionLongitude;
    }
    if (completionAccuracy != null) {
      body['completion_accuracy'] = completionAccuracy;
    }
    if (completionCapturedAt != null && completionCapturedAt.isNotEmpty) {
      body['completion_captured_at'] = completionCapturedAt;
    }
    if (notes != null && notes.isNotEmpty) body['notes'] = notes;
    if (signatureData != null && signatureData.isNotEmpty) {
      body['signature_data'] = signatureData;
    }
    if (photos != null && photos.isNotEmpty) body['photos'] = photos;
    final res = await post('/driver/services/delivery/complete', body: body);
    return res == null ? <String, dynamic>{} : Map<String, dynamic>.from(res as Map);
  }

  /// Resend delivery OTP to customer (POST /api/driver/services/delivery/:id/resend-otp).
  Future<Map<String, dynamic>> resendDeliveryOtp(int deliveryId) async {
    final res = await post(
      '/driver/services/delivery/$deliveryId/resend-otp',
      body: <String, dynamic>{},
    );
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

  /// Cancel an active delivery (services API).
  Future<Map<String, dynamic>> cancelDeliveryRequest(int deliveryId) async {
    final res = await post(
      ApiConfig.driverDeliveryCancelEndpoint(deliveryId),
      body: <String, dynamic>{},
    );
    return res == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(res as Map);
  }

  /// Decline a delivery offer before accept.
  Future<Map<String, dynamic>> declineDeliveryRequest(int deliveryId) async {
    final res = await post(
      ApiConfig.driverDeliveryDeclineEndpoint(deliveryId),
      body: <String, dynamic>{},
    );
    return res == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(res as Map);
  }

  /// @Deprecated Prefer [acceptDeliveryRequest] / [acceptRideRequest].
  Future<Map<String, dynamic>> acceptDriverOrder(int orderId) async {
    return acceptRideRequest(orderId);
  }

  /// @Deprecated Prefer [startDeliveryRequest] / [startRideRequest].
  Future<Map<String, dynamic>> startDriverOrder(int orderId) async {
    return startRideRequest(orderId);
  }

  /// @Deprecated Prefer [completeDeliveryRequest] / [completeRideRequest].
  Future<Map<String, dynamic>> completeDriverOrder(int orderId) async {
    return completeRideRequest(orderId);
  }

  /// @Deprecated Prefer [cancelDeliveryRequest] / [cancelRideRequest].
  Future<Map<String, dynamic>> cancelDriverOrder(int orderId) async {
    return cancelDeliveryRequest(orderId);
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

  /// Update driver location (POST /api/driver/location).
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
    Future<dynamic> postLocation(String endpoint) {
      return post(
        endpoint,
        body: body,
        acceptStaleLocation409: true,
        logTraffic: false,
      );
    }

    dynamic res;
    if (_useLegacyDriverLocationEndpoint) {
      res = await postLocation(ApiConfig.driverUpdateLocationEndpoint);
    } else {
      try {
        res = await postLocation(ApiConfig.driverLocationEndpoint);
      } on NotFoundException {
        _useLegacyDriverLocationEndpoint = true;
        res = await postLocation(ApiConfig.driverUpdateLocationEndpoint);
      }
    }
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
    final res = await post(
      ApiConfig.driverDriverLocationEndpoint,
      body: body,
      logTraffic: false,
    );
    return Map<String, dynamic>.from(res as Map);
  }

  // Driver Registration Methods
  static Future<DriverRegistrationResult> registerDriver(
    DriverRegistrationData registration,
  ) async {
    final logger = AppLogger();
    final stopwatch = Stopwatch()..start();
    const sensitiveFields = {'password', 'password_confirmation', 'device_token'};

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.driverRegisterUrl),
      );
      request.headers['Accept'] = 'application/json';
      request.fields.addAll(registration.toMultipartFields());
      request.files.add(
        await http.MultipartFile.fromPath(
          'profile_picture',
          registration.profilePicture.path,
        ),
      );

      final logBody = <String, dynamic>{
        for (final entry in request.fields.entries)
          if (!sensitiveFields.contains(entry.key)) entry.key: entry.value,
        'profile_picture': registration.profilePicture.path,
      };

      logger.logApiRequest(
        method: 'POST',
        endpoint: ApiConfig.driverRegisterUrl,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'multipart/form-data',
        },
        body: logBody,
      );

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      stopwatch.stop();

      dynamic responseData;
      try {
        responseData = jsonDecode(response.body);
      } catch (_) {
        responseData = {'message': response.body};
      }

      logger.logApiResponse(
        method: 'POST',
        endpoint: ApiConfig.driverRegisterUrl,
        statusCode: response.statusCode,
        headers: response.headers,
        responseBody: responseData,
        duration: stopwatch.elapsed,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return DriverRegistrationResult.success(
          data: responseData,
          message: _registrationMessage(
            responseData,
            'Driver registered successfully.',
          ),
        );
      }

      if (response.statusCode == 422) {
        return DriverRegistrationResult.validationErrors(
          fieldErrors: DriverRegistrationResult.parseFieldErrors(responseData),
          message: _registrationMessage(responseData, 'Validation failed.'),
        );
      }

      if (response.statusCode == 429) {
        return DriverRegistrationResult.rateLimited(
          message: _registrationMessage(
            responseData,
            'Too many registration attempts. Please wait a moment and try again.',
          ),
        );
      }

      if (response.statusCode == 503) {
        return DriverRegistrationResult.unavailable(
          message: _registrationMessage(
            responseData,
            'Driver registration is temporarily unavailable. Please try again.',
          ),
        );
      }

      return DriverRegistrationResult.failure(
        statusCode: response.statusCode,
        message: _registrationMessage(responseData, 'Registration failed.'),
      );
    } catch (e, stackTrace) {
      stopwatch.stop();

      logger.logApiError(
        method: 'POST',
        endpoint: ApiConfig.driverRegisterUrl,
        error: e,
        stackTrace: stackTrace,
        duration: stopwatch.elapsed,
      );

      return DriverRegistrationResult.failure(
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  static String _registrationMessage(dynamic responseData, String fallback) {
    if (responseData is Map) {
      final message = responseData['message']?.toString().trim();
      if (message != null && message.isNotEmpty) return message;
      final errors = responseData['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) return first.first.toString();
        if (first != null) return first.toString();
      }
    }
    return fallback;
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
    String? fcmToken,
    String? deviceType,
    String? deviceId,
    String? appVersion,
    String? osVersion,
  }) async {
    final logger = AppLogger();
    final secureStorage = SecureStorageService();
    final stopwatch = Stopwatch()..start();
    
    try {
      final identifier =
          EthiopianPhoneNumber.normalizeIdentifier(email) ?? email;
      final isPhone = !identifier.contains('@');
      final body = <String, dynamic>{
        'password': password,
        if (isPhone) 'phone': identifier else 'email': identifier,
        // Keep email for backends that still expect it for phone logins.
        if (isPhone) 'email': identifier,
      };
      final token = (fcmToken != null && fcmToken.isNotEmpty)
          ? fcmToken
          : deviceToken;
      if (token != null && token.isNotEmpty) {
        body['fcm_token'] = token;
        body['device_token'] = token;
      }

      final deviceMeta = await DeviceUtils.loginDeviceMetadata(
        appVersion: appVersion,
      );
      body.addAll({
        'device_type': deviceType ?? deviceMeta['device_type'] ?? 'android',
        'app_version': appVersion ?? deviceMeta['app_version'] ?? '1.0.0',
        if ((osVersion ?? deviceMeta['os_version']) != null)
          'os_version': osVersion ?? deviceMeta['os_version'],
        if ((deviceId ?? deviceMeta['device_id']) != null)
          'device_id': deviceId ?? deviceMeta['device_id'],
      });

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
          final userData = Map<String, dynamic>.from(
            responseData['user'] as Map,
          );
          print('🔍 Debug: User data found: $userData');

          await persistLoginUser(userData, secureStorage: secureStorage);

          final applicationStatus =
              ApplicationStatus.fromLoginResponse(responseData);
          if (applicationStatus != null) {
            await secureStorage.saveApplicationStatus(applicationStatus);
          }
          await secureStorage.saveStatusReason(
            ApplicationStatus.reasonFrom(responseData),
          );

          print(
            '👤 User data stored: ID=${userData['id']}, Name=${userData['name']}, Email=${userData['email']}',
          );
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
    final stopwatch = Stopwatch()..start();

    try {
      final body = {
        'phone': _phoneForVerificationApi(phone),
      };

      _logger.logApiRequest(
        method: 'POST',
        endpoint: ApiConfig.sendPhoneVerificationUrl,
        headers: await _getHeaders(),
        body: body,
      );

      final response = await http.post(
        Uri.parse(ApiConfig.sendPhoneVerificationUrl),
        headers: await _getHeaders(),
        body: jsonEncode(body),
      );

      stopwatch.stop();

      dynamic responseData;
      try {
        responseData = jsonDecode(response.body);
      } catch (e) {
        responseData = {'message': response.body};
      }

      _logger.logApiResponse(
        method: 'POST',
        endpoint: ApiConfig.sendPhoneVerificationEndpoint,
        statusCode: response.statusCode,
        headers: response.headers,
        responseBody: responseData,
        duration: stopwatch.elapsed,
      );

      final result = await _handleVerificationHttpResponse(
        response,
        responseData,
      );
      if (result['success'] == true) {
        result['message'] = responseData is Map
            ? (responseData['message'] ??
                'Verification code sent successfully')
            : 'Verification code sent successfully';
      }
      return result;
    } catch (e, stackTrace) {
      stopwatch.stop();

      _logger.logApiError(
        method: 'POST',
        endpoint: ApiConfig.sendPhoneVerificationEndpoint,
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
    final stopwatch = Stopwatch()..start();
    final trimmedCode = code.trim();

    try {
      final body = {
        'phone': _phoneForVerificationApi(phone),
        'code': trimmedCode,
      };

      _logger.logApiRequest(
        method: 'POST',
        endpoint: ApiConfig.verifyPhoneUrl,
        headers: await _getHeaders(),
        body: body,
      );

      final response = await http.post(
        Uri.parse(ApiConfig.verifyPhoneUrl),
        headers: await _getHeaders(),
        body: jsonEncode(body),
      );

      stopwatch.stop();

      dynamic responseData;
      try {
        responseData = jsonDecode(response.body);
      } catch (e) {
        responseData = {'message': response.body};
      }

      _logger.logApiResponse(
        method: 'POST',
        endpoint: ApiConfig.verifyPhoneEndpoint,
        statusCode: response.statusCode,
        headers: response.headers,
        responseBody: responseData,
        duration: stopwatch.elapsed,
      );

      final result = await _handleVerificationHttpResponse(
        response,
        responseData,
      );
      if (result['success'] != true) return result;

      final refresh = await refreshVerificationStatus();
      if (refresh['phoneVerified'] != true) {
        return {
          'success': false,
          'data': responseData,
          'message':
              'Verification could not be confirmed. Please try again.',
        };
      }

      return {
        'success': true,
        'data': responseData,
        'message': responseData is Map
            ? (responseData['message'] ?? 'Phone verified successfully')
            : 'Phone verified successfully',
        'phoneVerified': true,
      };
    } catch (e, stackTrace) {
      stopwatch.stop();

      _logger.logApiError(
        method: 'POST',
        endpoint: ApiConfig.verifyPhoneEndpoint,
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

  /// Register or refresh the FCM device token for the authenticated user.
  Future<void> updateDeviceToken(String deviceToken) async {
    await post(
      ApiConfig.deviceTokenEndpoint,
      body: await _fcmTokenBody(deviceToken),
    );
  }

  /// Remove an FCM device token on logout.
  Future<void> removeDeviceToken(String deviceToken) async {
    await delete(
      ApiConfig.deviceTokenEndpoint,
      body: await _fcmTokenBody(deviceToken),
    );
  }

  Future<Map<String, dynamic>> _fcmTokenBody(String fcmToken) async {
    final meta = await DeviceUtils.loginDeviceMetadata();
    final userIdRaw = await _secureStorage.getUserId();
    final userId = int.tryParse(userIdRaw ?? '');
    return {
      'token': fcmToken,
      'device_type': meta['device_type'] ?? 'android',
      if (userId != null) 'user_id': userId,
      if ((meta['device_id'] ?? '').isNotEmpty) 'device_id': meta['device_id'],
    };
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
  Future<Map<String, dynamic>> getDeliveryConversation(int deliveryId) async {
    final res = await get(ApiConfig.chatPackageDeliveryConversation(deliveryId));
    return _mapResponse(res);
  }

  /// GET /api/chat/package-delivery/{id}/conversation
  /// Creates the conversation only when it does not exist (404), not on server errors.
  Future<Map<String, dynamic>> getOrCreateDeliveryConversation(int deliveryId) async {
    try {
      return await getDeliveryConversation(deliveryId);
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

  /// POST /api/password/reset-otp — unauthenticated.
  static Future<Map<String, dynamic>> requestPasswordResetOtp({
    required String identifier,
    required String method,
  }) {
    return _passwordResetPost(
      url: ApiConfig.passwordResetOtpUrl,
      body: {'identifier': identifier, 'method': method},
      requiredField: 'reset_id',
    );
  }

  /// POST /api/password/verify-otp — unauthenticated.
  static Future<Map<String, dynamic>> verifyPasswordResetOtp({
    required String resetId,
    required String otp,
  }) {
    return _passwordResetPost(
      url: ApiConfig.passwordVerifyOtpUrl,
      body: {'reset_id': resetId, 'otp': otp},
      requiredField: 'reset_token',
    );
  }

  /// POST /api/password/resend-otp — unauthenticated.
  static Future<Map<String, dynamic>> resendPasswordResetOtp({
    required String resetId,
  }) {
    return _passwordResetPost(
      url: ApiConfig.passwordResendOtpUrl,
      body: {'reset_id': resetId},
    );
  }

  /// POST /api/password/reset-with-token — unauthenticated.
  static Future<Map<String, dynamic>> resetPasswordWithToken({
    required String resetToken,
    required String password,
    required String passwordConfirmation,
  }) {
    return _passwordResetPost(
      url: ApiConfig.passwordResetWithTokenUrl,
      body: {
        'reset_token': resetToken,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
      successFallback: ForgotPassword.successFallback,
    );
  }

  static Future<Map<String, dynamic>> _passwordResetPost({
    required String url,
    required Map<String, dynamic> body,
    String? requiredField,
    String? successFallback,
  }) async {
    final logger = AppLogger();
    final stopwatch = Stopwatch()..start();
    try {
      logger.logApiRequest(
        method: 'POST',
        endpoint: url,
        headers: ApiConfig.defaultHeaders,
        body: body,
      );

      final response = await http.post(
        Uri.parse(url),
        headers: ApiConfig.defaultHeaders,
        body: jsonEncode(body),
      );
      stopwatch.stop();

      dynamic responseData;
      try {
        responseData =
            response.body.isEmpty ? null : jsonDecode(response.body);
      } catch (_) {
        responseData = response.body;
      }

      logger.logApiResponse(
        method: 'POST',
        endpoint: url,
        statusCode: response.statusCode,
        headers: response.headers,
        responseBody: responseData,
        duration: stopwatch.elapsed,
      );

      // Surface the error code from the body so callers can branch on it.
      final bodyCode = responseData is Map
          ? responseData['code']?.toString()
          : null;

      final ok = response.statusCode >= 200 && response.statusCode < 300;
      if (!ok) {
        return {
          'success': false,
          'code': bodyCode,
          'data': responseData,
          'message': ForgotPassword.errorMessage(
            response.statusCode,
            responseData,
          ),
        };
      }

      // Support both flat { reset_id, ... } and wrapped { data: { reset_id } }.
      dynamic dataPayload = responseData;
      if (responseData is Map &&
          responseData['data'] is Map &&
          requiredField != null &&
          ForgotPassword.requiredString(responseData, requiredField) == null) {
        dataPayload = responseData['data'];
      }

      if (requiredField != null &&
          ForgotPassword.requiredString(dataPayload, requiredField) == null) {
        return {
          'success': false,
          'data': dataPayload,
          'message': ForgotPassword.invalidServerResponse,
        };
      }

      var message = successFallback ?? '';
      if (responseData is Map &&
          responseData['message'] != null &&
          responseData['message'].toString().trim().isNotEmpty) {
        message = responseData['message'].toString();
      } else if (successFallback != null) {
        message = successFallback;
      }

      return {
        'success': true,
        'code': bodyCode,
        'data': dataPayload,
        'message': message,
      };
    } catch (e, stackTrace) {
      stopwatch.stop();
      logger.logApiError(
        method: 'POST',
        endpoint: url,
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