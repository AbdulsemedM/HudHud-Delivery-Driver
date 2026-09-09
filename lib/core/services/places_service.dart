import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:hudhud_delivery_driver/core/config/google_maps_api_key_provider.dart';

/// A single Places Autocomplete prediction.
class PlacePrediction {
  const PlacePrediction({
    required this.placeId,
    required this.description,
    this.mainText,
    this.secondaryText,
  });

  final String placeId;
  final String description;
  final String? mainText;
  final String? secondaryText;
}

/// Coordinates + formatted address from Place Details.
class PlaceDetails {
  const PlaceDetails({
    required this.placeId,
    required this.formattedAddress,
    required this.location,
    this.name,
  });

  final String placeId;
  final String formattedAddress;
  final LatLng location;
  final String? name;
}

/// Google Places Autocomplete + Details via the classic Places REST API.
class PlacesService {
  PlacesService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const LatLng defaultBias = LatLng(8.9806, 38.7578);
  static const int defaultRadiusMeters = 50000;

  /// Returns autocomplete predictions for [query], biased to [bias] in Ethiopia.
  Future<List<PlacePrediction>> autocomplete(
    String query, {
    LatLng? bias,
    int radiusMeters = defaultRadiusMeters,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];

    final apiKey = await GoogleMapsApiKeyProvider.getApiKey();
    if (apiKey.isEmpty) {
      throw PlacesException('Google Maps API key is not configured.');
    }

    final location = bias ?? defaultBias;
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      {
        'input': trimmed,
        'key': apiKey,
        'components': 'country:et',
        'location': '${location.latitude},${location.longitude}',
        'radius': '$radiusMeters',
      },
    );

    final response =
        await _client.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw PlacesException(
        'Places autocomplete failed (${response.statusCode}).',
      );
    }

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw PlacesException('Invalid Places autocomplete response.');
    }

    final status = body['status']?.toString();
    if (status == 'ZERO_RESULTS') return const [];
    if (status != 'OK') {
      final error = body['error_message']?.toString();
      throw PlacesException(
        error != null && error.isNotEmpty
            ? error
            : 'Places autocomplete status: ${status ?? 'UNKNOWN'}',
      );
    }

    final predictions = body['predictions'];
    if (predictions is! List) return const [];

    final results = <PlacePrediction>[];
    for (final item in predictions) {
      if (item is! Map) continue;
      final placeId = item['place_id']?.toString();
      final description = item['description']?.toString();
      if (placeId == null ||
          placeId.isEmpty ||
          description == null ||
          description.isEmpty) {
        continue;
      }
      final structured = item['structured_formatting'];
      String? mainText;
      String? secondaryText;
      if (structured is Map) {
        mainText = structured['main_text']?.toString();
        secondaryText = structured['secondary_text']?.toString();
      }
      results.add(
        PlacePrediction(
          placeId: placeId,
          description: description,
          mainText: mainText,
          secondaryText: secondaryText,
        ),
      );
    }
    return results;
  }

  /// Resolves [placeId] to coordinates and a formatted address.
  Future<PlaceDetails> placeDetails(String placeId) async {
    final id = placeId.trim();
    if (id.isEmpty) {
      throw PlacesException('Place id is required.');
    }

    final apiKey = await GoogleMapsApiKeyProvider.getApiKey();
    if (apiKey.isEmpty) {
      throw PlacesException('Google Maps API key is not configured.');
    }

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {
        'place_id': id,
        'fields': 'place_id,name,formatted_address,geometry',
        'key': apiKey,
      },
    );

    final response =
        await _client.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw PlacesException(
        'Place details failed (${response.statusCode}).',
      );
    }

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw PlacesException('Invalid Place details response.');
    }

    final status = body['status']?.toString();
    if (status != 'OK') {
      final error = body['error_message']?.toString();
      throw PlacesException(
        error != null && error.isNotEmpty
            ? error
            : 'Place details status: ${status ?? 'UNKNOWN'}',
      );
    }

    final result = body['result'];
    if (result is! Map) {
      throw PlacesException('Place details missing result.');
    }

    final geometry = result['geometry'];
    final location = geometry is Map ? geometry['location'] : null;
    if (location is! Map) {
      throw PlacesException('Place details missing coordinates.');
    }

    final lat = location['lat'];
    final lng = location['lng'];
    if (lat is! num || lng is! num) {
      throw PlacesException('Place details has invalid coordinates.');
    }

    final formatted = result['formatted_address']?.toString().trim();
    final name = result['name']?.toString().trim();
    final address = (formatted != null && formatted.isNotEmpty)
        ? formatted
        : (name != null && name.isNotEmpty ? name : 'Selected place');

    return PlaceDetails(
      placeId: result['place_id']?.toString() ?? id,
      formattedAddress: address,
      location: LatLng(lat.toDouble(), lng.toDouble()),
      name: name,
    );
  }
}

class PlacesException implements Exception {
  PlacesException(this.message);
  final String message;

  @override
  String toString() => message;
}
