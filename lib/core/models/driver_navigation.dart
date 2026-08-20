import 'package:hudhud_delivery_driver/core/utils/json_parse.dart';

/// Server-authoritative navigation target from accept / start / current-status.
class DriverNavigation {
  const DriverNavigation({
    this.enabled = false,
    this.phase,
    this.label,
    this.address,
    this.latitude,
    this.longitude,
    this.googleMapsUrl,
    this.geoUri,
  });

  final bool enabled;
  final String? phase;
  final String? label;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? googleMapsUrl;
  final String? geoUri;

  bool get isToPickup =>
      phase?.toLowerCase() == 'to_pickup' ||
      phase?.toLowerCase() == 'pickup';

  bool get isToDropoff =>
      phase?.toLowerCase() == 'to_dropoff' ||
      phase?.toLowerCase() == 'dropoff';

  bool get hasExternalMapsLink =>
      (googleMapsUrl != null && googleMapsUrl!.isNotEmpty) ||
      (geoUri != null && geoUri!.isNotEmpty);

  Uri? get externalMapsUri {
    final maps = googleMapsUrl?.trim();
    if (maps != null && maps.isNotEmpty) {
      return Uri.tryParse(maps);
    }
    final geo = geoUri?.trim();
    if (geo != null && geo.isNotEmpty) {
      return Uri.tryParse(geo);
    }
    if (latitude != null && longitude != null) {
      return Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude',
      );
    }
    return null;
  }

  static DriverNavigation? fromJson(dynamic raw) {
    final map = JsonParse.toMap(raw);
    if (map == null) return null;

    final destination = JsonParse.toMap(map['destination']) ?? map;
    final lat = JsonParse.toDouble(
          destination['latitude'] ?? destination['lat'],
        ) ??
        JsonParse.toDouble(map['latitude']);
    final lng = JsonParse.toDouble(
          destination['longitude'] ??
              destination['lng'] ??
              destination['lon'],
        ) ??
        JsonParse.toDouble(map['longitude']);

    return DriverNavigation(
      enabled: JsonParse.toBool(map['enabled'], defaultValue: true),
      phase: map['phase']?.toString(),
      label: destination['label']?.toString() ?? map['label']?.toString(),
      address:
          destination['address']?.toString() ?? map['address']?.toString(),
      latitude: lat,
      longitude: lng,
      googleMapsUrl: map['google_maps_url']?.toString(),
      geoUri: map['geo_uri']?.toString(),
    );
  }

  /// Reads nested `navigation` from accept / start / current-status / detail.
  static DriverNavigation? fromPayload(dynamic payload) {
    final map = JsonParse.toMap(payload);
    if (map == null) return null;
    return fromJson(map['navigation']) ??
        fromJson(JsonParse.toMap(map['delivery'])?['navigation']) ??
        fromJson(JsonParse.toMap(map['active_job'])?['navigation']);
  }
}
