// Generated from android/app/google-services.json and ios/Runner/GoogleService-Info.plist.
// ignore_for_file: lines_longer_than_80_chars

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for this project.
class DefaultFirebaseOptions {
  /// Options for the current platform, or `null` when that platform is not configured.
  static FirebaseOptions? get maybeCurrentPlatform {
    if (kIsWeb) return null;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return null;
    }
  }

  static FirebaseOptions get currentPlatform {
    final options = maybeCurrentPlatform;
    if (options != null) return options;
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  /// Matches `applicationId` `com.hudhud.admin` in android/app/google-services.json.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCmj-GfPdrGRTlX2mfy1dqiJi6JGBlFIP4',
    appId: '1:284030196855:android:01d1f3ddc37dfa82bc3a72',
    messagingSenderId: '284030196855',
    projectId: 'hudhud-delivery-cus',
    storageBucket: 'hudhud-delivery-cus.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBB0nsMbAYTrd6VCEiMQYpvfq281GqpGAA',
    appId: '1:284030196855:ios:72c4db222b54fe5bbc3a72',
    messagingSenderId: '284030196855',
    projectId: 'hudhud-delivery-cus',
    storageBucket: 'hudhud-delivery-cus.firebasestorage.app',
    iosBundleId: 'com.hudhud.newdriver',
    iosClientId:
        '284030196855-23lgej37bgt3fnfj06qsgjf8ao752n69.apps.googleusercontent.com',
  );
}
