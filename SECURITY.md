# Security

## Exposed Google / Firebase API keys

If you see an alert about exposed API keys in git history:

1. **Rotate the keys immediately** in [Google Cloud Console](https://console.cloud.google.com/apis/credentials).
2. **Never commit secrets** — see [ENV_SECRETS.md](ENV_SECRETS.md) for the local-only setup.
3. **Dismiss the alert** after rotating keys and confirming no real keys remain in the current tree.

## Where secrets belong

| Secret | Location |
|--------|----------|
| Google Maps API key | `.env` (Android) or `ios/Flutter/LocalSecrets.xcconfig` (iOS) |
| Firebase config | Gitignored `google-services.json` / `GoogleService-Info.plist` |
| Release signing | Gitignored `android/key.properties` |

Never hardcode API keys in Dart source, `AppDelegate.swift`, or committed config files.
