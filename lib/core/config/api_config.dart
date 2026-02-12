class ApiConfig {
  static const String baseUrl = 'https://hudapi.mbitrix.com';

  // Auth endpoints
  static const String registerEndpoint = '/api/register';
  static const String loginEndpoint = '/api/login';
  static const String sendEmailVerificationEndpoint =
      '/api/send-email-verification';
  static const String verifyEmailEndpoint = '/api/verify-email';
  static const String sendPhoneVerificationEndpoint =
      '/api/send-phone-verification-code';
  static const String verifyPhoneEndpoint = '/api/verify-phone';

  // Full URLs
  static String get registerUrl => '$baseUrl$registerEndpoint';
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
