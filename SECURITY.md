# Security

## Exposed Google / Firebase API keys

If you see an alert about exposed API keys (e.g. in `lib/firebase_options.dart` or `ios/Runner/AppDelegate.swift`):

1. **Rotate the keys immediately** in [Google Cloud Console](https://console.cloud.google.com/apis/credentials) (APIs & Services → Credentials):
   - For **Firebase** keys: open the [Firebase console](https://console.firebase.google.com/) → Project settings → your Android/iOS app → download fresh `google-services.json` / `GoogleService-Info.plist`, or regenerate keys in Google Cloud for project `hudhud-delivery-cus`.
   - Delete or restrict the exposed keys, then create replacements.
   - Restrict new keys by API and by app (Android package name / iOS bundle ID).

2. **Do not commit API keys** in this repo. Use a local `.env` file:

   ```bash
   cp .env.example .env
   # Edit .env with real values
   dart run tool/sync_env.dart   # iOS native Maps key
   ```

   | Variable | Used for |
   | --- | --- |
   | `FIREBASE_ANDROID_API_KEY` | Firebase SDK (Dart) on Android |
   | `FIREBASE_IOS_API_KEY` | Firebase SDK (Dart) on iOS |
   | `GOOGLE_MAPS_API_KEY` | Google Maps (Dart, Android manifest, iOS Info.plist) |

   Native Firebase config files (`android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`) remain gitignored.

3. **Dismiss the alert** in GitHub/GitLab after rotating keys and confirming no real keys remain in the current tree.

## Google Maps API key (AppDelegate / AndroidManifest)

Never hardcode Maps keys in `AppDelegate.swift` or Dart source. The app reads iOS keys from `Bundle.main.infoDictionary?["GMS_API_KEY"]` only.
