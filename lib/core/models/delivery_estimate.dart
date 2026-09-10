import 'package:hudhud_delivery_driver/core/utils/json_parse.dart';

/// Result of POST /services/delivery/estimate (flat or `{ success, data }`).
class DeliveryEstimate {
  const DeliveryEstimate({
    required this.estimatedCost,
    this.estimatedDistance,
    this.estimatedDuration,
    this.currency = 'ETB',
  });

  final double estimatedCost;
  final double? estimatedDistance;
  final int? estimatedDuration;
  final String currency;

  static DeliveryEstimate? fromResponse(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final nested = map['data'];
    final payload = nested is Map
        ? Map<String, dynamic>.from(nested)
        : map;

    final cost = JsonParse.toDouble(payload['estimated_cost']);
    if (cost == null) return null;

    final durationRaw = payload['estimated_duration'];
    int? duration;
    if (durationRaw is int) {
      duration = durationRaw;
    } else if (durationRaw is num) {
      duration = durationRaw.round();
    } else if (durationRaw != null) {
      duration = int.tryParse(durationRaw.toString());
    }

    return DeliveryEstimate(
      estimatedCost: cost,
      estimatedDistance: JsonParse.toDouble(payload['estimated_distance']),
      estimatedDuration: duration,
      currency: payload['currency']?.toString().trim().isNotEmpty == true
          ? payload['currency'].toString().trim()
          : 'ETB',
    );
  }

  /// Maps registration / profile vehicle labels to estimate API values.
  static String normalizeVehicleType(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    switch (v) {
      case 'motorcycle':
      case 'motorbike':
      case 'bike':
        return 'motorbike';
      case 'car':
        return 'car';
      case 'bajaj':
      case 'tuk-tuk':
      case 'tuktuk':
        return 'bajaj';
      case 'bicycle':
      case 'cycle':
        return 'bicycle';
      default:
        return 'motorbike';
    }
  }
}
