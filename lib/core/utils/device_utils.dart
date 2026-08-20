import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class DeviceUtils {
  static Future<String?> getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor;
    }
    return null;
  }

  static Future<String> appVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      return '1.0.0';
    }
  }

  /// Handbook login fields: device_type, device_id, app_version, os_version.
  static Future<Map<String, String>> loginDeviceMetadata({
    String? appVersion,
  }) async {
    final deviceInfo = DeviceInfoPlugin();
    String deviceType = 'android';
    String osVersion = '';
    String? deviceId;
    final resolvedVersion = appVersion ?? await DeviceUtils.appVersion();

    try {
      if (kIsWeb) {
        deviceType = 'web';
        final web = await deviceInfo.webBrowserInfo;
        osVersion = web.platform?.toString() ?? 'web';
        deviceId = web.userAgent;
      } else if (Platform.isAndroid) {
        deviceType = 'android';
        final android = await deviceInfo.androidInfo;
        osVersion = 'Android ${android.version.release}';
        deviceId = android.id;
      } else if (Platform.isIOS) {
        deviceType = 'ios';
        final ios = await deviceInfo.iosInfo;
        osVersion = '${ios.systemName} ${ios.systemVersion}';
        deviceId = ios.identifierForVendor;
      } else {
        deviceType = Platform.operatingSystem;
        osVersion = Platform.operatingSystemVersion;
      }
    } catch (_) {
      deviceType = kIsWeb
          ? 'web'
          : (Platform.isIOS ? 'ios' : 'android');
    }

    return {
      'device_type': deviceType,
      'app_version': resolvedVersion,
      if (osVersion.isNotEmpty) 'os_version': osVersion,
      if (deviceId != null && deviceId.isNotEmpty) 'device_id': deviceId,
    };
  }
}
