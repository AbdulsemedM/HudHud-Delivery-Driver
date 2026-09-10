import 'package:hudhud_delivery_driver/core/models/active_job.dart';
import 'package:hudhud_delivery_driver/core/models/driver_navigation.dart';
import 'package:hudhud_delivery_driver/core/utils/json_parse.dart';

/// GET /api/driver/services/current-status — authoritative active job recovery.
class DriverCurrentStatus {
  const DriverCurrentStatus({
    this.activeJob,
    this.navigation,
    this.delivery,
    this.ride,
    this.order,
    this.activeService,
    this.raw = const {},
  });

  final ActiveJob? activeJob;
  final DriverNavigation? navigation;
  final Map<String, dynamic>? delivery;
  final Map<String, dynamic>? ride;
  /// Commerce / street-pickup order payload when present.
  final Map<String, dynamic>? order;
  final Map<String, dynamic>? activeService;
  final Map<String, dynamic> raw;

  /// Active package job id — delivery service or commerce order (street pickup).
  int? get deliveryId {
    if (activeJob?.type == ActiveJobType.delivery ||
        activeJob?.type == ActiveJobType.order) {
      return activeJob?.id;
    }
    final fromDelivery = JsonParse.toInt(delivery?['id']);
    if (fromDelivery != null) return fromDelivery;
    final fromOrder = JsonParse.toInt(order?['id']);
    if (fromOrder != null) return fromOrder;
    final fromService = JsonParse.toInt(activeService?['id']);
    if (fromService != null && _serviceIsOrder(activeService)) {
      return fromService;
    }
    final map = JsonParse.toMap(raw);
    if (map == null) return null;
    final data = JsonParse.toMap(map['data']) ?? map;
    return JsonParse.toInt(data['delivery_id']) ??
        JsonParse.toInt(data['current_delivery_id']) ??
        JsonParse.toInt(data['order_id']) ??
        JsonParse.toInt(data['current_order_id']) ??
        JsonParse.toInt(map['delivery_id']) ??
        JsonParse.toInt(map['current_delivery_id']) ??
        JsonParse.toInt(map['order_id']) ??
        JsonParse.toInt(map['current_order_id']);
  }

  int? get rideId {
    if (activeJob?.type == ActiveJobType.ride) return activeJob?.id;
    return JsonParse.toInt(ride?['id']);
  }

  bool get hasActiveDelivery => deliveryId != null;

  bool get isStreetPickupOrder {
    if (_isStreetPickupMap(order)) return true;
    if (_isStreetPickupMap(activeService)) return true;
    if (_isStreetPickupMap(delivery)) return true;
    final st = activeService?['service_type']?.toString().toLowerCase().trim();
    return st == 'street_pickup';
  }

  static bool _serviceIsOrder(Map<String, dynamic>? service) {
    if (service == null) return false;
    final type = service['type']?.toString().toLowerCase().trim();
    if (type == 'order') return true;
    return _isStreetPickupMap(service);
  }

  static bool _isStreetPickupMap(Map<String, dynamic>? map) {
    if (map == null) return false;
    if (map['is_street_pickup'] == true) return true;
    final reason = map['reason_code']?.toString().toLowerCase().trim();
    if (reason == 'street_pickup') return true;
    final serviceType = map['service_type']?.toString().toLowerCase().trim();
    return serviceType == 'street_pickup';
  }

  factory DriverCurrentStatus.fromJson(dynamic raw) {
    if (raw is! Map) {
      return const DriverCurrentStatus();
    }
    final map = Map<String, dynamic>.from(raw);
    final data = map['data'] is Map
        ? Map<String, dynamic>.from(map['data'] as Map)
        : map;

    final activeService = JsonParse.toMap(data['active_service']) ??
        JsonParse.toMap(map['active_service']);

    final activeJob = ActiveJob.fromJson(data['active_job']) ??
        ActiveJob.fromJson(data['current_job']) ??
        ActiveJob.fromJson(map['active_job']) ??
        ActiveJob.fromJson(activeService);

    final delivery = JsonParse.toMap(data['delivery']) ??
        JsonParse.toMap(map['delivery']);
    final ride =
        JsonParse.toMap(data['ride']) ?? JsonParse.toMap(map['ride']);
    final order = JsonParse.toMap(data['order']) ??
        JsonParse.toMap(map['order']) ??
        (_serviceIsOrder(activeService) ? activeService : null);

    ActiveJob? resolvedJob = activeJob;
    if (resolvedJob == null && order != null) {
      final id = JsonParse.toInt(order['id']);
      if (id != null) {
        resolvedJob = ActiveJob(
          type: ActiveJobType.order,
          id: id,
          status: order['status']?.toString(),
        );
      }
    }
    if (resolvedJob == null && delivery != null) {
      final id = JsonParse.toInt(delivery['id']);
      if (id != null) {
        resolvedJob = ActiveJob(
          type: ActiveJobType.delivery,
          id: id,
          status: delivery['status']?.toString(),
        );
      }
    }
    if (resolvedJob == null && ride != null) {
      final id = JsonParse.toInt(ride['id']);
      if (id != null) {
        resolvedJob = ActiveJob(
          type: ActiveJobType.ride,
          id: id,
          status: ride['status']?.toString(),
        );
      }
    }
    // active_service.type=order with id but no nested order map
    if (resolvedJob == null && _serviceIsOrder(activeService)) {
      final id = JsonParse.toInt(activeService?['id']);
      if (id != null) {
        resolvedJob = ActiveJob(
          type: ActiveJobType.order,
          id: id,
          status: activeService?['status']?.toString(),
        );
      }
    }

    return DriverCurrentStatus(
      activeJob: resolvedJob,
      navigation: DriverNavigation.fromPayload(data) ??
          DriverNavigation.fromPayload(map) ??
          DriverNavigation.fromPayload(activeService) ??
          DriverNavigation.fromPayload(order) ??
          DriverNavigation.fromPayload(delivery),
      delivery: delivery,
      ride: ride,
      order: order,
      activeService: activeService,
      raw: map,
    );
  }
}
