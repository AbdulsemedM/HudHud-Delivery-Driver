import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  static const String _bgDisclosureDeclinedKey =
      'bg_location_disclosure_declined';
  static const String _bgDisclosureAttemptedKey =
      'bg_location_disclosure_attempted';

  static const String _alwaysPermissionSettingsMessage =
      'Allow location "Always" so nearby offers continue when the app is in '
      'the background. Open Settings, tap Location, and choose Always.';

  /// Ensures when-in-use location only (map display, one-shot GPS). Does not
  /// show the background/"Always" disclosure.
  Future<LocationPermissionResult> ensureWhenInUseLocation(
    BuildContext context,
  ) async {
    await _syncBackgroundDisclosureStateWithPermission();

    var geo = await Geolocator.checkPermission();
    if (geo == LocationPermission.denied) {
      if (!context.mounted) {
        return const LocationPermissionResult(
          whenInUse: false,
          always: false,
        );
      }
      final consented = await showWhenInUseLocationConsentDialog(context);
      if (!consented) {
        return const LocationPermissionResult(
          whenInUse: false,
          always: false,
        );
      }
      geo = await Geolocator.requestPermission();
    }

    if (!_geoWhenInUseGranted(geo)) {
      return LocationPermissionResult(
        whenInUse: false,
        always: geo == LocationPermission.always,
      );
    }

    return LocationPermissionResult(
      whenInUse: true,
      always: geo == LocationPermission.always,
    );
  }

  /// Requests background/"Always" location when needed (e.g. going online).
  ///
  /// [userInitiated] is true when the driver explicitly opts in (go online,
  /// taps the background-location warning). Passive calls skip the disclosure
  /// if the user previously declined or already went through the prompt.
  Future<LocationPermissionResult> requestBackgroundLocationIfNeeded(
    BuildContext context, {
    required bool userInitiated,
  }) async {
    await _syncBackgroundDisclosureStateWithPermission();

    var geo = await Geolocator.checkPermission();
    if (!_geoWhenInUseGranted(geo)) {
      if (!context.mounted) {
        return const LocationPermissionResult(
          whenInUse: false,
          always: false,
        );
      }
      final whenInUse = await ensureWhenInUseLocation(context);
      if (!whenInUse.whenInUse) {
        return whenInUse;
      }
      geo = await Geolocator.checkPermission();
    }

    if (geo == LocationPermission.always) {
      return const LocationPermissionResult(whenInUse: true, always: true);
    }

    final declined = await _isBackgroundDisclosureDeclined();
    final attempted = await _isBackgroundDisclosureAttempted();
    if (declined && !userInitiated) {
      return const LocationPermissionResult(whenInUse: true, always: false);
    }
    if (attempted && !userInitiated) {
      return const LocationPermissionResult(whenInUse: true, always: false);
    }
    if (attempted && userInitiated) {
      if (context.mounted) {
        showPermissionSettingsDialog(
          context,
          message: _alwaysPermissionSettingsMessage,
        );
      }
      return const LocationPermissionResult(whenInUse: true, always: false);
    }

    if (!context.mounted) {
      return const LocationPermissionResult(whenInUse: true, always: false);
    }

    final consented = await showBackgroundLocationConsentDialog(context);
    if (!consented) {
      await _setBackgroundDisclosureDeclined();
      return const LocationPermissionResult(whenInUse: true, always: false);
    }

    var alwaysGranted = false;
    if (Platform.isIOS) {
      await Permission.locationAlways.request();
      geo = await Geolocator.checkPermission();
      alwaysGranted = geo == LocationPermission.always;
      if (!alwaysGranted) {
        await _setBackgroundDisclosureAttempted();
        if (context.mounted) {
          showPermissionSettingsDialog(
            context,
            message: _alwaysPermissionSettingsMessage,
          );
        }
      }
    } else {
      final alwaysStatus = await Permission.locationAlways.status;
      if (!alwaysStatus.isGranted && !alwaysStatus.isPermanentlyDenied) {
        await Permission.locationAlways.request();
      }
      geo = await Geolocator.checkPermission();
      alwaysGranted =
          geo == LocationPermission.always ||
          (await Permission.locationAlways.status).isGranted;
      if (!alwaysGranted) {
        await _setBackgroundDisclosureAttempted();
      }
    }

    if (alwaysGranted) {
      await _clearBackgroundDisclosureState();
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

  /// Request when-in-use, then Always so nearby offers can continue in background.
  ///
  /// Shows a prominent in-app disclosure before each location runtime permission
  /// (when-in-use, then background/"Always"), as required by Google Play's
  /// User Data policy.
  ///
  /// Prefer [ensureWhenInUseLocation] for passive map loads and
  /// [requestBackgroundLocationIfNeeded] when going online.
  ///
  /// iOS source of truth is [Geolocator]: `permission_handler` can keep reporting
  /// denied after the user enables location in Settings.
  Future<LocationPermissionResult> requestLocationPermission(
    BuildContext context,
  ) async {
    final whenInUse = await ensureWhenInUseLocation(context);
    if (!whenInUse.whenInUse) {
      return whenInUse;
    }
    if (!context.mounted) {
      return whenInUse;
    }
    return requestBackgroundLocationIfNeeded(
      context,
      userInitiated: true,
    );
  }

  Future<void> _syncBackgroundDisclosureStateWithPermission() async {
    final geo = await Geolocator.checkPermission();
    if (geo == LocationPermission.always) {
      await _clearBackgroundDisclosureState();
    } else if (geo == LocationPermission.denied ||
        geo == LocationPermission.deniedForever) {
      await _clearBackgroundDisclosureState();
    }
  }

  Future<bool> _isBackgroundDisclosureDeclined() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_bgDisclosureDeclinedKey) ?? false;
  }

  Future<bool> _isBackgroundDisclosureAttempted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_bgDisclosureAttemptedKey) ?? false;
  }

  Future<void> _setBackgroundDisclosureDeclined() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_bgDisclosureDeclinedKey, true);
  }

  Future<void> _setBackgroundDisclosureAttempted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_bgDisclosureAttemptedKey, true);
  }

  Future<void> _clearBackgroundDisclosureState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_bgDisclosureDeclinedKey);
    await prefs.remove(_bgDisclosureAttemptedKey);
  }

  /// Prominent disclosure required before requesting when-in-use location.
  ///
  /// Returns `true` only if the user explicitly consents. Declining skips the
  /// system location permission prompt.
  Future<bool> showWhenInUseLocationConsentDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return const _WhenInUseLocationConsentDialog();
      },
    );
    return result == true;
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
  ///
  /// Does not request permission — use [ensureWhenInUseLocation] first so
  /// the system dialog is always preceded by in-app disclosure.
  Future<LatLng?> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('LocationService: location services disabled');
        return null;
      }

      final permission = await Geolocator.checkPermission();
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
  ///
  /// Does not request permission — use [ensureWhenInUseLocation] first so
  /// the system dialog is always preceded by in-app disclosure.
  Future<Map<String, dynamic>?> getCurrentPositionDetails({
    bool highAccuracy = true,
  }) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      final permission = await Geolocator.checkPermission();
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

/// Prominent disclosure before when-in-use location access.
class _WhenInUseLocationConsentDialog extends StatefulWidget {
  const _WhenInUseLocationConsentDialog();

  @override
  State<_WhenInUseLocationConsentDialog> createState() =>
      _WhenInUseLocationConsentDialogState();
}

class _WhenInUseLocationConsentDialogState
    extends State<_WhenInUseLocationConsentDialog> {
  bool _acknowledged = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Allow location access'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'HudHud collects location data while you use the app to enable '
              'nearby delivery and ride offers, show your position on the map, '
              'navigate to pickups and drop-offs, and share your live location '
              'with customers during active jobs.',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You can turn off location access anytime in your device '
              'settings. Declining means you will not receive nearby offers '
              'or see your position on the map.',
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
                'I understand and agree to location access',
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
          child: const Text('Enable location'),
        ),
      ],
    );
  }
}

/// Prominent disclosure before background location access.
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
              'This app collects location data to enable nearby delivery and '
              'ride offers, customer trip tracking, and dispatch matching even '
              'when the app is closed or not in use.',
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
