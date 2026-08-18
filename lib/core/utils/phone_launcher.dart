import 'package:hudhud_delivery_driver/core/utils/ethiopian_phone_number.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the device dialer for a phone number.
class PhoneLauncher {
  PhoneLauncher._();

  static final RegExp _nonDigits = RegExp(r'\D');

  static String? telPath(String? phone) {
    final canonical = EthiopianPhoneNumber.tryNormalize(phone);
    if (canonical != null) return '+$canonical';
    final digits = (phone ?? '').replaceAll(_nonDigits, '');
    if (digits.isEmpty) return null;
    return digits;
  }

  /// Returns false when the number is missing or the dialer cannot be opened.
  static Future<bool> call(String? phone) async {
    final path = telPath(phone);
    if (path == null) return false;
    final uri = Uri(scheme: 'tel', path: path);
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri);
  }
}
