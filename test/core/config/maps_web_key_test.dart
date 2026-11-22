import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/config/google_maps_api_key_provider.dart';

/// The Maps SDK key and the web-services key must not be confused.
///
/// Google applies an "Android apps" application restriction to the Maps SDKs
/// ONLY. The maps.googleapis.com web services — Places autocomplete, place
/// details, Geocoding, Directions — reject a key carrying such a restriction
/// with REQUEST_DENIED.
///
/// That makes this the nastiest kind of regression, because it fails
/// asymmetrically: the map still draws, so the app looks healthy, and what
/// breaks is address lookup and the route polyline — the two things a rider
/// needs to actually find the pickup.
///
/// It nearly shipped that way: one shared key worked only because it was
/// unrestricted, and locking it down to com.hudhud.admin would have taken
/// those with it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('hudhud_delivery_driver/config');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// [webKey] null means the native side does not implement the method at all,
  /// which is what an older binary does.
  void stubNative({required String sdkKey, String? webKey}) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'getGoogleMapsApiKey':
          return sdkKey;
        case 'getGoogleMapsWebKey':
          if (webKey == null) {
            throw MissingPluginException('No implementation for getGoogleMapsWebKey');
          }
          return webKey;
        default:
          throw MissingPluginException(call.method);
      }
    });
  }

  setUp(GoogleMapsApiKeyProvider.clearCache);

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    GoogleMapsApiKeyProvider.clearCache();
  });

  test('the two keys are read from two different native methods', () async {
    stubNative(sdkKey: 'SDK-KEY', webKey: 'WEB-KEY');

    expect(await GoogleMapsApiKeyProvider.getApiKey(), 'SDK-KEY');
    expect(await GoogleMapsApiKeyProvider.getWebKey(), 'WEB-KEY');
  });

  /// An older native binary answers with MissingPluginException. Returning
  /// empty there would break address lookup for every rider on that build,
  /// which is worse than the restriction problem this split is solving.
  test('an older binary without the web method falls back to the SDK key', () async {
    stubNative(sdkKey: 'SDK-KEY', webKey: null);

    expect(await GoogleMapsApiKeyProvider.getWebKey(), 'SDK-KEY');
  });

  /// Same reasoning for a build where only the old secret is configured:
  /// build.gradle hands back an empty string rather than failing the build.
  test('an empty web key falls back to the SDK key rather than to empty', () async {
    stubNative(sdkKey: 'SDK-KEY', webKey: '');

    expect(await GoogleMapsApiKeyProvider.getWebKey(), 'SDK-KEY');
  });

  test('clearCache clears both keys, not just the SDK one', () async {
    stubNative(sdkKey: 'SDK-1', webKey: 'WEB-1');
    expect(await GoogleMapsApiKeyProvider.getWebKey(), 'WEB-1');

    GoogleMapsApiKeyProvider.clearCache();
    stubNative(sdkKey: 'SDK-2', webKey: 'WEB-2');

    expect(await GoogleMapsApiKeyProvider.getWebKey(), 'WEB-2');
  });

  /// The guard that actually prevents the regression coming back.
  ///
  /// In a diff, `getApiKey()` and `getWebKey()` are nearly the same string, and
  /// both compile, both run, and both return something that looks like a key.
  /// The only thing that tells them apart is which Google endpoint accepts the
  /// result — which no unit test can observe without calling Google. So assert
  /// the rule at the source level instead: anything that builds a
  /// maps.googleapis.com URL must take the web key.
  test('every maps.googleapis.com caller uses the web key, not the SDK key', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;

      final source = entity.readAsStringSync();
      if (!source.contains('maps.googleapis.com')) continue;
      if (!source.contains('GoogleMapsApiKeyProvider.getApiKey()')) continue;

      offenders.add(entity.path);
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'These files call maps.googleapis.com with the Maps SDK key:\n  ${offenders.join('\n  ')}\n\n'
          'The SDK key carries an Android application restriction, which Google '
          'applies only to the Maps SDKs. Web-service endpoints reject it with '
          'REQUEST_DENIED, and the failure is invisible — the map keeps drawing '
          'and only address lookup dies. Use GoogleMapsApiKeyProvider.getWebKey().',
    );
  });
}
