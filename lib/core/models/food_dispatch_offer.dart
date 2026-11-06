import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';
import 'package:hudhud_delivery_driver/core/utils/json_parse.dart';

/// A food order the system offers to this rider (Phase 10 system dispatch,
/// Keeta model: one rider at a time, accept or decline before it expires).
///
/// From `GET /api/driver/dispatch/offers/current` → `data` (also the
/// `dispatch_offer` of a row in `GET /api/driver/orders/available`). The FCM
/// push (`type: food_dispatch_offer`) carries the same fields as strings but
/// is only a wake-up: the app re-reads the offer from the API.
///
/// No customer name / phone / exact address before accept: only the
/// restaurant, the distance to it and the drop-off neighbourhood.
class FoodDispatchOffer {
  FoodDispatchOffer({
    required this.offerId,
    required this.orderId,
    required this.deadline,
    this.orderNumber,
    this.timeoutSeconds = defaultTimeoutSeconds,
    this.restaurantName,
    this.restaurantAddress,
    this.restaurantLatitude,
    this.restaurantLongitude,
    this.pickupDistanceKm,
    this.dropoffArea,
    this.earningsEstimate,
    this.currency,
    this.paymentMethod,
    this.isCash = false,
    this.isGift = false,
    this.itemsCount = 0,
    this.waitingForFood = false,
  });

  static const int defaultTimeoutSeconds = 30;

  final int offerId;
  final int orderId;
  final String? orderNumber;

  /// Local device time when the offer expires: received time +
  /// `expires_in_seconds`, so a wrong phone clock cannot shorten or lengthen
  /// the countdown.
  final DateTime deadline;

  /// Full offer window (`timeout_seconds`, setting dispatch.offer_timeout_seconds).
  final int timeoutSeconds;
  final String? restaurantName;
  final String? restaurantAddress;
  final double? restaurantLatitude;
  final double? restaurantLongitude;

  /// Straight-line km from the rider to the restaurant when offered.
  final double? pickupDistanceKm;

  /// Neighbourhood only (never the exact address before accept).
  final String? dropoffArea;

  /// What the rider earns, as computed by the API (`earnings_estimate`).
  final double? earningsEstimate;

  /// `ETB` (Addis) or `USD` (Hargeisa); null means ETB.
  final String? currency;
  final String? paymentMethod;

  /// Cash on delivery: the rider collects the order total.
  final bool isCash;
  final bool isGift;
  final int itemsCount;

  /// The restaurant is still cooking (offer sent ahead of ready time).
  final bool waitingForFood;

  int secondsLeft(DateTime now) {
    final ms = deadline.difference(now).inMilliseconds;
    if (ms <= 0) return 0;
    return (ms / 1000).ceil();
  }

  bool isExpired(DateTime now) => secondsLeft(now) <= 0;

  /// 1.0 when just offered → 0.0 when expired (countdown ring).
  double remainingFraction(DateTime now) {
    final total = timeoutSeconds <= 0 ? defaultTimeoutSeconds : timeoutSeconds;
    final ms = deadline.difference(now).inMilliseconds;
    return (ms / (total * 1000)).clamp(0.0, 1.0).toDouble();
  }

  String get displayNumber {
    final number = orderNumber?.trim();
    return number == null || number.isEmpty ? '#$orderId' : number;
  }

  /// Parses the API offer (`data` of offers/current). [receivedAt] defaults
  /// to now and anchors the countdown.
  static FoodDispatchOffer? fromJson(dynamic raw, {DateTime? receivedAt}) {
    final map = JsonParse.toMap(raw);
    if (map == null) return null;
    final offerId =
        JsonParse.toInt(map['offer_id']) ?? JsonParse.toInt(map['id']);
    final orderId = JsonParse.toInt(map['order_id']);
    if (offerId == null || offerId <= 0 || orderId == null || orderId <= 0) {
      return null;
    }
    final restaurant = JsonParse.toMap(map['restaurant']);
    final now = receivedAt ?? DateTime.now();
    return FoodDispatchOffer(
      offerId: offerId,
      orderId: orderId,
      orderNumber: _text(map['order_number']),
      deadline: _deadline(map, now),
      timeoutSeconds:
          JsonParse.toInt(map['timeout_seconds']) ?? defaultTimeoutSeconds,
      restaurantName:
          _text(restaurant?['name']) ?? _text(map['restaurant_name']),
      restaurantAddress:
          _text(restaurant?['address']) ?? _text(map['pickup_location']),
      restaurantLatitude: JsonParse.toDouble(restaurant?['latitude']) ??
          JsonParse.toDouble(map['pickup_latitude']),
      restaurantLongitude: JsonParse.toDouble(restaurant?['longitude']) ??
          JsonParse.toDouble(map['pickup_longitude']),
      pickupDistanceKm: JsonParse.toDouble(map['pickup_distance_km']),
      dropoffArea: _text(map['dropoff_area']),
      earningsEstimate: JsonParse.toDouble(map['earnings_estimate']),
      currency: _text(map['currency'])?.toUpperCase(),
      paymentMethod: _text(map['payment_method']),
      isCash: JsonParse.toBool(map['is_cash']) ||
          _text(map['payment_method']) == 'cash_on_delivery',
      isGift: JsonParse.toBool(map['is_gift']),
      itemsCount: JsonParse.toInt(map['items_count']) ?? 0,
      waitingForFood: JsonParse.toBool(map['waiting_for_food']),
    );
  }

