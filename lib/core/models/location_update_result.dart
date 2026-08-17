/// Result of POST /api/driver/update-location.
class LocationUpdateResult {
  const LocationUpdateResult({
    this.message,
    this.stale = false,
    this.location,
    this.skipped = false,
  });

  final String? message;
  final bool stale;
  final Map<String, dynamic>? location;
  final bool skipped;

  factory LocationUpdateResult.fromJson(Map<String, dynamic> json) {
    final location = json['location'];
    return LocationUpdateResult(
      message: json['message']?.toString(),
      stale: json['stale'] == true,
      location: location is Map ? Map<String, dynamic>.from(location) : null,
    );
  }

  /// Returns a stale result when a 409 conflict body has `stale: true`.
  static LocationUpdateResult? tryFromStaleConflict(dynamic details) {
    if (details is! Map) return null;
    final map = Map<String, dynamic>.from(details);
    if (map['stale'] != true) return null;
    return LocationUpdateResult.fromJson(map);
  }
}

/// Clamps driver location fields to the API-supported ranges.
class LocationUpdatePayload {
  LocationUpdatePayload._();

  static const sources = {'gps', 'network', 'fused', 'manual'};

  static double clampLatitude(double value) => value.clamp(-90, 90);
  static double clampLongitude(double value) => value.clamp(-180, 180);
  static double clampAccuracy(double value) => value.clamp(0, 5000);
  static double clampSpeed(double value) => value.clamp(0, 300);
  static double clampHeading(double value) => value.clamp(0, 360);
  static double clampAltitude(double value) => value.clamp(-1000, 10000);

  static String? normalizeSource(String? source) {
    if (source == null) return null;
    final normalized = source.trim().toLowerCase();
    if (sources.contains(normalized)) return normalized;
    return 'fused';
  }

  static Map<String, dynamic> build({
    required double latitude,
    required double longitude,
    double? accuracy,
    double? speed,
    int? heading,
    double? altitude,
    String? recordedAt,
    String? source,
  }) {
    final body = <String, dynamic>{
      'latitude': clampLatitude(latitude),
      'longitude': clampLongitude(longitude),
    };
    if (accuracy != null && accuracy.isFinite) {
      body['accuracy'] = clampAccuracy(accuracy);
    }
    if (speed != null && speed.isFinite) {
      body['speed'] = clampSpeed(speed);
    }
    if (heading != null && heading >= 0) {
      body['heading'] = clampHeading(heading.toDouble()).round();
    }
    if (altitude != null && altitude.isFinite) {
      body['altitude'] = clampAltitude(altitude);
    }
    if (recordedAt != null && recordedAt.isNotEmpty) {
      body['recorded_at'] = recordedAt;
    }
    final normalizedSource = normalizeSource(source);
    if (normalizedSource != null) {
      body['source'] = normalizedSource;
    }
    return body;
  }
}
