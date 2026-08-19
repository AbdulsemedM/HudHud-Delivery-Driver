import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/core/constants/user_type_constants.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/services/secure_storage_service.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/pages/verification_required_page.dart';

/// Phone verification rules for authenticated users.
class PhoneVerificationGate {
  PhoneVerificationGate._();

  static bool requiresMandatoryPhone(String? userType) {
    return UserTypeConstants.isDriver(userType) ||
        UserTypeConstants.isCourier(userType);
  }

  static Future<bool> isPhoneVerified() async {
    final storage = getIt<SecureStorageService>();
    if (await storage.getUserPhoneVerified()) return true;

    final refresh = await getIt<ApiService>().refreshVerificationStatus();
    return refresh['phoneVerified'] == true;
  }

  /// Blocks until phone is verified or the user leaves the gate.
  static Future<bool> ensurePhoneVerified(BuildContext context) async {
    final storage = getIt<SecureStorageService>();
    final userType = await storage.getUserType();
    if (!requiresMandatoryPhone(userType)) return true;
    if (await isPhoneVerified()) return true;

    final email = await storage.getUserEmail();
    final phone = await storage.getUserPhone();
    final emailVerified = await storage.getUserEmailVerified();

    if (!context.mounted) return false;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (gateContext) => VerificationRequiredPage(
          email: email,
          phone: phone,
          emailVerified: emailVerified,
          phoneVerified: false,
          requirePhoneVerification: true,
          showEmailVerification: false,
          onContinue: () => Navigator.pop(gateContext, true),
        ),
      ),
    );

    if (result == true) return true;
    return isPhoneVerified();
  }
}