  /// The FCM data payload has the same keys (flat, all strings).
  static FoodDispatchOffer? fromPushData(
    Map<String, dynamic> data, {
    DateTime? receivedAt,
  }) {
    if (!isOfferPush(data)) return null;
    return fromJson(data, receivedAt: receivedAt);
  }

  static bool isOfferPush(Map<String, dynamic> data) =>
      (data['type'] ?? data['event'])?.toString().trim().toLowerCase() ==
      pushType;

  static const String pushType = 'food_dispatch_offer';

  static DateTime _deadline(Map<String, dynamic> map, DateTime now) {
    final inSeconds = JsonParse.toInt(map['expires_in_seconds']);
    if (inSeconds != null) return now.add(Duration(seconds: inSeconds));
    final at = DateTime.tryParse(map['expires_at']?.toString() ?? '');
    if (at != null) return at.toLocal();
    return now.add(const Duration(seconds: defaultTimeoutSeconds));
  }

  static String? _text(dynamic value) {
    if (value is Map || value is List) return null;
    final s = value?.toString().trim();
    return s == null || s.isEmpty ? null : s;
  }
}

/// `GET /api/driver/dispatch/offers/current` response.
class FoodDispatchPoll {
  const FoodDispatchPoll({
    this.offer,
    this.autoDispatch = false,
    this.pollAfterSeconds = 15,
    this.market,
  });

  final FoodDispatchOffer? offer;

  /// System dispatch is on for the rider's city.
  final bool autoDispatch;

  /// Server hint: 5 s with an offer, 15 s online, 30 s offline, 60 s when off.
  final int pollAfterSeconds;
  final String? market;

  static FoodDispatchPoll fromResponse(dynamic res, {DateTime? receivedAt}) {
    final map = JsonParse.toMap(res) ?? const <String, dynamic>{};
    final poll = JsonParse.toInt(map['poll_after_seconds']) ?? 15;
    return FoodDispatchPoll(
      offer: FoodDispatchOffer.fromJson(map['data'], receivedAt: receivedAt),
      autoDispatch: JsonParse.toBool(map['auto_dispatch']),
      pollAfterSeconds: poll.clamp(3, 120).toInt(),
      market: map['market']?.toString(),
    );
  }
}

/// Why accepting / declining an offer failed.
enum FoodOfferError {
  /// DISPATCH_OFFER_EXPIRED: the 30 s ran out.
  expired,

  /// DISPATCH_OFFER_CLOSED / ORDER_ALREADY_ASSIGNED / ORDER_NO_LONGER_AVAILABLE.
  gone,

  /// DRIVER_CITY_MISMATCH (403): the order is in another city.
  otherCity,

  /// LOW_WALLET_BALANCE: top up the wallet to take cash orders.
  lowBalance,

  /// DRIVER_ACTIVE_JOB_CONFLICT: finish the current job first.
  activeJob,

  /// Anything else (network, server).
  other,
}

class FoodOfferErrors {
  FoodOfferErrors._();

  static FoodOfferError classify(Object error) {
    if (error is! AppException) return FoodOfferError.other;
    switch (_codeOf(error)) {
      case 'DISPATCH_OFFER_EXPIRED':
        return FoodOfferError.expired;
      case 'DISPATCH_OFFER_CLOSED':
      case 'DISPATCH_OFFER_NOT_FOUND':
      case 'ORDER_ALREADY_ASSIGNED':
      case 'ORDER_NO_LONGER_AVAILABLE':
        return FoodOfferError.gone;
      case 'DRIVER_CITY_MISMATCH':
        return FoodOfferError.otherCity;
      case 'LOW_WALLET_BALANCE':
        return FoodOfferError.lowBalance;
      case 'DRIVER_ACTIVE_JOB_CONFLICT':
        return FoodOfferError.activeJob;
      default:
        return FoodOfferError.other;
    }
  }

  /// Translation key under `dispatch_offer.*` for the error.
  static String messageKey(FoodOfferError error) {
    switch (error) {
      case FoodOfferError.expired:
        return 'dispatch_offer.error_expired';
      case FoodOfferError.gone:
        return 'dispatch_offer.error_gone';
      case FoodOfferError.otherCity:
        return 'dispatch_offer.error_other_city';
      case FoodOfferError.lowBalance:
        return 'dispatch_offer.error_low_balance';
      case FoodOfferError.activeJob:
        return 'dispatch_offer.error_active_job';
      case FoodOfferError.other:
        return 'dispatch_offer.error_other';
    }
  }

  static String? _codeOf(AppException error) {
    final details = JsonParse.toMap(error.details);
    final fromBody = details?['code']?.toString();
    if (fromBody != null && fromBody.isNotEmpty) return fromBody;
    return error.code;
  }
}

/// Decides which offers get the full-screen card: each offer once, never
/// one that already expired, never while another offer is on screen.
class FoodOfferTracker {
  final Set<int> _handled = <int>{};
  int? _showingOfferId;

  int? get showingOfferId => _showingOfferId;

  bool shouldShow(FoodDispatchOffer? offer, DateTime now) {
    if (offer == null) return false;
    if (_showingOfferId != null) return false;
    if (_handled.contains(offer.offerId)) return false;
    return !offer.isExpired(now);
  }

  void markShowing(FoodDispatchOffer offer) {
    _showingOfferId = offer.offerId;
    _handled.add(offer.offerId);
  }

  void markClosed(int offerId) {
    if (_showingOfferId == offerId) _showingOfferId = null;
    _handled.add(offerId);
    // Keep memory bounded over a long shift.
    if (_handled.length > 200) {
      _handled.remove(_handled.first);
    }
  }

  void reset() {
    _handled.clear();
    _showingOfferId = null;
  }
}
