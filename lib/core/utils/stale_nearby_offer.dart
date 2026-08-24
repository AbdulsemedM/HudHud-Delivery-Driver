import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';

/// Nearby-wave offers that expired or were reserved for another driver.
class StaleNearbyOffer {
  static const fallbackMessage =
      'This nearby offer has expired. Refreshing available requests.';

  static bool matches(Object error) {
    if (error is ConflictException) {
      return !error.isActiveJobConflict;
    }
    if (error is GoneException) return true;
    if (error is AppException &&
        error.code == ConflictException.offerNotActiveCode) {
      return true;
    }
    return false;
  }

  static String messageOf(Object error) {
    if (error is AppException && error.message.trim().isNotEmpty) {
      return error.message;
    }
    return fallbackMessage;
  }

  static void showInfoSnackBar(BuildContext context, Object error) {
    showMessageSnackBar(context, messageOf(error));
  }

  static void showMessageSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blueGrey.shade700,
      ),
    );
  }
}
