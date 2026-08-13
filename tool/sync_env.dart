import 'dart:convert';
import 'dart:io';

/// Syncs generated config from the project root `.env` file.
///
/// Run after editing `.env`:
///   dart run tool/sync_env.dart
void main() {
  final root = Directory.current;
  final envFile = File('${root.path}/.env');
  final iosEnvFile = File('${root.path}/ios/Flutter/Env.xcconfig');
  final dartSecretsFile = File('${root.path}/lib/core/config/env.secrets.dart');

  if (!envFile.existsSync()) {
    stderr.writeln('Missing .env — copy .env.example to .env and fill in values.');
    exit(1);
  }

  final values = _parseEnvFile(envFile);
  final mapsKey = values['GOOGLE_MAPS_API_KEY'] ?? '';

  iosEnvFile.writeAsStringSync(
    '// Generated from .env — do not commit\n'
    'GMS_API_KEY=$mapsKey\n',
  );

  dartSecretsFile.writeAsStringSync('''
// Generated from .env — do not commit.
// Run: dart run tool/sync_env.dart

const Map<String, String> envSecrets = {
  'FIREBASE_ANDROID_API_KEY': ${jsonEncode(values['FIREBASE_ANDROID_API_KEY'] ?? '')},
  'FIREBASE_IOS_API_KEY': ${jsonEncode(values['FIREBASE_IOS_API_KEY'] ?? '')},
  'GOOGLE_MAPS_API_KEY': ${jsonEncode(mapsKey)},
};
''');

  stdout.writeln('Wrote ${iosEnvFile.path}');
  stdout.writeln('Wrote ${dartSecretsFile.path}');
}

Map<String, String> _parseEnvFile(File file) {
  final values = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final idx = trimmed.indexOf('=');
    if (idx <= 0) continue;
    values[trimmed.substring(0, idx).trim()] = trimmed.substring(idx + 1).trim();
  }
  return values;
}
