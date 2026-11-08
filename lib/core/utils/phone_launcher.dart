import 'package:hudhud_delivery_driver/core/utils/ethiopian_phone_number.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the device dialer (or SMS app) for a phone number.
class PhoneLauncher {
  PhoneLauncher._();

  static final RegExp _nonDigits = RegExp(r'\D');

  /// Dialable path: Ethiopian numbers as `+2519…`; other international
  /// numbers (`+252…` Somaliland gift recipients, or 11+ digits with a
  /// country code) keep a leading `+`; short local numbers stay as digits.
  static String? telPath(String? phone) {
    final canonical = EthiopianPhoneNumber.tryNormalize(phone);
    if (canonical != null) return '+$canonical';
    final raw = (phone ?? '').trim();
    final digits = raw.replaceAll(_nonDigits, '');
    if (digits.isEmpty) return null;
    if (raw.startsWith('+')) return '+$digits';
    if (raw.startsWith('00') && digits.length > 2) {
      return '+${digits.substring(2)}';
    }
    if (digits.length >= 11) return '+$digits';
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

  /// Opens the SMS composer; false when the number is missing or no SMS app.
  static Future<bool> sms(String? phone) async {
    final path = telPath(phone);
    if (path == null) return false;
    final uri = Uri(scheme: 'sms', path: path);
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri);
  }
}
