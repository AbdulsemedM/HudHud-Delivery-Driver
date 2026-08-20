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
    this.raw = const {},
  });

  final ActiveJob? activeJob;
  final DriverNavigation? navigation;
  final Map<String, dynamic>? delivery;
  final Map<String, dynamic>? ride;
  final Map<String, dynamic> raw;

  int? get deliveryId {
    if (activeJob?.type == ActiveJobType.delivery) return activeJob?.id;
    return JsonParse.toInt(delivery?['id']);
  }

  int? get rideId {
    if (activeJob?.type == ActiveJobType.ride) return activeJob?.id;
    return JsonParse.toInt(ride?['id']);
  }

  bool get hasActiveDelivery => deliveryId != null;

  factory DriverCurrentStatus.fromJson(dynamic raw) {
    if (raw is! Map) {
      return const DriverCurrentStatus();
    }
    final map = Map<String, dynamic>.from(raw);
    final data = map['data'] is Map
        ? Map<String, dynamic>.from(map['data'] as Map)
        : map;

    final activeJob = ActiveJob.fromJson(data['active_job']) ??
        ActiveJob.fromJson(data['current_job']) ??
        ActiveJob.fromJson(map['active_job']);

    final delivery = JsonParse.toMap(data['delivery']) ??
        JsonParse.toMap(map['delivery']);
    final ride =
        JsonParse.toMap(data['ride']) ?? JsonParse.toMap(map['ride']);

    ActiveJob? resolvedJob = activeJob;
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

    return DriverCurrentStatus(
      activeJob: resolvedJob,
      navigation: DriverNavigation.fromPayload(data) ??
          DriverNavigation.fromPayload(map) ??
          DriverNavigation.fromPayload(delivery),
      delivery: delivery,
      ride: ride,
      raw: map,
    );
  }
}
