import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hudhud_delivery_driver/core/constants/application_status.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';
import 'package:hudhud_delivery_driver/core/services/secure_storage_service.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';

/// Routes a driver to pending/suspended screens and persists the status.
class ApplicationStatusGate {
  ApplicationStatusGate._();

  static String? routeFor(String? status) {
    if (status == ApplicationStatus.pending) {
      return AppRouter.applicationPending;
    }
    if (status == ApplicationStatus.suspended) {
      return AppRouter.applicationSuspended;
    }
    return null;
  }

  /// Path of the screen [routeFor] returns, used to avoid re-navigating.
  static String? pathFor(String? status) {
    if (status == ApplicationStatus.pending) {
      return AppRouter.applicationPendingPath;
    }
    if (status == ApplicationStatus.suspended) {
      return AppRouter.applicationSuspendedPath;
    }
    return null;
  }

  static Future<void> persist(String status, {String? reason}) async {
    final storage = getIt<SecureStorageService>();
    await storage.saveApplicationStatus(status);
    await storage.saveStatusReason(reason);
  }

  /// Returns true when [error] is a work-action 403 for pending/suspended
  /// (`{message, application_status, status_reason}` from DriverEligibility).
  /// The caller must stop polling/retrying when this returns true.
  static Future<bool> handleForbidden(
    BuildContext context,
    Object error,
  ) async {
    if (error is! ForbiddenException) return false;
    final status = ApplicationStatus.fromExceptionDetails(error.details);
    if (status == null ||
        (status != ApplicationStatus.pending &&
            status != ApplicationStatus.suspended)) {
      return false;
    }
    await persist(status, reason: ApplicationStatus.reasonFrom(error.details));
    if (!context.mounted) return true;
    final route = routeFor(status);
    if (route == null) return true;
    // Several in-flight calls (poll + accept) can 403 together; navigate once.
    final current = AppRouter.router.routeInformationProvider.value.uri.path;
    if (current == pathFor(status)) return true;
    context.goNamed(route);
    return true;
  }
}
