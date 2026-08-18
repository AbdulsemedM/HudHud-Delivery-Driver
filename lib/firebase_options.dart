// File generated from ios/Runner/GoogleService-Info.plist.
// Ignore for platform coverage until Android/web options are added.
// ignore_for_file: lines_longer_than_80_chars

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for this project.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.android:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for android. '
          'Add android/app/google-services.json and regenerate options.',
        );
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
