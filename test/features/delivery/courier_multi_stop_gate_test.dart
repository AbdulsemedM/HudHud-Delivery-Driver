import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/models/parcel_extras.dart';

/// Which deliveries get the stop-by-stop completion screen.
///
/// The whole rider-side multi-stop flow already existed — the stop list, the
/// per-stop arrive / code / complete / fail, the API client — and it was shut
/// behind `isV2`, meaning a parcels v2 booking and nothing else.
///
/// A classic courier delivery with three drop-offs carries `stop_count` but
/// not `version: 2`. It got the single-drop screen: the rider completed it
/// once and the other two stops never happened. The backend never had that
/// restriction — /driver/parcels/{id} and the four stop endpoints check only
/// that this rider is assigned — so the UI was stricter than the thing it
/// talks to.
///
/// The gate is now "does this delivery have stops", which is what it was
/// always asking.
Map<String, dynamic> _payload({
  required int version,
  required int stopCount,
}) =>
    {
      'success': true,
      'data': {
        'id': 77,
        'version': version,
        'status': 'en_route_dropoff',
        'item': {'category': 'parcel'},
        'payer': 'sender',
        'handover': {'required': true, 'verified': false, 'digits': 4},
        'stop_count': stopCount,
        'current_stop': 1,
        'stops': List.generate(
          stopCount,
          (i) => {
            'id': 500 + i,
            'sequence': i + 1,
            'status': i == 0 ? 'pending' : 'pending',
            'address': 'Stop ${i + 1}',
            'lat': 9.0 + i / 100,
            'lng': 38.7 + i / 100,
            'recipient_name': 'Receiver ${i + 1}',
            'recipient_phone': '25191100000${i + 1}',
            'handover': {'required': true, 'verified': false, 'digits': 4},
          },
        ),
      },
    };

/// The condition both the completion page and the courier card now use.
bool showsStopFlow(ParcelExtras? extras) =>
    extras != null && (extras.isV2 || extras.isMultiStop);

void main() {
  group('the stop-by-stop screen', () {
    test('opens for a classic courier delivery with several drop-offs', () {
      // version 1 — booked through services/delivery/request, not parcels v2.
      final extras =
          ParcelExtras.fromResponse(_payload(version: 1, stopCount: 3));

      expect(extras, isNotNull);
      expect(extras!.isV2, isFalse, reason: 'this is a courier delivery');
      expect(extras.isMultiStop, isTrue);
      expect(
        showsStopFlow(extras),
        isTrue,
        reason: 'three drop-offs must be completed one at a time',
      );
    });

    test('still opens for a multi-stop parcels v2 booking', () {
      final extras =
          ParcelExtras.fromResponse(_payload(version: 2, stopCount: 2));

      expect(showsStopFlow(extras), isTrue);
    });

    test('stays shut for an ordinary single-drop courier delivery', () {
      // The case that must not change: one drop-off keeps the classic screen.
      final extras =
          ParcelExtras.fromResponse(_payload(version: 1, stopCount: 1));

      expect(extras!.isMultiStop, isFalse);
      expect(showsStopFlow(extras), isFalse);
    });

    test('a single-drop v2 parcel keeps its own screen', () {
      final extras =
          ParcelExtras.fromResponse(_payload(version: 2, stopCount: 1));

      // isV2 alone still opens it — parcels v2 has handover and proof steps
      // of its own that do not depend on there being several stops.
      expect(showsStopFlow(extras), isTrue);
    });

    test('every stop is parsed with its own receiver', () {
      final extras =
          ParcelExtras.fromResponse(_payload(version: 1, stopCount: 3))!;

      expect(extras.stops.map((s) => s.sequence), [1, 2, 3]);
      expect(extras.stops[1].recipientName, 'Receiver 2');
      expect(extras.current?.sequence, 1);
    });
  });
}
