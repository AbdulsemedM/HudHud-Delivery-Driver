import 'package:flutter/material.dart';

/// The rider's vehicle as shown on home and profile screens, built from the
/// `driver_profile` map of GET /driver/driver/profile.
///
/// Bicycles have no plate (and often no meaningful make / model), so the
/// vehicle TYPE always leads; make, model, colour and plate are added when
/// the profile has them. e.g. "Bicycle · Black", "Motorcycle · Bajaj Boxer
/// · AA 3-12345".
class VehicleDisplay {
  const VehicleDisplay._({
    required this.typeLabel,
    required this.details,
    required this.summary,
    required this.icon,
  });

  /// "Bicycle", "Motorcycle", "Car" … or null when the profile has no type.
  final String? typeLabel;

  /// Make / model / colour / plate without the type, or null.
  final String? details;

  /// One-line description, or null when the profile has nothing at all.
  final String? summary;

  final IconData icon;

  static VehicleDisplay fromDriverProfile(Map<String, dynamic>? profile) {
    final type = _text(profile?['vehicle_type']);
    final make = _text(profile?['vehicle_make']);
    final model = _text(profile?['vehicle_model']);
    final color = _text(profile?['vehicle_color']);
    final plate = _text(profile?['vehicle_plate_number']);

    final typeLabel = type == null ? null : labelForType(type);
    final makeModel = [make, model].whereType<String>().join(' ');
    final detailParts = <String>[
      if (makeModel.isNotEmpty) makeModel,
      if (color != null) color,
      if (plate != null) plate,
    ];
    final parts = <String>[
      if (typeLabel != null) typeLabel,
      ...detailParts,
    ];
    return VehicleDisplay._(
      typeLabel: typeLabel,
      details: detailParts.isEmpty ? null : detailParts.join(' · '),
      summary: parts.isEmpty ? null : parts.join(' · '),
      icon: iconForType(type),
    );
  }

  /// Human label for an API `vehicle_type` value.
  static String labelForType(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'bicycle':
      case 'cycle':
        return 'Bicycle';
      case 'motorcycle':
      case 'motorbike':
      case 'bike':
        return 'Motorcycle';
      case 'car':
        return 'Car';
      case 'bajaj':
      case 'tuk-tuk':
      case 'tuktuk':
        return 'Bajaj';
      case 'van':
        return 'Van';
      case 'truck':
        return 'Truck';
      default:
        final cleaned = raw.trim().replaceAll(RegExp(r'[_-]+'), ' ');
        if (cleaned.isEmpty) return raw;
        return cleaned[0].toUpperCase() + cleaned.substring(1);
    }
  }

  static IconData iconForType(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'bicycle':
      case 'cycle':
        return Icons.pedal_bike;
      case 'motorcycle':
      case 'motorbike':
      case 'bike':
        return Icons.two_wheeler;
      case 'car':
        return Icons.directions_car;
      case 'bajaj':
      case 'tuk-tuk':
      case 'tuktuk':
        return Icons.electric_rickshaw;
      case 'van':
      case 'truck':
        return Icons.local_shipping;
      default:
        return Icons.local_shipping;
    }
  }

  static String? _text(dynamic value) {
    if (value == null || value is Map || value is List) return null;
    final s = value.toString().trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return null;
    return s;
  }
}
