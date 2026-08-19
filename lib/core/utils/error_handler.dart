import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/core/models/active_job.dart';
import 'package:hudhud_delivery_driver/core/utils/logger.dart';

/// Parses Laravel-style API error bodies: `{ message, errors: { field: [...] } }`.
String extractApiErrorMessage(
  dynamic body, {
  String fallback = 'Request failed',
}) {
  if (body is! Map) return fallback;

  final message = body['message']?.toString().trim();
  if (message != null && message.isNotEmpty) return message;

  final errors = body['errors'];
  if (errors is Map && errors.isNotEmpty) {
    for (final value in errors.values) {
      if (value is List && value.isNotEmpty) return value.first.toString();
      if (value != null) return value.toString();
    }
  }

  return fallback;
}

// Base exception class
class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  AppException(this.message, {this.code, this.details});

  @override
  String toString() => 'AppException: $message (Code: $code)';
}

// Network exceptions
class NetworkException extends AppException {
  NetworkException(String message, {String? code, dynamic details})
      : super(message, code: code, details: details);
}

// API exceptions
class ApiException extends AppException {
  ApiException(String message, {String? code, dynamic details})
      : super(message, code: code, details: details);
}

class BadRequestException extends ApiException {
  BadRequestException(String message, {String? code, dynamic details})
      : super(message, code: code ?? '400', details: details);
}

class UnauthorizedException extends ApiException {
  UnauthorizedException(String message, {String? code, dynamic details})
      : super(message, code: code ?? '401', details: details);
}

class ForbiddenException extends ApiException {
  ForbiddenException(String message, {String? code, dynamic details})
      : super(message, code: code ?? '403', details: details);
}

class NotFoundException extends ApiException {
  NotFoundException(String message, {String? code, dynamic details})
      : super(message, code: code ?? '404', details: details);
}

class ConflictException extends ApiException {
  static const String activeJobConflictCode = 'DRIVER_ACTIVE_JOB_CONFLICT';
  static const String offerNotActiveCode = 'DRIVER_OFFER_NOT_ACTIVE';

  ConflictException(String message, {String? code, dynamic details})
      : super(message, code: code ?? '409', details: details);

  Map<String, dynamic>? get _detailsMap {
    final value = details;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  bool get isActiveJobConflict {
    if (code == activeJobConflictCode) return true;
    return _detailsMap?['code']?.toString() == activeJobConflictCode;
  }

  bool get isOfferNotActive {
    if (isActiveJobConflict) return false;
    if (code == offerNotActiveCode) return true;
    return _detailsMap?['code']?.toString() == offerNotActiveCode;
  }

  bool get isUnavailable {
    if (isActiveJobConflict) return false;
    return _detailsMap?['reason']?.toString() == 'unavailable';
  }

  ActiveJob? get activeJob => ActiveJob.fromJson(_detailsMap?['active_job']);
}

class GoneException extends ApiException {
  GoneException(String message, {String? code, dynamic details})
      : super(message, code: code ?? '410', details: details);
}

class LockedException extends ApiException {
  LockedException(String message, {String? code, dynamic details})
      : super(message, code: code ?? '423', details: details);
}

class TooManyRequestsException extends ApiException {
  TooManyRequestsException(String message, {String? code, dynamic details})
      : super(message, code: code ?? '429', details: details);
}

class ServerException extends ApiException {
  ServerException(String message, {String? code, dynamic details})
      : super(message, code: code ?? '500', details: details);
}

// Storage exceptions
class StorageException extends AppException {
  StorageException(String message, {String? code, dynamic details})
      : super(message, code: code, details: details);
}

// Global error handler
class ErrorHandler {
  final AppLogger _logger;

  ErrorHandler(this._logger);

  void handleError(dynamic error, {StackTrace? stackTrace}) {
    _logger.error('Error: $error');
    if (stackTrace != null) {
      _logger.error('StackTrace: $stackTrace');
    }

    // Additional error reporting could be added here
    // e.g., Sentry, Firebase Crashlytics, etc.
  }

  String getErrorMessage(dynamic error) {
    if (error is AppException) {
      return error.message;
    } else if (error is Error || error is Exception) {
      return error.toString();
    } else {
      return 'An unexpected error occurred';
    }
  }

  void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}