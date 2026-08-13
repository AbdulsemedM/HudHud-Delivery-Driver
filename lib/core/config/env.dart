import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Loads secrets from the project root `.env` file (see `.env.example`).
Future<void> loadEnv() async {
  await dotenv.load(fileName: '.env');
}

/// Reads a value from the loaded `.env` file.
String env(String key, {String defaultValue = ''}) {
  return dotenv.env[key]?.trim() ?? defaultValue;
}
