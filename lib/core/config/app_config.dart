class AppConfig {
  // API URLs (aligned with ApiConfig for hudapi.mbitrix.com)
  static const String baseUrl = 'https://hudapi.mbitrix.com';
  
  // Timeouts
  static const int connectionTimeout = 30000; // 30 seconds
  static const int receiveTimeout = 30000; // 30 seconds
  
  // Cache config
  static const int cacheMaxAge = 7 * 24 * 60 * 60 * 1000; // 7 days in milliseconds
  static const int cacheMaxSize = 10 * 1024 * 1024; // 10MB
}