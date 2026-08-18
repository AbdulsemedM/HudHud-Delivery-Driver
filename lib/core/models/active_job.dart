import 'package:hudhud_delivery_driver/core/utils/json_parse.dart';

enum ActiveJobType {
  ride,
  delivery,
  order,
  unknown;

  static ActiveJobType fromApi(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'ride':
        return ActiveJobType.ride;
      case 'delivery':
        return ActiveJobType.delivery;
      case 'order':
        return ActiveJobType.order;
      default:
        return ActiveJobType.unknown;
    }
  }
}

class ActiveJob {
  const ActiveJob({
    this.type = ActiveJobType.unknown,
    this.id,
    this.status,
    this.acceptedAt,
    this.startedAt,
    this.trackingNumber,
  });

  final ActiveJobType type;
  final int? id;
  final String? status;
  final DateTime? acceptedAt;
  final DateTime? startedAt;
  final String? trackingNumber;

  static ActiveJob? fromJson(dynamic raw) {
    final map = JsonParse.toMap(raw);
    if (map == null) return null;
    final id = JsonParse.toInt(map['id']);
    final type = ActiveJobType.fromApi(map['type']?.toString());
    if (id == null && type == ActiveJobType.unknown) return null;
    return ActiveJob(
      type: type,
      id: id,
      status: map['status']?.toString(),
      acceptedAt: JsonParse.toDateTime(map['accepted_at']),
      startedAt: JsonParse.toDateTime(map['started_at']),
      trackingNumber: map['tracking_number']?.toString(),
    );
  }

  /// Profile pointers are not the server authority; used only to disable Accept locally.
  static ActiveJob? fromDriverProfile(dynamic profile) {
    final map = JsonParse.toMap(profile);
    if (map == null) return null;
    final driverProfile = JsonParse.toMap(map['driver_profile']) ?? map;
    final rideId = JsonParse.toInt(driverProfile['current_ride_id']);
    if (rideId != null) {
      return ActiveJob(type: ActiveJobType.ride, id: rideId);
    }
    final deliveryId = JsonParse.toInt(driverProfile['current_delivery_id']);
    if (deliveryId != null) {
      return ActiveJob(type: ActiveJobType.delivery, id: deliveryId);
    }
    final orderId = JsonParse.toInt(driverProfile['current_order_id']);
    if (orderId != null) {
      return ActiveJob(type: ActiveJobType.order, id: orderId);
    }
    return null;
  }

  /// Delivery-home pointer from profile (`current_delivery_id`, optional `current_job`).
  static int? deliveryIdFromProfile(dynamic profile) {
    final map = JsonParse.toMap(profile);
    if (map == null) return null;

    final driverProfile = JsonParse.toMap(map['driver_profile']) ?? map;
    final fromPointer = JsonParse.toInt(driverProfile['current_delivery_id']);
    if (fromPointer != null) return fromPointer;

    final currentJob = ActiveJob.fromJson(map['current_job']) ??
        ActiveJob.fromJson(driverProfile['current_job']);
    if (currentJob?.type == ActiveJobType.delivery && currentJob?.id != null) {
      return currentJob!.id;
    }

    return null;
  }

  /// Resolves which delivery id delivery home should load.
  static int? resolveDeliveryIdForHome({
    Map<String, dynamic>? profile,
    int? initialDeliveryId,
    int? currentActiveId,
    int? cachedDeliveryId,
  }) {
    return deliveryIdFromProfile(profile) ??
        initialDeliveryId ??
        currentActiveId ??
        cachedDeliveryId;
  }
}
