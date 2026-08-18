import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:hudhud_delivery_driver/core/config/google_maps_api_key_provider.dart';

/// Fetches a driving route between two points via Google Directions API.
class DirectionsService {
  DirectionsService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Returns road-following points from [origin] to [destination].
  /// Throws [DirectionsException] when the key is missing or the API fails.
  Future<List<LatLng>> getDrivingRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final apiKey = await GoogleMapsApiKeyProvider.getApiKey();
    if (apiKey.isEmpty) {
      throw DirectionsException(
        'Google Maps API key is not configured.',
      );
    }

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/directions/json',
      {
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'mode': 'driving',
        'key': apiKey,
      },
    );

    final response = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw DirectionsException(
        'Directions request failed (${response.statusCode}).',
      );
    }

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw DirectionsException('Invalid Directions response.');
    }

    final status = body['status']?.toString();
    if (status != 'OK') {
      final error = body['error_message']?.toString();
      throw DirectionsException(
        error != null && error.isNotEmpty
            ? error
            : 'Directions status: ${status ?? 'UNKNOWN'}',
      );
    }

    final routes = body['routes'];
    if (routes is! List || routes.isEmpty) {
      throw DirectionsException('No route found.');
    }

    final route = routes.first;
    if (route is! Map) {
      throw DirectionsException('Invalid route payload.');
    }

    final overview = route['overview_polyline'];
    final encoded = overview is Map ? overview['points']?.toString() : null;
    if (encoded == null || encoded.isEmpty) {
      throw DirectionsException('Route polyline missing.');
    }

    final points = decodePolyline(encoded);
    if (points.length < 2) {
      throw DirectionsException('Route polyline too short.');
    }
    return points;
  }

  /// Decodes a Google encoded polyline into [LatLng] points.
  static List<LatLng> decodePolyline(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var lat = 0;
    var lng = 0;

    while (index < encoded.length) {
      var result = 0;
      var shift = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      result = 0;
      shift = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }
}

class DirectionsException implements Exception {
  DirectionsException(this.message);
  final String message;

  @override
  String toString() => message;
}
