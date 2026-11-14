import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/utils/vehicle_display.dart';

void main() {
  test('bicycle with no plate still shows the vehicle type', () {
    // Shape of driver_profile from GET /driver/driver/profile.
    final v = VehicleDisplay.fromDriverProfile({
      'vehicle_type': 'bicycle',
      'vehicle_make': 'medium',
      'vehicle_model': 'mountain',
      'vehicle_color': 'Black',
      'vehicle_plate_number': null,
    });
    expect(v.typeLabel, 'Bicycle');
    expect(v.details, 'medium mountain · Black');
    expect(v.summary, 'Bicycle · medium mountain · Black');
    expect(v.icon, Icons.pedal_bike);
  });

  test('motorbike alias, plate included', () {
    final v = VehicleDisplay.fromDriverProfile({
      'vehicle_type': 'motorbike',
      'vehicle_plate_number': 'AA 3-12345',
    });
    expect(v.typeLabel, 'Motorcycle');
    expect(v.summary, 'Motorcycle · AA 3-12345');
    expect(v.icon, Icons.two_wheeler);
  });

  test('empty or missing profile', () {
    final v = VehicleDisplay.fromDriverProfile(null);
    expect(v.typeLabel, isNull);
    expect(v.summary, isNull);
    expect(VehicleDisplay.fromDriverProfile({'vehicle_type': ''}).summary,
        isNull);
  });

  test('unknown types are humanised', () {
    expect(VehicleDisplay.labelForType('cargo_van'), 'Cargo van');
  });
}
