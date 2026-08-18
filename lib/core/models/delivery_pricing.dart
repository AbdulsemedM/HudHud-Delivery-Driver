import 'package:hudhud_delivery_driver/core/utils/json_parse.dart';

/// Helper model for reading zone pricing metadata returned by the backend.
///
/// The driver app receives deliveries as `Map<String, dynamic>` responses
/// and can show the pinned pricing zone and the route basis when present.
class DeliveryPricing {
  final String? pricingEngine;
  final String? pricingPinnedAt;
  final PricingZone? zone;
  final String? routeBasis;
  final double? total;
  final double? baseFee;
  final double? distanceFee;
  final double? timeFee;
  final double? billableDistanceKm;
  final int? estimatedDurationMinutes;

  const DeliveryPricing({
    this.pricingEngine,
    this.pricingPinnedAt,
    this.zone,
    this.routeBasis,
    this.total,
    this.baseFee,
    this.distanceFee,
    this.timeFee,
    this.billableDistanceKm,
    this.estimatedDurationMinutes,
  });

  bool get hasFeeBreakdown =>
      baseFee != null || distanceFee != null || timeFee != null;

  /// Server-authoritative customer quote amount.
  ///
  /// Priority: `metadata.pricing_quote.total` → `estimated_cost` →
  /// `final_cost` → `payment.amount`.
  static double? serverQuoteAmount(Map<String, dynamic> delivery) {
    final pricing = fromDelivery(delivery);
    if (pricing?.total != null) return pricing!.total;

    final estimated = JsonParse.toDouble(delivery['estimated_cost']);
    if (estimated != null) return estimated;

    final finalCost = JsonParse.toDouble(delivery['final_cost']);
    if (finalCost != null) return finalCost;

    final payment = delivery['payment'];
    if (payment is Map) {
      return JsonParse.toDouble(payment['amount']);
    }
    return null;
  }

  /// Parses pricing metadata from a top-level delivery map.
  static DeliveryPricing? fromDelivery(Map<String, dynamic> delivery) {
    final metadata = delivery['metadata'];
    if (metadata is Map<String, dynamic>) return fromMetadata(metadata);
    if (metadata is Map) return fromMetadata(Map<String, dynamic>.from(metadata));
    return null;
  }

  /// Parses pricing metadata from a metadata object.
  static DeliveryPricing? fromMetadata(Map<String, dynamic> metadata) {
    final pricingQuote = metadata['pricing_quote'];
    if (pricingQuote is! Map) return null;
    final pricingQuoteMap = Map<String, dynamic>.from(pricingQuote);

    final zone = pricingQuoteMap['zone'];
    final zoneModel = zone is Map
        ? PricingZone.fromMap(Map<String, dynamic>.from(zone))
        : null;

    return DeliveryPricing(
      pricingEngine: metadata['pricing_engine']?.toString(),
      pricingPinnedAt: metadata['pricing_pinned_at']?.toString(),
      zone: zoneModel,
      routeBasis: pricingQuoteMap['route_basis']?.toString(),
      total: JsonParse.toDouble(pricingQuoteMap['total']),
      baseFee: JsonParse.toDouble(pricingQuoteMap['base_fee']),
      distanceFee: JsonParse.toDouble(pricingQuoteMap['distance_fee']),
      timeFee: JsonParse.toDouble(pricingQuoteMap['time_fee']),
      billableDistanceKm:
          JsonParse.toDouble(pricingQuoteMap['billable_distance_km']),
      estimatedDurationMinutes:
          JsonParse.toInt(pricingQuoteMap['estimated_duration_minutes']),
    );
  }
}

class PricingZone {
  final String? id;
  final String? name;
  final int? version;

  const PricingZone({
    this.id,
    this.name,
    this.version,
  });

  static PricingZone? fromMap(Map<String, dynamic> map) {
    final versionRaw = map['version'];
    final version = versionRaw is int
        ? versionRaw
        : versionRaw is num
            ? versionRaw.round()
            : int.tryParse(versionRaw?.toString() ?? '');

    return PricingZone(
      id: map['id']?.toString(),
      name: map['name']?.toString(),
      version: version,
    );
  }
}

/// User-facing message for zone coverage errors (`422` + `pickup_outside_configured_zone`).
String? pickupOutsideZoneMessage(dynamic details) {
  if (details is! Map) return null;
  final map = Map<String, dynamic>.from(details);
  final reason = map['reason']?.toString();
  if (reason == 'pickup_outside_configured_zone') {
    final message = map['message']?.toString();
    return message?.isNotEmpty == true
        ? message
        : 'Pickup location is outside all configured delivery zones.';
  }
  return null;
}
