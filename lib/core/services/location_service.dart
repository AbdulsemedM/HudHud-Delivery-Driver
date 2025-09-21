import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  
  factory LocationService() {
    return _instance;
  }
  
  LocationService._internal();
  
  /// Request location permissions at app startup
  Future<bool> requestLocationPermission() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled
      return false;
    }
    
    // Check location permission status
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      // Request permission
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permission denied
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      // Permission permanently denied, show dialog to open settings
      return false;
    }
    
    // Permission granted
    return true;
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
  
  /// Get current position
  Future<Position?> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition();
    } catch (e) {
      debugPrint('Error getting current position: $e');
      return null;
    }
  }
}