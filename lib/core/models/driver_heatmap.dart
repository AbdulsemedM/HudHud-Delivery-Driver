import 'package:hudhud_delivery_driver/core/utils/json_parse.dart';

/// Demand level of one heatmap cell (contract §4: low | medium | high).
enum DemandLevel {
  low,
  medium,
  high,
  unknown;

  static DemandLevel fromApi(dynamic raw) {
    switch (raw?.toString().trim().toLowerCase()) {
      case 'low':
        return DemandLevel.low;
      case 'medium':
      case 'med':
        return DemandLevel.medium;
      case 'high':
        return DemandLevel.high;
      default:
        return DemandLevel.unknown;
    }
  }
}

/// One grid cell from `GET /api/driver/heatmap`. [lat]/[lng] are treated as
/// the cell centre.
class HeatmapCell {
  const HeatmapCell({
    required this.lat,
    required this.lng,
    this.demand = 0,
    this.supply = 0,
    this.level = DemandLevel.unknown,
  });

  final double lat;
  final double lng;
  final int demand;
  final int supply;
  final DemandLevel level;

  /// Accepts `3`, `3.0`, `"3"` and `"3.0"`.
  static int _count(dynamic raw) =>
      JsonParse.toInt(raw) ?? JsonParse.toDouble(raw)?.round() ?? 0;

  /// Returns null when the cell has no usable coordinates.
  static HeatmapCell? fromJson(dynamic raw) {
    final map = JsonParse.toMap(raw);
    if (map == null) return null;
    final lat = JsonParse.toDouble(map['lat'] ?? map['latitude']);
    final lng = JsonParse.toDouble(map['lng'] ?? map['lon'] ?? map['longitude']);
    if (lat == null || lng == null) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return HeatmapCell(
      lat: lat,
      lng: lng,
      demand: _count(map['demand']),
      supply: _count(map['supply']),
      level: DemandLevel.fromApi(map['level']),
    );
  }
}

/// Response of `GET /api/driver/heatmap`.
class DriverHeatmap {
  const DriverHeatmap({
    this.enabled = true,
    this.generatedAt,
    this.cellSizeKm = defaultCellSizeKm,
    this.cells = const [],
  });

  static const double defaultCellSizeKm = 1.0;

  /// False when the backend flag `drivers.heatmap_enabled` is off.
  final bool enabled;
  final DateTime? generatedAt;
  final double cellSizeKm;
  final List<HeatmapCell> cells;

  /// Accepts the standard envelope (`{success, data: {...}}`) or a bare body.
  /// Returns null when the payload is not a JSON object.
  static DriverHeatmap? fromJson(dynamic raw) {
    final map = JsonParse.toMap(raw);
    if (map == null) return null;
    final data = JsonParse.toMap(map['data']) ?? map;

    final enabledRaw = data.containsKey('enabled') ? data['enabled'] : map['enabled'];
    final enabled = JsonParse.toBool(enabledRaw, defaultValue: true);

    final size = JsonParse.toDouble(data['cell_size_km']);
    final cellsRaw = data['cells'];
    final cells = <HeatmapCell>[];
    if (cellsRaw is List) {
      for (final item in cellsRaw) {
        final cell = HeatmapCell.fromJson(item);
        if (cell != null) cells.add(cell);
      }
    }

    return DriverHeatmap(
      enabled: enabled,
      generatedAt: JsonParse.toDateTime(data['generated_at']),
      cellSizeKm: size != null && size > 0 ? size : defaultCellSizeKm,
      cells: cells,
    );
  }
}
