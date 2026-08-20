import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationPermissionResult {
  const LocationPermissionResult({
    required this.whenInUse,
    required this.always,
  });

  final bool whenInUse;
  final bool always;

  bool get granted => whenInUse;
}

class LocationService {
  static final LocationService _instance = LocationService._internal();

  factory LocationService() {
    return _instance;
  }

  LocationService._internal();

  static const int distanceFilterMeters = 30;

  /// Request when-in-use, then Always so nearby offers can continue in background.
  Future<LocationPermissionResult> requestLocationPermission() async {
    var whenInUse = await Permission.locationWhenInUse.status;
    if (whenInUse.isDenied) {
      whenInUse = await Permission.locationWhenInUse.request();
    }
    if (whenInUse.isPermanentlyDenied || !whenInUse.isGranted) {
      return LocationPermissionResult(
        whenInUse: whenInUse.isGranted,
        always: false,
      );
    }

    var always = await Permission.locationAlways.status;
    if (!always.isGranted && !always.isPermanentlyDenied) {
      always = await Permission.locationAlways.request();
    }

    if (Platform.isAndroid) {
      final notification = await Permission.notification.status;
      if (notification.isDenied) {
        await Permission.notification.request();
      }
    }

    return LocationPermissionResult(
      whenInUse: true,
      always: always.isGranted,
    );
  }

  Future<bool> hasAlwaysPermission() async {
    return Permission.locationAlways.isGranted;
  }

  /// Check if location services are enabled on the device.
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Show dialog to open app settings when permission is permanently denied.
  void showPermissionSettingsDialog(
    BuildContext context, {
    String message =
        'Location permission is required for nearby delivery offers. '
        'Please enable it in app settings.',
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Permission Required'),
          content: Text(message),
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

  LocationSettings streamSettings({required bool highAccuracy}) {
    final accuracy =
        highAccuracy ? LocationAccuracy.best : LocationAccuracy.medium;
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilterMeters,
        intervalDuration: const Duration(seconds: 8),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'HudHud Driver',
          notificationText:
              "You're online — sharing location for nearby offers",
          notificationChannelName: 'Driver location',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: accuracy,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: distanceFilterMeters,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }
    return LocationSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilterMeters,
    );
  }

  Stream<Position> positionStream({required bool highAccuracy}) {
    return Geolocator.getPositionStream(
      locationSettings: streamSettings(highAccuracy: highAccuracy),
    );
  }

  Map<String, dynamic> detailsFromPosition(Position position) {
    final heading = position.heading;
    return {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
      'speed': position.speed.isFinite ? position.speed : 0.0,
      'heading': heading.isFinite && heading >= 0 ? heading.round() : null,
      'altitude': position.altitude,
      'recorded_at': position.timestamp.toUtc().toIso8601String(),
      'source': 'fused',
    };
  }

  /// Get current device location as LatLng using GPS.
  /// Returns null if permission denied, location disabled, or on error.
  Future<LatLng?> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('LocationService: location services disabled');
        return null;
      }

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested != LocationPermission.whileInUse &&
            requested != LocationPermission.always) {
          debugPrint('LocationService: permission denied');
          return null;
        }
      }
      if (permission == LocationPermission.deniedForever) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('LocationService: error getting location: $e');
      return null;
    }
  }

  /// Get current position with full details for driver location API.
  /// Returns map with latitude, longitude, accuracy, speed, heading, altitude,
  /// recorded_at, and source (null if unavailable).
  Future<Map<String, dynamic>?> getCurrentPositionDetails({
    bool highAccuracy = true,
  }) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested != LocationPermission.whileInUse &&
            requested != LocationPermission.always) {
          return null;
        }
      }
      if (permission == LocationPermission.deniedForever) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy:
              highAccuracy ? LocationAccuracy.best : LocationAccuracy.medium,
        ),
      );
      return detailsFromPosition(position);
    } catch (e) {
      debugPrint('LocationService: error getting position details: $e');
      return null;
    }
  }
}
