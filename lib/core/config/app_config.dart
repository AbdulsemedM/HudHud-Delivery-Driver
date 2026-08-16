import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  /// API base URL from `.env` (`BASE_URL`), without a trailing slash.
  static String get baseUrl {
    final raw = dotenv.maybeGet('BASE_URL')?.trim();
    if (raw == null || raw.isEmpty) {
      throw StateError(
        'BASE_URL is missing. Set it in the project root `.env` file.',
      );
    }
    return raw.replaceAll(RegExp(r'/+$'), '');
  }

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
