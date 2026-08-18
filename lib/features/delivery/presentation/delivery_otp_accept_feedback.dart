import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/core/models/delivery_otp.dart';

/// Non-blocking accept-time OTP SMS feedback for drivers.
class DeliveryOtpAcceptFeedback {
  DeliveryOtpAcceptFeedback._();

  static void showIfNeeded(
    BuildContext context,
    Map<String, dynamic> acceptResponse,
  ) {
    final result = DeliveryOtpDeliveryResult.fromAcceptResponse(acceptResponse);
    if (result == null) return;

    if (result.code == DeliveryOtpDeliveryResult.sentCode) {
      return;
    }

    if (result.smsNeedsRetry) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message ??
                'Delivery accepted, but the customer SMS could not be sent. '
                    'Use Resend code on the completion screen.',
          ),
          backgroundColor: Colors.orange.shade800,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}
