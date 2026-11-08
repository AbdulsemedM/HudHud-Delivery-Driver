import 'package:flutter_test/flutter_test.dart';
import 'package:hudhud_delivery_driver/core/models/parcel_extras.dart';

void main() {
  group('ParcelExtras', () {
    test('parses the courier parcel payload without any handover code', () {
      final extras = ParcelExtras.fromResponse({
        'success': true,
        'data': {
          'id': 41,
          'version': 2,
          'status': 'at_dropoff',
          'item': {'category': 'document', 'size': 'small', 'description': 'Contract', 'value': '1500'},
          'pickup_details': {'building': 'Edna Mall', 'floor': '3', 'ignored': 'x'},
          'dropoff_details': {'apartment': '12', 'landmark': ''},
          'courier_note': 'Call at the gate',
          'payer': 'recipient',
          'handover': {'required': true, 'verified': false, 'digits': 4},
          'proofs': {'pickup': 1, 'delivery': 0, 'return': 0},
          'delivery_photo_required': true,
          'can_fail': true,
          'return_required': false,
        },
      })!;

      expect(extras.isV2, isTrue);
      expect(extras.itemSize, 'small');
      expect(extras.itemValue, 1500);
      expect(extras.pickupDetails, {'building': 'Edna Mall', 'floor': '3'});
      expect(extras.dropoffDetails, {'apartment': '12'});
      expect(extras.recipientPays, isTrue);
      expect(extras.handoverDigits, 4);
      expect(extras.pickupPhotos, 1);
      expect(extras.deliveryPhotoMissing, isTrue);
      expect(extras.withDeliveryPhotos(1).deliveryPhotoMissing, isFalse);
      expect(extras.canFail, isTrue);
    });

    test('legacy or empty payloads are not v2', () {
      expect(ParcelExtras.fromResponse(null), isNull);
      expect(ParcelExtras.fromResponse({'success': false}), isNull);
      final legacy = ParcelExtras.fromResponse({'data': {'id': 3, 'version': 1}})!;
      expect(legacy.isV2, isFalse);
      expect(legacy.deliveryPhotoMissing, isFalse);
    });

    test('details line and fail reasons match the API', () {
      expect(
        parcelDetailsLine({'building': 'Tower', 'floor': '2'}, (k) => k.toUpperCase()),
        'BUILDING: Tower · FLOOR: 2',
      );
      expect(kParcelFailReasons, contains('recipient_unreachable'));
      expect(kParcelFailReasons, hasLength(6));
    });
  });
}
