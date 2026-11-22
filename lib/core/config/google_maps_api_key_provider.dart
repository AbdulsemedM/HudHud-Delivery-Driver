import 'package:flutter/services.dart';

/// Reads the Google keys from native build configuration via method channel.
///
/// THERE ARE TWO KEYS AND THEY ARE NOT INTERCHANGEABLE.
///
/// [getApiKey] is the Maps SDK key — the one in the Android manifest as
/// `com.google.android.geo.API_KEY`, used to draw map tiles. It carries an
/// "Android apps" application restriction, which only the Maps SDKs honour.
///
/// [getWebKey] is for anything that talks to `maps.googleapis.com` over HTTPS:
/// Places autocomplete, place details, Geocoding, Directions. Google does not
/// apply Android application restrictions to those endpoints — a key carrying
/// one is rejected with REQUEST_DENIED — so they need a separate,
/// app-unrestricted key narrowed by API restriction instead.
///
/// Sending the SDK key to a web service fails *invisibly from the rider's
/// seat*: the map still renders, and only address lookup and the route
/// polyline stop working. If you add a new call to maps.googleapis.com, use
/// [getWebKey].
class GoogleMapsApiKeyProvider {
  GoogleMapsApiKeyProvider._();

  static const MethodChannel _channel =
      MethodChannel('hudhud_delivery_driver/config');

  static String? _cachedKey;
  static String? _cachedWebKey;

  /// Returns the Maps SDK key from the native layer, or empty string if unset.
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

  /// Returns the key for maps.googleapis.com web services.
  ///
  /// Falls back to [getApiKey] when the native binary predates the split — an
  /// older build answers `getGoogleMapsWebKey` with MissingPluginException,
  /// and behaving as before beats returning empty and breaking address lookup
  /// for every rider on that build.
  static Future<String> getWebKey() async {
    if (_cachedWebKey != null) {
      return _cachedWebKey!;
    }
    try {
      final key = await _channel.invokeMethod<String>('getGoogleMapsWebKey');
      final resolved = key?.trim() ?? '';
      _cachedWebKey = resolved.isNotEmpty ? resolved : await getApiKey();
      return _cachedWebKey!;
    } on PlatformException {
      _cachedWebKey = await getApiKey();
      return _cachedWebKey!;
    } on MissingPluginException {
      _cachedWebKey = await getApiKey();
      return _cachedWebKey!;
    }
  }

  /// Clears the in-memory cache (useful after hot restart in development).
  static void clearCache() {
    _cachedKey = null;
    _cachedWebKey = null;
  }
}
