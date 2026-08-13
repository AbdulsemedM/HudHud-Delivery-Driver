import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

import 'package:hudhud_delivery_driver/core/config/env.dart';

/// Firebase configuration for project `hudhud-delivery-cus`.
///
/// API keys are loaded from `.env` (copy from `.env.example`).
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Firebase is not configured for web.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError('Firebase is not configured for macOS.');
      case TargetPlatform.windows:
        throw UnsupportedError('Firebase is not configured for Windows.');
      case TargetPlatform.linux:
        throw UnsupportedError('Firebase is not configured for Linux.');
      default:
        throw UnsupportedError('Unsupported platform.');
    }
  }

  static FirebaseOptions get android => FirebaseOptions(
        apiKey: env('FIREBASE_ANDROID_API_KEY'),
        appId: '1:284030196855:android:01d1f3ddc37dfa82bc3a72',
        messagingSenderId: '284030196855',
        projectId: 'hudhud-delivery-cus',
        storageBucket: 'hudhud-delivery-cus.firebasestorage.app',
      );

  static FirebaseOptions get ios => FirebaseOptions(
        apiKey: env('FIREBASE_IOS_API_KEY'),
        appId: '1:284030196855:ios:2dae708ff0824e4abc3a72',
        messagingSenderId: '284030196855',
        projectId: 'hudhud-delivery-cus',
        storageBucket: 'hudhud-delivery-cus.firebasestorage.app',
        iosBundleId: 'com.hudhud.admin',
      );
}
