import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/models/parcel_extras.dart';

Map<String, dynamic> _multiStopPayload() => {
      'success': true,
      'data': {
        'id': 52,
        'version': 2,
        'status': 'at_dropoff',
        'item': {'category': 'document', 'size': 'small'},
        'payer': 'sender',
        'handover': {'required': true, 'verified': false, 'digits': 4},
        'proofs': {'pickup': 0, 'delivery': 1, 'return': 0},
        'delivery_photo_required': true,
        'payment_timing': 'pickup',
        'collect_at_pickup': {'amount': '240', 'currency': 'etb', 'collected': true},
        'stop_count': 3,
        'current_stop': 2,
        'stops': [
          {
            'id': 102,
            'sequence': 2,
            'status': 'arrived',
            'address': 'Kazanchis',
            'lat': 9.02,
            'lng': 38.77,
            'details': {'building': 'Tower', 'ignored': 'x'},
            'note': 'Reception',
            'recipient_name': 'Dawit',
            'recipient_phone': '+251933555662',
            'handover': {'required': true, 'verified': false, 'locked': false, 'digits': 4},
            'is_current': true,
            'proofs': {'delivery': 0},
          },
          {
            'id': 101,
            'sequence': 1,
            'status': 'delivered',
            'handover': {'verified': true},
            'proofs': {'delivery': 1},
          },
          {'id': 103, 'sequence': 3, 'status': 'pending'},
          {'status': 'broken row without a sequence'},
        ],
      },
    };

void main() {
  group('Phase 11 parcel extras', () {
    test('parses stops in order with the current stop and no codes', () {
      final extras = ParcelExtras.fromResponse(_multiStopPayload())!;
      expect(extras.isMultiStop, isTrue);
      expect(extras.stops.map((s) => s.sequence), [1, 2, 3]);
      expect(extras.currentStop, 2);
      final current = extras.current!;
      expect(current.address, 'Kazanchis');
      expect(current.arrived, isTrue);
      expect(current.isCurrent, isTrue);
      expect(current.details, {'building': 'Tower'});
      expect(current.latitude, 9.02);
      expect(current.handoverDigits, 4);
      expect(current.deliveryPhotos, 0);
      expect(extras.stops.first.isResolved, isTrue);
      expect(extras.stops.last.isResolved, isFalse);
      expect(jsonEncode(_multiStopPayload()).contains('"code"'), isFalse,
          reason: 'the courier payload never has a handover code');
    });

    test('pay at pickup amount is shown in the parcel currency', () {
      final extras = ParcelExtras.fromResponse(_multiStopPayload())!;
      expect(extras.paysAtPickup, isTrue);
      expect(extras.paymentTiming, 'pickup');
      expect(extras.collectAtPickup!.label, 'ETB 240.00');
      expect(extras.collectAtPickup!.collected, isTrue);
      // copyWith keeps the Phase 11 fields.
      final copy = extras.withDeliveryPhotos(2);
      expect(copy.stops, hasLength(3));
      expect(copy.collectAtPickup, isNotNull);
    });

    test('single-stop and older payloads have no stops or cash at pickup', () {
      final extras = ParcelExtras.fromResponse({
        'data': {'id': 3, 'version': 2, 'payment_timing': 'booking', 'stops': []},
      })!;
      expect(extras.isMultiStop, isFalse);
      expect(extras.paysAtPickup, isFalse);
      expect(extras.current, isNull);
      final legacy = ParcelExtras.fromResponse({'data': {'id': 4, 'version': 1}})!;
      expect(legacy.stops, isEmpty);
      expect(legacy.collectAtPickup, isNull);
    });

    test('every parcel string used by the app exists in en and ar', () {
      final en = jsonDecode(File('assets/lang/en.json').readAsStringSync())['parcel'] as Map;
      final ar = jsonDecode(File('assets/lang/ar.json').readAsStringSync())['parcel'] as Map;
      final used = <String>{};
      final pattern = RegExp(r"'parcel\.([a-z_]+)'");
      for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        for (final m in pattern.allMatches(file.readAsStringSync())) {
          used.add(m.group(1)!);
        }
      }
      // Dynamic keys built from a prefix.
      used.removeWhere((k) => k.endsWith('_'));
      expect(used, containsAll(<String>['stop_n', 'collect_at_pickup', 'stops_title']));
      for (final key in used) {
        expect(en.containsKey(key), isTrue, reason: 'en.json parcel.$key');
        expect(ar.containsKey(key), isTrue, reason: 'ar.json parcel.$key');
      }
      expect(en['stop_n'], contains('{number}'));
      expect(ar['collect_at_pickup'], contains('{amount}'));
    });
  });
}
