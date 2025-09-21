import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/core/utils/logger.dart';

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