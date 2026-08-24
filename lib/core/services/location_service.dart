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
  ///
  /// Shows a prominent in-app disclosure before requesting background ("Always")
  /// location, as required by Google Play's User Data policy.
  ///
  /// iOS source of truth is [Geolocator]: `permission_handler` can keep reporting
  /// denied after the user enables location in Settings.
  Future<LocationPermissionResult> requestLocationPermission(
    BuildContext context,
  ) async {
    var geo = await Geolocator.checkPermission();
    if (geo == LocationPermission.denied) {
      geo = await Geolocator.requestPermission();
    }

    if (!_geoWhenInUseGranted(geo)) {
      return const LocationPermissionResult(
        whenInUse: false,
        always: false,
      );
    }

    var alwaysGranted = geo == LocationPermission.always;
    if (!alwaysGranted) {
      final alwaysStatus = await Permission.locationAlways.status;
      if (!alwaysStatus.isGranted && !alwaysStatus.isPermanentlyDenied) {
        if (!context.mounted) {
          return const LocationPermissionResult(
            whenInUse: true,
            always: false,
          );
        }
        final consented = await showBackgroundLocationConsentDialog(context);
        if (!consented) {
          return const LocationPermissionResult(
            whenInUse: true,
            always: false,
          );
        }
        await Permission.locationAlways.request();
        geo = await Geolocator.checkPermission();
        alwaysGranted = geo == LocationPermission.always;
      } else {
        alwaysGranted = alwaysStatus.isGranted;
      }
    }

    if (Platform.isAndroid) {
      final notification = await Permission.notification.status;
      if (notification.isDenied) {
        await Permission.notification.request();
      }
    }

    return LocationPermissionResult(
      whenInUse: true,
      always: alwaysGranted,
    );
  }

  /// Prominent disclosure required before requesting ACCESS_BACKGROUND_LOCATION.
  ///
  /// Returns `true` only if the user explicitly consents to enable background
  /// location. Declining skips the system Always permission prompt.
  Future<bool> showBackgroundLocationConsentDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return const _BackgroundLocationConsentDialog();
      },
    );
    return result == true;
  }

  Future<bool> hasAlwaysPermission() async {
    final geo = await Geolocator.checkPermission();
    return geo == LocationPermission.always;
  }

  Future<bool> hasWhenInUsePermission() async {
    final geo = await Geolocator.checkPermission();
    return _geoWhenInUseGranted(geo);
  }

  Future<bool> isLocationPermissionPermanentlyDenied() async {
    final geo = await Geolocator.checkPermission();
    return geo == LocationPermission.deniedForever;
  }

  static bool _geoWhenInUseGranted(LocationPermission permission) {
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
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
      barrierDismissible: true,
      builder: (BuildContext context) {
        return _LocationPermissionSettingsDialog(message: message);
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

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('LocationService: permission denied');
        return null;
      }

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

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

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

class _LocationPermissionSettingsDialog extends StatefulWidget {
  const _LocationPermissionSettingsDialog({required this.message});

  final String message;

  @override
  State<_LocationPermissionSettingsDialog> createState() =>
      _LocationPermissionSettingsDialogState();
}

class _LocationPermissionSettingsDialogState
    extends State<_LocationPermissionSettingsDialog>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dismissIfGranted();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _dismissIfGranted();
    }
  }

  Future<void> _dismissIfGranted() async {
    final permission = await Geolocator.checkPermission();
    if (!mounted) return;
    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Location Permission Required'),
      content: Text(widget.message),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: const Text('Open Settings'),
          onPressed: () {
            openAppSettings();
          },
        ),
      ],
    );
  }
}

/// Full-screen-style prominent disclosure before background location access.
class _BackgroundLocationConsentDialog extends StatefulWidget {
  const _BackgroundLocationConsentDialog();

  @override
  State<_BackgroundLocationConsentDialog> createState() =>
      _BackgroundLocationConsentDialogState();
}

class _BackgroundLocationConsentDialogState
    extends State<_BackgroundLocationConsentDialog> {
  bool _acknowledged = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Allow background location'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'HudHud collects your location data even when the app is closed '
              'or not in use.',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This is used to:\n'
              '• Keep you eligible for nearby delivery and ride offers while '
              'you are online\n'
              '• Let customers track you after you accept a job\n'
              '• Update your position for dispatch matching',
            ),
            const SizedBox(height: 12),
            Text(
              'You can turn off background location anytime in your device '
              'settings. Declining will not prevent you from using the app '
              'while it is open, but nearby offers may stop when you leave '
              'the app.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _acknowledged,
              onChanged: (value) {
                setState(() => _acknowledged = value ?? false);
              },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'I understand and agree to background location access',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: _acknowledged
              ? () => Navigator.of(context).pop(true)
              : null,
          child: const Text('Enable background location'),
        ),
      ],
    );
  }
}
