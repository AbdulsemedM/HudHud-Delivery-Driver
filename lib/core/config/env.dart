import 'package:hudhud_delivery_driver/core/config/env.secrets.dart';

/// Reads a secret value generated from the local `.env` file.
///
/// After editing `.env`, run: dart run tool/sync_env.dart
String env(String key, {String defaultValue = ''}) {
  return envSecrets[key]?.trim() ?? defaultValue;
}
