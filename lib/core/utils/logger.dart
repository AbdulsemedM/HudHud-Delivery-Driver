import 'package:logger/logger.dart';
import 'dart:convert';

class AppLogger {
  static const int maxLogChars = 2000;

  late final Logger _logger;

  AppLogger() {
    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 0,
        errorMethodCount: 4,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        printTime: true,
      ),
      level: Level.debug,
    );
  }

  void debug(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(_clip(message), error: error, stackTrace: stackTrace);
  }

  void info(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(_clip(message), error: error, stackTrace: stackTrace);
  }

  void warning(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(_clip(message), error: error, stackTrace: stackTrace);
  }

  void error(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(_clip(message), error: error, stackTrace: stackTrace);
  }

  void fatal(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(_clip(message), error: error, stackTrace: stackTrace);
  }

  // API Logging Methods
  void logApiRequest({
    required String method,
    required String endpoint,
    Map<String, String>? headers,
    dynamic body,
  }) {
    final logMessage = StringBuffer();
    logMessage.writeln('🚀 API REQUEST');
    logMessage.writeln('Method: $method');
    logMessage.writeln('Endpoint: $endpoint');
    
    if (headers != null && headers.isNotEmpty) {
      logMessage.writeln('Headers: ${_formatJson(_safeHeaders(headers))}');
    }
    
    if (body != null) {
      logMessage.writeln('Body: ${_formatJson(redactSensitive(body))}');
    }
    
    info(logMessage.toString());
  }

  void logApiResponse({
    required String method,
    required String endpoint,
    required int statusCode,
    Map<String, String>? headers,
    dynamic responseBody,
    Duration? duration,
  }) {
    final logMessage = StringBuffer();
    final isSuccess = statusCode >= 200 && statusCode < 300;
    
    logMessage.writeln(isSuccess ? '✅ API RESPONSE SUCCESS' : '❌ API RESPONSE ERROR');
    logMessage.writeln('Method: $method');
    logMessage.writeln('Endpoint: $endpoint');
    logMessage.writeln('Status Code: $statusCode');
    
    if (duration != null) {
      logMessage.writeln('Duration: ${duration.inMilliseconds}ms');
    }

    if (headers != null && headers.isNotEmpty) {
      logMessage.writeln('Response headers: ${headers.length} fields');
    }
    
    if (responseBody != null) {
      logMessage.writeln(
        'Response Body: ${_formatJson(redactSensitive(responseBody))}',
      );
    }
    
    if (isSuccess) {
      info(logMessage.toString());
    } else {
      error(logMessage.toString());
    }
  }

  void logApiError({
    required String method,
    required String endpoint,
    required dynamic error,
    StackTrace? stackTrace,
    Duration? duration,
  }) {
    final logMessage = StringBuffer();
    logMessage.writeln('💥 API ERROR');
    logMessage.writeln('Method: $method');
    logMessage.writeln('Endpoint: $endpoint');
    
    if (duration != null) {
      logMessage.writeln('Duration: ${duration.inMilliseconds}ms');
    }
    
    logMessage.writeln('Error: ${redactSensitive(error)}');
    
    this.error(logMessage.toString(), error, stackTrace);
  }

  static const _redacted = '[REDACTED]';
  static const _sensitiveKeys = {
    'otp',
    'authorization',
    'cookie',
    'set-cookie',
    'qr_code',
    'qpay_qr_code',
  };

  static String truncate(String value, {int maxChars = maxLogChars}) {
    if (value.length <= maxChars) return value;
    final omitted = value.length - maxChars;
    return '${value.substring(0, maxChars)}\n… [truncated $omitted chars]';
  }

  static dynamic _clip(dynamic message) {
    if (message == null) return message;
    return truncate(message.toString());
  }

  static Map<String, String> _safeHeaders(Map<String, String> headers) {
    return headers.map((key, value) {
      if (_sensitiveKeys.contains(key.toLowerCase())) {
        return MapEntry(key, _redacted);
      }
      return MapEntry(key, value);
    });
  }

  /// Recursively redacts sensitive keys such as `otp` from log payloads.
  static dynamic redactSensitive(dynamic data) {
    if (data is Map) {
      return data.map((key, value) {
        if (_sensitiveKeys.contains(key.toString().toLowerCase())) {
          return MapEntry(key, _redacted);
        }
        return MapEntry(key, redactSensitive(value));
      });
    }
    if (data is List) {
      return data.map(redactSensitive).toList();
    }
    if (data is String) {
      try {
        final parsed = jsonDecode(data);
        if (parsed is Map || parsed is List) {
          return jsonEncode(redactSensitive(parsed));
        }
      } catch (_) {}
    }
    return data;
  }

  String _formatJson(dynamic data) {
    try {
      String formatted;
      if (data is String) {
        try {
          final parsed = jsonDecode(data);
          formatted = const JsonEncoder.withIndent('  ').convert(parsed);
        } catch (e) {
          formatted = data;
        }
      } else if (data is Map || data is List) {
        formatted = const JsonEncoder.withIndent('  ').convert(data);
      } else {
        formatted = data.toString();
      }
      return truncate(formatted);
    } catch (e) {
      return truncate(data.toString());
    }
  }
}