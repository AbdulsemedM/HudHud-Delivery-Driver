/// Google API key for Maps/Geocoding/Directions.
///
/// Set via: flutter run --dart-define=GOOGLE_API_KEY=your_key
/// Or from a local override (see .gitignore).
const String googleApiKey = String.fromEnvironment(
  'GOOGLE_API_KEY',
  defaultValue: '',
);
