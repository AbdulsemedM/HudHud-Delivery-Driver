import 'package:hudhud_delivery_driver/core/config/env.dart';

/// Google API key for Maps/Geocoding/Directions (from `.env`).
String get googleApiKey => env('GOOGLE_MAPS_API_KEY');
