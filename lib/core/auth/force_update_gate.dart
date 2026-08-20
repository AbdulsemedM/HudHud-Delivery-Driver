import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';
import 'package:hudhud_delivery_driver/core/services/app_update_service.dart';

/// Blocks navigation when a newer store version is available.
class ForceUpdateGate {
  ForceUpdateGate._();

  /// Returns true when navigation to the force-update screen already happened.
  static Future<bool> ensureUpToDate(BuildContext context) async {
    final requirement =
        await getIt<AppUpdateService>().checkForForcedUpdate();
    if (requirement == null) return false;
    if (!context.mounted) return true;
    context.goNamed(AppRouter.forceUpdate, extra: requirement);
    return true;
  }
}
