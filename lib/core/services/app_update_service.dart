import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:hudhud_delivery_driver/core/utils/logger.dart';
import 'package:hudhud_delivery_driver/core/utils/version_compare.dart';

/// Result of a store version check that requires the user to update.
class AppUpdateRequirement {
  const AppUpdateRequirement({
    required this.currentVersion,
    required this.storeVersion,
    required this.storeUrl,
  });

  final String currentVersion;
  final String storeVersion;
  final Uri storeUrl;
}

/// Checks App Store / Play Store for a newer version and opens the store page.
class AppUpdateService {
  AppUpdateService({http.Client? client, AppLogger? logger})
      : _client = client ?? http.Client(),
        _logger = logger ?? AppLogger();

  final http.Client _client;
  final AppLogger _logger;

  static const String androidPackageId = 'com.hudhud.admin';
  static const String iosBundleId = 'com.hudhud.newdriver';

  /// Returns an [AppUpdateRequirement] when the installed app is older than the
  /// store listing. Returns null when up to date, offline, or not on store yet.
  ///
  /// Force-update runs in release builds only so local/debug installs are not
  /// blocked by a published store version. Set `FORCE_UPDATE_IN_DEBUG=true` in
  /// `.env` to exercise the flow during development.
  Future<AppUpdateRequirement?> checkForForcedUpdate() async {
    if (kIsWeb) return null;
    final forceInDebug =
        dotenv.maybeGet('FORCE_UPDATE_IN_DEBUG')?.trim().toLowerCase() == 'true';
    if (!kReleaseMode && !forceInDebug) {
      _logger.debug('App update check skipped outside release builds');
      return null;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final current = packageInfo.version;
      final store = Platform.isIOS
          ? await _fetchIosStoreInfo()
          : Platform.isAndroid
              ? await _fetchAndroidStoreInfo()
              : null;
      if (store == null) return null;

      if (!VersionCompare.isOlderThan(current, store.version)) {
        _logger.debug(
          'App is up to date (current=$current, store=${store.version})',
        );
        return null;
      }

      _logger.info(
        'Force update required: current=$current, store=${store.version}',
      );
      return AppUpdateRequirement(
        currentVersion: current,
        storeVersion: store.version,
        storeUrl: store.url,
      );
    } catch (e, st) {
      _logger.warning('App update check failed; allowing app to continue', e);
      _logger.debug(st.toString());
      return null;
    }
  }

  Future<bool> openStore(Uri storeUrl) async {
    try {
      if (!await canLaunchUrl(storeUrl)) return false;
      return launchUrl(storeUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      _logger.warning('Failed to open store URL: $storeUrl', e);
      return false;
    }
  }

  Future<_StoreInfo?> _fetchIosStoreInfo() async {
    final country = dotenv.maybeGet('APP_STORE_COUNTRY')?.trim();
    final query = <String, String>{
      'bundleId': iosBundleId,
      if (country != null && country.isNotEmpty) 'country': country,
    };
    final uri = Uri.https('itunes.apple.com', '/lookup', query);
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) return null;

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) return null;
    final results = body['results'];
    if (results is! List || results.isEmpty) return null;
    final first = results.first;
    if (first is! Map) return null;

    final version = first['version']?.toString();
    final trackViewUrl = first['trackViewUrl']?.toString();
    if (version == null || version.isEmpty) return null;

    final url = trackViewUrl != null && trackViewUrl.isNotEmpty
        ? Uri.parse(trackViewUrl)
        : Uri.parse('https://apps.apple.com/app/id${first['trackId']}');
    return _StoreInfo(version: version, url: url);
  }

  Future<_StoreInfo?> _fetchAndroidStoreInfo() async {
    final uri = Uri.https(
      'play.google.com',
      '/store/apps/details',
      {'id': androidPackageId, 'hl': 'en', 'gl': 'US'},
    );
    final response = await _client.get(
      uri,
      headers: const {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        'Accept-Language': 'en-US,en;q=0.9',
      },
    ).timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) return null;

    final version = _parsePlayStoreVersion(response.body);
    if (version == null || version.isEmpty) return null;

    return _StoreInfo(version: version, url: uri);
  }

  /// Play Store HTML does not expose a stable API; these patterns cover common
  /// listing markup used by popular Flutter updaters.
  static String? _parsePlayStoreVersion(String html) {
    final patterns = <RegExp>[
      RegExp(r'\[\[\["([\d.]+?)"\]\]'),
      RegExp(r'"softwareVersion"\s*:\s*"([\d.]+)"'),
      RegExp(
        r'Current Version</div><span[^>]*>\s*([\d.]+)\s*</span>',
        caseSensitive: false,
      ),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      final value = match?.group(1)?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }
}

class _StoreInfo {
  const _StoreInfo({required this.version, required this.url});

  final String version;
  final Uri url;
}
