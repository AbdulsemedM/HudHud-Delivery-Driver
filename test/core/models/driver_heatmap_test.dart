import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/models/driver_heatmap.dart';

void main() {
  group('DriverHeatmap.fromJson', () {
    test('parses contract envelope', () {
      final heatmap = DriverHeatmap.fromJson({
        'success': true,
        'data': {
          'generated_at': '2026-11-04T09:00:00Z',
          'cell_size_km': 0.5,
          'cells': [
            {
              'lat': 9.03,
              'lng': 38.74,
              'demand': 12,
              'supply': 3,
              'level': 'high',
            },
            {
              'lat': 9.04,
              'lng': 38.75,
              'demand': 2,
              'supply': 4,
              'level': 'low',
            },
          ],
        },
      });

      expect(heatmap, isNotNull);
      expect(heatmap!.enabled, isTrue);
      expect(heatmap.generatedAt, DateTime.utc(2026, 11, 4, 9));
      expect(heatmap.cellSizeKm, 0.5);
      expect(heatmap.cells.length, 2);
      expect(heatmap.cells.first.lat, 9.03);
      expect(heatmap.cells.first.lng, 38.74);
      expect(heatmap.cells.first.demand, 12);
      expect(heatmap.cells.first.supply, 3);
      expect(heatmap.cells.first.level, DemandLevel.high);
      expect(heatmap.cells.last.level, DemandLevel.low);
    });

    test('tolerates string numbers and bare body', () {
      final heatmap = DriverHeatmap.fromJson({
        'cell_size_km': '1.5',
        'cells': [
          {
            'lat': '9.03',
            'lng': '38.74',
            'demand': '7',
            'supply': '1.0',
            'level': 'MEDIUM',
          },
        ],
      });

      expect(heatmap!.cellSizeKm, 1.5);
      final cell = heatmap.cells.single;
      expect(cell.lat, 9.03);
      expect(cell.demand, 7);
      expect(cell.supply, 1);
      expect(cell.level, DemandLevel.medium);
    });

    test('skips cells without valid coordinates', () {
      final heatmap = DriverHeatmap.fromJson({
        'data': {
          'cells': [
            {'lat': null, 'lng': 38.7, 'level': 'high'},
            {'lat': 120, 'lng': 38.7, 'level': 'high'},
            {'lat': 9.0, 'lng': 'x', 'level': 'high'},
            'garbage',
            {'lat': 9.0, 'lng': 38.7, 'level': 'unexpected'},
          ],
        },
      });

      expect(heatmap!.cells.length, 1);
      expect(heatmap.cells.single.level, DemandLevel.unknown);
    });

    test('defaults cell size when missing or invalid', () {
      expect(
        DriverHeatmap.fromJson({'data': {'cells': []}})!.cellSizeKm,
        DriverHeatmap.defaultCellSizeKm,
      );
      expect(
        DriverHeatmap.fromJson({
          'data': {'cell_size_km': 0, 'cells': []},
        })!.cellSizeKm,
        DriverHeatmap.defaultCellSizeKm,
      );
    });

    test('reads enabled:false', () {
      final heatmap = DriverHeatmap.fromJson({
        'success': true,
        'data': {'enabled': false, 'cells': []},
      });
      expect(heatmap!.enabled, isFalse);

      final topLevel = DriverHeatmap.fromJson({
        'success': true,
        'enabled': false,
        'data': {'cells': []},
      });
      expect(topLevel!.enabled, isFalse);
    });

    test('returns null for non-object payloads', () {
      expect(DriverHeatmap.fromJson(null), isNull);
      expect(DriverHeatmap.fromJson('nope'), isNull);
      expect(DriverHeatmap.fromJson([1, 2]), isNull);
    });
  });
}
