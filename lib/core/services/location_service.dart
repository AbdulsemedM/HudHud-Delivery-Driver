import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  
  factory LocationService() {
    return _instance;
  }
  
  LocationService._internal();
  
  /// Request location permissions at app startup
  Future<bool> requestLocationPermission() async {
    // Request location permission
    PermissionStatus status = await Permission.location.status;
    
    if (status.isDenied) {
      // Request permission
      status = await Permission.location.request();
      if (status.isDenied) {
        // Permission denied
        return false;
      }
    }
    
    if (status.isPermanentlyDenied) {
      // Permission permanently denied, show dialog to open settings
      return false;
    }
    
    // Permission granted
    return status.isGranted;
  }
  
  /// Show dialog to open app settings when permission is permanently denied
  void showPermissionSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Permission Required'),
          content: const Text(
            'Location permission is required for delivery services. '
            'Please enable it in app settings.'
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Open Settings'),
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
            ),
          ],
        );
      },
    );
  }
  
  /// Get current location as LatLng
  Future<LatLng?> getCurrentLocation() async {
    try {
      List<Location> locations = await locationFromAddress("your current location");
      if (locations.isNotEmpty) {
        return LatLng(locations.first.latitude, locations.first.longitude);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting current location: $e');
      return null;
    }
  }
}