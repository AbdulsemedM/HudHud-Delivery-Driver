class ApiConfig {
  static const String baseUrl = 'https://hudapi.mbitrix.com';
  
  // Auth endpoints
  static const String registerEndpoint = '/api/register';
  static const String loginEndpoint = '/api/login';
  static const String verifyEmailEndpoint = '/api/verify-email';
  static const String verifyPhoneEndpoint = '/api/verify-phone';
  
  // Full URLs
  static String get registerUrl => '$baseUrl$registerEndpoint';
  static String get loginUrl => '$baseUrl$loginEndpoint';
  static String get verifyEmailUrl => '$baseUrl$verifyEmailEndpoint';
  static String get verifyPhoneUrl => '$baseUrl$verifyPhoneEndpoint';
  
  // Headers
  static Map<String, String> get defaultHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}