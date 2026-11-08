# hudhud_delivery_driver

HudHud driver / courier app (Android `com.hudhud.admin`).

## Configuration

### Dart settings (compile-time `--dart-define`)

The app no longer bundles a `.env` asset. Dart-side settings are compile-time
defines with safe, non-secret defaults:

| Key | Default | Purpose |
| --- | --- | --- |
| `BASE_URL` | `https://api.hudhuddelivery.com/api/` | API base URL (include `/api/`) |
| `APP_STORE_COUNTRY` | empty | Optional iOS App Store lookup country (e.g. `et`) |
| `FORCE_UPDATE_IN_DEBUG` | `false` | Exercise the force-update flow in debug/profile |

Production builds need no defines. To point at another backend:

```sh
flutter run --dart-define=BASE_URL=https://staging.example.com/api/
```

Or keep the values in a JSON file (no secrets in it, since defines are compiled into the app):

```json
// dart_defines.staging.json
{ "BASE_URL": "https://staging.example.com/api/", "FORCE_UPDATE_IN_DEBUG": "true" }
```

```sh
flutter run --dart-define-from-file=dart_defines.staging.json
```

Don't pass the native `.env` to `--dart-define-from-file`. Anything you pass
that way is compiled into the Dart code.

### Google Maps API key (native build time only)

Copy `.env.example` to `.env` (git-ignored) and set `GOOGLE_MAPS_API_KEY`.
Gradle (Android) and `ios/Flutter/sync_maps_key_from_env.sh` (iOS) read it at
build time. On Android, `android/local.properties` also works.

### Android release signing

Release builds (`flutter build apk --release`, `flutter build appbundle`)
**fail** unless `android/key.properties` exists (git-ignored):

```properties
storeFile=upload-keystore.jks   # relative to android/
storePassword=...
keyAlias=upload
keyPassword=...
```

Release builds are never signed with the debug key. Debug and profile builds
don't need this file.

## Release checklist

```sh
flutter pub get          # regenerates pubspec.lock after dependency changes
flutter analyze
flutter test
flutter build appbundle --release
```
