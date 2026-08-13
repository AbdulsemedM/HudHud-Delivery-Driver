import 'dart:io';

/// Syncs iOS native build settings from the project root `.env` file.
///
/// Run after editing `.env`:
///   dart run tool/sync_env.dart
void main() {
  final root = Directory.current;
  final envFile = File('${root.path}/.env');
  final outFile = File('${root.path}/ios/Flutter/Env.xcconfig');

  if (!envFile.existsSync()) {
    stderr.writeln('Missing .env — copy .env.example to .env and fill in values.');
    exit(1);
  }

  String mapsKey = '';
  for (final line in envFile.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.startsWith('GOOGLE_MAPS_API_KEY=')) {
      mapsKey = trimmed.substring('GOOGLE_MAPS_API_KEY='.length).trim();
      break;
    }
  }

  outFile.writeAsStringSync(
    '// Generated from .env — do not commit\n'
    'GMS_API_KEY=$mapsKey\n',
  );
  stdout.writeln('Wrote ${outFile.path}');
}
