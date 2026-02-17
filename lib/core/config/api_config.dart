class ApiConfig {
  static const String baseUrl = 'https://hudapi.mbitrix.com';

  // Auth endpoints
  static const String registerEndpoint = '/api/register';
  static const String driverRegisterEndpoint = '/api/driver/driver/register';
  static const String handymanRegisterEndpoint = '/api/handyman/register';
  static const String loginEndpoint = '/api/login';
  static const String sendEmailVerificationEndpoint =
      '/api/send-email-verification';
  static const String verifyEmailEndpoint = '/api/verify-email';
  static const String sendPhoneVerificationEndpoint =
      '/api/send-phone-verification-code';
  static const String verifyPhoneEndpoint = '/api/verify-phone';

  // Driver profile (authenticated)
  static const String driverProfileEndpoint = '/api/driver/driver/profile';

  // Handyman profile (authenticated — returns user + handyman_profile + recent_services)
  static const String handymanAuthProfileEndpoint = '/api/handyman/profile';

  // Handyman service requests (available list)
  static const String handymanServiceRequestsEndpoint =
      '/api/handyman/service-requests/available';

  // Handyman earnings (total, weekly, balance, transactions)
  static const String handymanEarningsEndpoint = '/api/handyman/earnings';

  // Handyman service history (completed services)
  static const String handymanServiceHistoryEndpoint =
      '/api/handyman/service-history';

  // Driver ride history (paginated)
  static const String driverHistoryEndpoint = '/api/driver/driver/history';

  // Driver earnings (total, weekly, current_balance, transactions)
  static const String driverEarningsEndpoint = '/api/driver/driver/earnings';

  // Driver available orders (list of orders ready for pickup / unassigned)
  static const String driverAvailableOrdersEndpoint = '/api/driver/driver/orders/available';

  // Driver profile documents (multipart upload)
  static const String driverProfileDocumentsEndpoint = '/api/driver/profile/documents';

  // Driver availability (go online/offline)
  static const String driverAvailabilityEndpoint = '/api/driver/availability';

  // Driver location update (full: active ride)
  static const String driverLocationEndpoint = '/api/driver/location';

  // Driver location (simple: no active ride) — latitude, longitude, order_id
  static const String driverDriverLocationEndpoint = '/api/driver/driver/location';

  // Full URLs
  static String get registerUrl => '$baseUrl$registerEndpoint';
  static String get driverRegisterUrl => '$baseUrl$driverRegisterEndpoint';
  static String get handymanRegisterUrl => '$baseUrl$handymanRegisterEndpoint';
  static String get loginUrl => '$baseUrl$loginEndpoint';
  static String get sendEmailVerificationUrl =>
      '$baseUrl$sendEmailVerificationEndpoint';
  static String get verifyEmailUrl => '$baseUrl$verifyEmailEndpoint';
  static String get sendPhoneVerificationUrl =>
      '$baseUrl$sendPhoneVerificationEndpoint';
  static String get verifyPhoneUrl => '$baseUrl$verifyPhoneEndpoint';

  // Admin endpoints (list users by type, get/update user, handyman profile)
  static const String adminUsersEndpoint = '/api/admin/users';
  static const String userByIdEndpoint = '/api/users';
  static const String handymanProfileEndpoint = '/api/handyman-profile';

  // Headers
  static Map<String, String> get defaultHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
}
