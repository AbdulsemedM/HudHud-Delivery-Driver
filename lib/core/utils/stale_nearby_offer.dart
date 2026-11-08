import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';

/// Nearby-wave offers that expired or were reserved for another driver.
class StaleNearbyOffer {
  static const fallbackMessage =
      'This nearby offer has expired. Refreshing available requests.';

  static const deliveryUnavailableMessage =
      'This delivery is no longer available.';

  /// Accept refused because the parcel is gone / not offered to this driver.
  static bool isDeliveryNoLongerAvailable(Object error) {
    if (error is GoneException) return true;
    if (error is ConflictException) return error.isNoLongerAvailable;
    return false;
  }

  /// Info snackbar after a failed parcel accept; callers refresh the list.
  static void showDeliveryAcceptFailure(BuildContext context, Object error) {
    showMessageSnackBar(
      context,
      isDeliveryNoLongerAvailable(error)
          ? deliveryUnavailableMessage
          : messageOf(error),
    );
  }

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
