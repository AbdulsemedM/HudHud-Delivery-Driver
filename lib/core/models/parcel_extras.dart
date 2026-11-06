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
    this.paymentTiming,
    this.collectAtPickup,
    this.stops = const [],
    this.currentStop,
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

  /// Phase 11: booking | pickup | dropoff.
  final String? paymentTiming;

  /// Phase 11: cash the sender pays at pickup (null unless pay-at-pickup).
  final ParcelPickupCash? collectAtPickup;

  /// Phase 11: drop-offs of a multi-stop parcel, in order (empty otherwise).
  final List<ParcelCourierStop> stops;

  /// Sequence of the stop to serve now.
  final int? currentStop;

  bool get isV2 => version >= 2;
  bool get isMultiStop => stops.length > 1;
  bool get paysAtPickup => collectAtPickup != null;

  ParcelCourierStop? get current {
    for (final stop in stops) {
      if (stop.sequence == currentStop) return stop;
    }
    return null;
  }
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
      paymentTiming: data['payment_timing']?.toString(),
      collectAtPickup: ParcelPickupCash.fromJson(data['collect_at_pickup']),
      stops: ParcelCourierStop.listFrom(data['stops']),
      currentStop: JsonParse.toInt(data['current_stop']),
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
        paymentTiming: paymentTiming,
        collectAtPickup: collectAtPickup,
        stops: stops,
        currentStop: currentStop,
      );
}

/// Phase 11: cash to collect from the sender before confirming pickup.
class ParcelPickupCash {
  const ParcelPickupCash({
    required this.amount,
    this.currency,
    this.collected = false,
  });

  final double amount;
  final String? currency;
  final bool collected;

  static ParcelPickupCash? fromJson(dynamic raw) {
    final map = JsonParse.toMap(raw);
    if (map == null) return null;
    return ParcelPickupCash(
      amount: JsonParse.toDouble(map['amount']) ?? 0,
      currency: map['currency']?.toString(),
      collected: JsonParse.toBool(map['collected']),
    );
  }

  /// "ETB 240.00" in the parcel currency.
  String get label {
    final value = amount.toStringAsFixed(2);
    final code = currency?.trim().toUpperCase() ?? '';
    return code.isEmpty ? value : '$code $value';
  }
}

/// Phase 11: one drop-off as the courier sees it (never the handover code).
class ParcelCourierStop {
  const ParcelCourierStop({
    required this.sequence,
    this.status = 'pending',
    this.address,
    this.latitude,
    this.longitude,
    this.details = const {},
    this.note,
    this.recipientName,
    this.recipientPhone,
    this.handoverVerified = false,
    this.handoverLocked = false,
    this.handoverDigits = 4,
    this.isCurrent = false,
    this.deliveryPhotos = 0,
  });

  final int sequence;

  /// pending | arrived | delivered | failed | returned
  final String status;
  final String? address;
  final double? latitude;
  final double? longitude;
  final Map<String, String> details;
  final String? note;
  final String? recipientName;
  final String? recipientPhone;
  final bool handoverVerified;
  final bool handoverLocked;
  final int handoverDigits;
  final bool isCurrent;
  final int deliveryPhotos;

  bool get isResolved =>
      status == 'delivered' || status == 'failed' || status == 'returned';
  bool get arrived => status == 'arrived';

  static ParcelCourierStop? fromJson(dynamic raw) {
    final map = JsonParse.toMap(raw);
    final sequence = JsonParse.toInt(map?['sequence']);
    if (map == null || sequence == null) return null;
    final handover = JsonParse.toMap(map['handover']) ?? const <String, dynamic>{};
    final proofs = JsonParse.toMap(map['proofs']) ?? const <String, dynamic>{};
    return ParcelCourierStop(
      sequence: sequence,
      status: map['status']?.toString() ?? 'pending',
      address: map['address']?.toString(),
      latitude: JsonParse.toDouble(map['lat']),
      longitude: JsonParse.toDouble(map['lng']),
      details: ParcelExtras._details(map['details']),
      note: map['note']?.toString(),
      recipientName: map['recipient_name']?.toString(),
      recipientPhone: map['recipient_phone']?.toString(),
      handoverVerified: JsonParse.toBool(handover['verified']),
      handoverLocked: JsonParse.toBool(handover['locked']),
      handoverDigits: JsonParse.toInt(handover['digits']) ?? 4,
      isCurrent: JsonParse.toBool(map['is_current']),
      deliveryPhotos: JsonParse.toInt(proofs['delivery']) ?? 0,
    );
  }

  static List<ParcelCourierStop> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    final out = <ParcelCourierStop>[];
    for (final item in raw) {
      final stop = fromJson(item);
      if (stop != null) out.add(stop);
    }
    out.sort((a, b) => a.sequence.compareTo(b.sequence));
    return out;
  }
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
