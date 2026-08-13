import 'package:flutter/services.dart';

/// Reads the Google Maps API key from native build configuration via method channel.
class GoogleMapsApiKeyProvider {
  GoogleMapsApiKeyProvider._();

  static const MethodChannel _channel =
      MethodChannel('hudhud_delivery_driver/config');

  static String? _cachedKey;

  /// Returns the Google Maps API key from the native layer, or empty string if unset.
  static Future<String> getApiKey() async {
    if (_cachedKey != null) {
      return _cachedKey!;
    }
    try {
      final key = await _channel.invokeMethod<String>('getGoogleMapsApiKey');
      _cachedKey = key?.trim() ?? '';
      return _cachedKey!;
    } on PlatformException {
      _cachedKey = '';
      return '';
    } on MissingPluginException {
      _cachedKey = '';
      return '';
    }
  }

  /// Clears the in-memory cache (useful after hot restart in development).
  static void clearCache() {
    _cachedKey = null;
  }
}
