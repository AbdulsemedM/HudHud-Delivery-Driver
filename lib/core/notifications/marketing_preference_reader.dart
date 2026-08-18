import 'dart:convert';

import 'package:hudhud_delivery_driver/core/constants/user_type_constants.dart';
import 'package:hudhud_delivery_driver/core/services/secure_storage_service.dart';

/// Reads marketing notification preference from profile or stored user data.
class MarketingPreferenceReader {
  MarketingPreferenceReader(this._secureStorage);

  final SecureStorageService _secureStorage;

  static const _marketingKeys = [
    'marketing_notifications_enabled',
    'marketing_enabled',
    'accepts_marketing',
    'promotions_enabled',
    'marketing_opt_in',
  ];

  /// Returns whether the user has opted in to marketing/promotions notifications.
  /// Defaults to false when preference is unknown.
  bool readFromMap(Map<String, dynamic>? profile) {
    if (profile == null) return false;

    final user = profile['user'];
    if (user is Map<String, dynamic>) {
      final fromUser = _readMarketingFlag(user);
      if (fromUser != null) return fromUser;
    }

    return _readMarketingFlag(profile) ?? false;
  }

  Future<bool> readFromStoredUserData() async {
    final raw = await _secureStorage.getUserData();
    if (raw == null || raw.isEmpty) return false;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return _readMarketingFlag(decoded) ?? false;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> resolve({
    required String? userType,
    Map<String, dynamic>? driverProfile,
    Map<String, dynamic>? handymanProfile,
  }) async {
    if (UserTypeConstants.isHandyman(userType)) {
      if (readFromMap(handymanProfile)) return true;
    } else if (readFromMap(driverProfile)) {
      return true;
    }
    return readFromStoredUserData();
  }

  bool? _readMarketingFlag(Map<String, dynamic> map) {
    for (final key in _marketingKeys) {
      final parsed = _parseBool(map[key]);
      if (parsed != null) return parsed;
    }

    for (final nestedKey in ['notification_preferences', 'preferences']) {
      final nested = map[nestedKey];
      if (nested is Map<String, dynamic>) {
        for (final key in ['marketing', 'promotions', 'marketing_notifications']) {
          final parsed = _parseBool(nested[key]);
          if (parsed != null) return parsed;
        }
      }
    }

    return null;
  }

  bool? _parseBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is int) return value == 1;
    final s = value.toString().toLowerCase();
    if (s == 'true' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'no') return false;
    return null;
  }
}
