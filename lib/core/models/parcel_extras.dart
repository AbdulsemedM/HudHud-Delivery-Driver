import 'package:hudhud_delivery_driver/core/utils/json_parse.dart';

/// Phase 10 parcel extras for the assigned courier
/// (`GET /api/driver/parcels/{id}`). Never carries the handover code: the
/// recipient gives it to the courier at the door.
class ParcelExtras {
  const ParcelExtras({
    this.version = 1,
    this.status,
    this.itemCategory,
    this.itemSize,
    this.itemDescription,
    this.itemValue,
    this.pickupDetails = const {},
    this.dropoffDetails = const {},
    this.courierNote,
    this.payer = 'sender',
    this.handoverDigits = 6,
    this.handoverVerified = false,
    this.pickupPhotos = 0,
    this.deliveryPhotos = 0,
    this.deliveryPhotoRequired = false,
    this.canFail = false,
    this.returnRequired = false,
  });

  final int version;
  final String? status;
  final String? itemCategory;
  final String? itemSize;
  final String? itemDescription;
  final double? itemValue;
  final Map<String, String> pickupDetails;
  final Map<String, String> dropoffDetails;
  final String? courierNote;
  final String payer;
  final int handoverDigits;
  final bool handoverVerified;
  final int pickupPhotos;
  final int deliveryPhotos;
  final bool deliveryPhotoRequired;
  final bool canFail;
  final bool returnRequired;

  bool get isV2 => version >= 2;
  bool get recipientPays => payer == 'recipient';
  bool get deliveryPhotoMissing => deliveryPhotoRequired && deliveryPhotos == 0;

  static Map<String, String> _details(dynamic raw) {
    final map = JsonParse.toMap(raw);
    if (map == null) return const {};
    final out = <String, String>{};
    for (final key in const ['building', 'entrance', 'floor', 'apartment', 'landmark']) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty) out[key] = value;
    }
    return out;
  }

  /// Accepts the raw response (`{success, data: {...}}`) or the data map.
  static ParcelExtras? fromResponse(dynamic raw) {
    final root = JsonParse.toMap(raw);
    if (root == null) return null;
    final data = JsonParse.toMap(root['data']) ?? root;
    if (data['id'] == null && data['version'] == null) return null;
    final item = JsonParse.toMap(data['item']) ?? const <String, dynamic>{};
    final handover = JsonParse.toMap(data['handover']) ?? const <String, dynamic>{};
    final proofs = JsonParse.toMap(data['proofs']) ?? const <String, dynamic>{};
    return ParcelExtras(
      version: JsonParse.toInt(data['version']) ?? 1,
      status: data['status']?.toString(),
      itemCategory: item['category']?.toString(),
      itemSize: item['size']?.toString(),
      itemDescription: item['description']?.toString(),
      itemValue: JsonParse.toDouble(item['value']),
      pickupDetails: _details(data['pickup_details']),
      dropoffDetails: _details(data['dropoff_details']),
      courierNote: data['courier_note']?.toString(),
      payer: data['payer']?.toString() ?? 'sender',
      handoverDigits: JsonParse.toInt(handover['digits']) ?? 6,
      handoverVerified: JsonParse.toBool(handover['verified']),
      pickupPhotos: JsonParse.toInt(proofs['pickup']) ?? 0,
      deliveryPhotos: JsonParse.toInt(proofs['delivery']) ?? 0,
      deliveryPhotoRequired: JsonParse.toBool(data['delivery_photo_required']),
      canFail: JsonParse.toBool(data['can_fail']),
      returnRequired: JsonParse.toBool(data['return_required']),
    );
  }

  ParcelExtras withDeliveryPhotos(int count) => ParcelExtras(
        version: version,
        status: status,
        itemCategory: itemCategory,
        itemSize: itemSize,
        itemDescription: itemDescription,
        itemValue: itemValue,
        pickupDetails: pickupDetails,
        dropoffDetails: dropoffDetails,
        courierNote: courierNote,
        payer: payer,
        handoverDigits: handoverDigits,
        handoverVerified: handoverVerified,
        pickupPhotos: pickupPhotos,
        deliveryPhotos: count,
        deliveryPhotoRequired: deliveryPhotoRequired,
        canFail: canFail,
        returnRequired: returnRequired,
      );
}

/// Reasons accepted by `POST /api/driver/parcels/{id}/fail`.
const List<String> kParcelFailReasons = [
  'recipient_unreachable',
  'recipient_refused',
  'wrong_address',
  'unsafe_location',
  'damaged',
  'other',
];

/// "Building: X · Floor: 3" line for a details map (labels via [label]).
String parcelDetailsLine(
  Map<String, String> details,
  String Function(String key) label,
) {
  return details.entries.map((e) => '${label(e.key)}: ${e.value}').join(' · ');
}
