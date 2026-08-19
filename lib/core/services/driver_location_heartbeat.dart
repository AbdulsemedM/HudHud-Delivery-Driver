import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/services/location_service.dart';

/// Posts GPS while the driver is online so they stay eligible for proximity waves.
class DriverLocationHeartbeat extends ChangeNotifier {
  DriverLocationHeartbeat({
    required ApiService api,
    required LocationService location,
  })  : _api = api,
        _location = location;

  static const Duration fallbackInterval = Duration(seconds: 8);
  static const Duration staleAfter = Duration(minutes: 3);

  final ApiService _api;
  final LocationService _location;

  StreamSubscription<Position>? _streamSub;
  Timer? _fallbackTimer;
  bool _running = false;
  bool _highAccuracy = false;
  bool _posting = false;
  DateTime? _lastSuccessfulPostAt;
  DateTime? _lastAttemptAt;
  Map<String, dynamic>? _lastDetails;

  bool get isRunning => _running;
  bool get highAccuracy => _highAccuracy;
  DateTime? get lastSuccessfulPostAt => _lastSuccessfulPostAt;

  bool get isLocationStale {
    if (!_running) return false;
    final at = _lastSuccessfulPostAt;
    if (at == null) {
      return _lastAttemptAt != null;
    }
    return DateTime.now().difference(at) > staleAfter;
  }

  LatLng? get lastLatLng {
    final details = _lastDetails;
    if (details == null) return null;
    final lat = details['latitude'];
    final lng = details['longitude'];
    if (lat is! num || lng is! num) return null;
    return LatLng(lat.toDouble(), lng.toDouble());
  }

  Future<void> start({bool highAccuracy = false}) async {
    _highAccuracy = highAccuracy;
    if (_running) {
      await _restartStream();
      return;
    }
    _running = true;
    await _restartStream();
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer.periodic(fallbackInterval, (_) {
      unawaited(_postCurrent());
    });
    await _postCurrent();
    notifyListeners();
  }

  Future<void> stop() async {
    _running = false;
    await _streamSub?.cancel();
    _streamSub = null;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    notifyListeners();
  }

  Future<void> setHighAccuracy(bool value) async {
    if (_highAccuracy == value) return;
    _highAccuracy = value;
    if (_running) await _restartStream();
  }

  Future<void> _restartStream() async {
    await _streamSub?.cancel();
    if (!_running) return;
    try {
      _streamSub = _location.positionStream(highAccuracy: _highAccuracy).listen(
        (position) {
          unawaited(_postDetails(_location.detailsFromPosition(position)));
        },
        onError: (_) {
          unawaited(_postCurrent());
        },
      );
    } catch (_) {
      // Fallback timer still posts.
    }
  }

  Future<void> _postCurrent() async {
    if (!_running) return;
    final details = await _location.getCurrentPositionDetails(
      highAccuracy: _highAccuracy,
    );
    if (details == null) {
      _lastAttemptAt = DateTime.now();
      notifyListeners();
      return;
    }
    await _postDetails(details);
  }

  Future<void> _postDetails(Map<String, dynamic> details) async {
    if (!_running || _posting) return;
    _posting = true;
    _lastAttemptAt = DateTime.now();
    try {
      final lat = details['latitude'];
      final lng = details['longitude'];
      if (lat is! num || lng is! num) return;
      await _api.updateDriverLocation(
        latitude: lat.toDouble(),
        longitude: lng.toDouble(),
        accuracy: details['accuracy'] is num
            ? (details['accuracy'] as num).toDouble()
            : null,
        speed: details['speed'] is num
            ? (details['speed'] as num).toDouble()
            : null,
        heading: details['heading'] as int?,
        altitude: details['altitude'] is num
            ? (details['altitude'] as num).toDouble()
            : null,
        recordedAt: details['recorded_at'] as String?,
        source: details['source'] as String?,
      );
      _lastDetails = details;
      _lastSuccessfulPostAt = DateTime.now();
      notifyListeners();
    } catch (_) {
      _lastDetails ??= details;
      notifyListeners();
    } finally {
      _posting = false;
    }
  }
}
