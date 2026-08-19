/// Parsed GET /api/driver/services/available-requests payload.
class AvailableDriverRequests {
  const AvailableDriverRequests({
    this.deliveries = const [],
    this.rides = const [],
    this.dispatch,
  });

  final List<Map<String, dynamic>> deliveries;
  final List<Map<String, dynamic>> rides;
  final DispatchInfo? dispatch;

  static const empty = AvailableDriverRequests();

  factory AvailableDriverRequests.fromJson(dynamic json) {
    if (json is! Map) return empty;
    final map = Map<String, dynamic>.from(json);
    return AvailableDriverRequests(
      deliveries: _mapList(map['deliveries']),
      rides: _mapList(map['rides']),
      dispatch: DispatchInfo.fromJson(map['dispatch']),
    );
  }

  static List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}

class DispatchInfo {
  const DispatchInfo({this.strategy, this.message});

  final String? strategy;
  final String? message;

  static DispatchInfo? fromJson(dynamic json) {
    if (json is! Map) return null;
    final map = Map<String, dynamic>.from(json);
    final strategy = map['strategy']?.toString().trim();
    final message = map['message']?.toString().trim();
    if ((strategy == null || strategy.isEmpty) &&
        (message == null || message.isEmpty)) {
      return null;
    }
    return DispatchInfo(
      strategy: strategy?.isEmpty == true ? null : strategy,
      message: message?.isEmpty == true ? null : message,
    );
  }
}

class DriverAvailability {
  DriverAvailability._();

  static bool? fromProfile(Map<String, dynamic>? profile) {
    if (profile == null) return null;
    return _bool(profile['is_available']) ??
        _bool(_asMap(profile['driver_profile'])?['is_available']) ??
        _bool(_asMap(profile['user'])?['is_available']) ??
        _fromAvailabilityString(profile['availability']) ??
        _fromAvailabilityString(
          _asMap(profile['driver_profile'])?['availability'],
        );
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static bool? _bool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.trim().toLowerCase();
      if (v == 'true' || v == '1') return true;
      if (v == 'false' || v == '0') return false;
    }
    return null;
  }

  static bool? _fromAvailabilityString(dynamic value) {
    if (value is! String) return _bool(value);
    final v = value.trim().toLowerCase();
    if (v == 'online' || v == 'available') return true;
    if (v == 'offline' || v == 'unavailable') return false;
    return _bool(value);
  }
}
