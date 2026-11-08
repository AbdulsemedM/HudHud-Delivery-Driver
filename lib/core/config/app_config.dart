class AppConfig {
  /// Production API base URL (public, not a secret). Override per build with
  /// `--dart-define=BASE_URL=...` or `--dart-define-from-file=<file>`.
  static const String _defaultBaseUrl = 'https://api.hudhuddelivery.com/api/';

  static const String _baseUrlDefine =
      String.fromEnvironment('BASE_URL', defaultValue: _defaultBaseUrl);

  /// API base URL (`BASE_URL` compile-time define), without a trailing slash.
  static String get baseUrl {
    final raw = _baseUrlDefine.trim();
    final value = raw.isEmpty ? _defaultBaseUrl : raw;
    return value.replaceAll(RegExp(r'/+$'), '');
  }

  /// Optional App Store country code for the iOS version lookup
  /// (`--dart-define=APP_STORE_COUNTRY=et`). Empty means no country filter.
  static const String appStoreCountry =
      String.fromEnvironment('APP_STORE_COUNTRY');

  /// Exercise the force-update flow in debug/profile builds
  /// (`--dart-define=FORCE_UPDATE_IN_DEBUG=true`).
  static const bool forceUpdateInDebug =
      bool.fromEnvironment('FORCE_UPDATE_IN_DEBUG');

  /// Site origin without `/api` (avatars, storage paths).
  static String get originUrl {
    final url = baseUrl;
    if (url.endsWith('/api')) {
      return url.substring(0, url.length - 4);
    }
    return url;
  }

  // Timeouts
  static const int connectionTimeout = 30000; // 30 seconds
  static const int receiveTimeout = 30000; // 30 seconds

  // Cache config
  static const int cacheMaxAge = 7 * 24 * 60 * 60 * 1000; // 7 days in milliseconds
  static const int cacheMaxSize = 10 * 1024 * 1024; // 10MB
}
