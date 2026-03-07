# Security

## Google API key (exposed in history)

If you see an alert about an exposed Google API key in `ios/Runner/AppDelegate.swift` (e.g. commit 54ba0b35):

1. **Rotate the key immediately** in [Google Cloud Console](https://console.cloud.google.com/apis/credentials):
   - Open your project → APIs & Services → Credentials.
   - Delete or restrict the exposed key, then create a new API key.
   - Restrict the new key (e.g. by API: Maps SDK for Android/iOS, Geocoding; by app bundle ID / package name).

2. **Do not commit API keys** in this repo. Use:
   - **Android:** `android/local.properties` with `GOOGLE_MAPS_API_KEY=your_key` (this file is gitignored by Flutter).
   - **iOS:** Set `GMS_API_KEY` in `ios/Runner/Info.plist` locally, or use a gitignored `ios/Secrets.xcconfig` and wire it into the build. The app reads the key from `Bundle.main.infoDictionary?["GMS_API_KEY"]` only; never hardcode it in `AppDelegate.swift`.

3. **Dismiss the alert** in GitHub/GitLab after rotating the key and confirming no key is present in the current tree.
