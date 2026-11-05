import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';
import 'package:hudhud_delivery_driver/core/utils/json_parse.dart';

/// A food / gift order assigned to the driver, from
/// `GET /api/driver/orders/active` (`DriverController::activeOrders`).
///
/// For a Phase 6 gift order the API runs `GiftOrderService::presentForDriver`:
/// `is_gift: true`, `recipient: {name, phone}`, the recipient replaces the
/// payer in `customer`, the payer's gift message is removed, and
/// `delivery_otp_required` says whether completion needs the recipient's
/// 4-digit code (setting `gifting.require_delivery_otp`).
class DriverFoodOrder {
  const DriverFoodOrder({
    required this.id,
    this.orderNumber,
    this.status,
    this.nextAction,
    this.isGift = false,
    this.contactName,
    this.contactPhone,
    this.vendorName,
    this.pickupAddress,
    this.deliveryAddress,
    this.deliveryNotes,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.totalAmount,
    this.currency,
    this.paymentMethod,
    this.deliveryOtpRequired = false,
  });

  final int id;
  final String? orderNumber;
  final String? status;

  /// `start` or `complete` (server hint; derived from [status] if absent).
  final String? nextAction;
  final bool isGift;

  /// Who the driver calls / texts: the recipient for a gift, else the
  /// customer.
  final String? contactName;
  final String? contactPhone;
  final String? vendorName;
  final String? pickupAddress;
  final String? deliveryAddress;
  final String? deliveryNotes;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final double? totalAmount;

  /// Order currency (`USD` in Hargeisa); null means ETB.
  final String? currency;
  final String? paymentMethod;

  /// True when the API will refuse completion without `delivery_otp`.
  final bool deliveryOtpRequired;

  static const Set<String> _inTransitStatuses = {
    'in_transit',
    'picked_up',
    'on_the_way',
    'in_progress',
  };

  bool get canStart =>
      nextAction == 'start' || (nextAction == null && status == 'accepted');

  bool get canComplete =>
      nextAction == 'complete' ||
      (nextAction == null && _inTransitStatuses.contains(status));

  /// Same order after a lifecycle step (e.g. `in_transit` after start).
  DriverFoodOrder withStatus(String newStatus, {String? newNextAction}) {
    return DriverFoodOrder(
      id: id,
      orderNumber: orderNumber,
      status: newStatus,
      nextAction: newNextAction,
      isGift: isGift,
      contactName: contactName,
      contactPhone: contactPhone,
      vendorName: vendorName,
      pickupAddress: pickupAddress,
      deliveryAddress: deliveryAddress,
      deliveryNotes: deliveryNotes,
      deliveryLatitude: deliveryLatitude,
      deliveryLongitude: deliveryLongitude,
      totalAmount: totalAmount,
      currency: currency,
      paymentMethod: paymentMethod,
      deliveryOtpRequired: deliveryOtpRequired,
    );
  }

  String get displayNumber {
    final number = orderNumber?.trim();
    return number == null || number.isEmpty ? '#$id' : number;
  }

  static DriverFoodOrder? fromJson(dynamic raw) {
    final map = JsonParse.toMap(raw);
    if (map == null) return null;
    final id = JsonParse.toInt(map['id']);
    if (id == null || id <= 0) return null;

    final isGift = JsonParse.toBool(map['is_gift']);
    final recipient = JsonParse.toMap(map['recipient']);
    final customer =
        JsonParse.toMap(map['customer']) ?? JsonParse.toMap(map['user']);
    final contact = isGift && recipient != null ? recipient : customer;
    final vendor = JsonParse.toMap(map['vendor']);

    return DriverFoodOrder(
      id: id,
      orderNumber: _text(map['order_number']),
      status: _text(map['status'])?.toLowerCase(),
      nextAction: _text(map['next_action'])?.toLowerCase(),
      isGift: isGift,
      contactName: _text(contact?['name']),
      contactPhone: _text(contact?['phone']),
      vendorName: _text(vendor?['shop_name']) ??
          _text(vendor?['business_name']) ??
          _text(vendor?['name']),
      pickupAddress: _text(map['pickup_location']),
      deliveryAddress: _text(map['delivery_address']) ??
          _text(map['delivery_location']),
      deliveryNotes: _text(map['delivery_notes']),
      deliveryLatitude: JsonParse.toDouble(map['delivery_latitude']),
      deliveryLongitude: JsonParse.toDouble(map['delivery_longitude']),
      totalAmount: JsonParse.toDouble(map['total_amount']),
      currency: _text(map['currency'])?.toUpperCase(),
      paymentMethod: _text(map['payment_method']),
      deliveryOtpRequired: JsonParse.toBool(map['delivery_otp_required']),
    );
  }

  /// Parses `{success, data: [...]}` (or a bare list). Bad rows are skipped.
  static List<DriverFoodOrder> listFromResponse(dynamic res) {
    final map = JsonParse.toMap(res);
    final raw = map != null ? map['data'] : res;
    if (raw is! List) return const [];
    return raw.map(fromJson).whereType<DriverFoodOrder>().toList();
  }

  static String? _text(dynamic value) {
    if (value is Map || value is List) return null;
    final s = value?.toString().trim();
    return s == null || s.isEmpty ? null : s;
  }
}

/// Why `POST /api/driver/orders/{id}/complete` refused a gift delivery.
enum GiftDeliveryCodeError {
  /// 422 INVALID_DELIVERY_OTP and no code was sent: ask the recipient.
  required,

  /// 422 INVALID_DELIVERY_OTP for a code that was sent: wrong code.
  invalid,

  /// 429 DELIVERY_OTP_LOCKED: 5 wrong codes in 15 minutes.
  locked,
}

class GiftDeliveryCode {
  GiftDeliveryCode._();

  static const int length = 4;
  static const String invalidCode = 'INVALID_DELIVERY_OTP';
  static const String lockedCode = 'DELIVERY_OTP_LOCKED';

  /// Wrong tries allowed by the API before [GiftDeliveryCodeError.locked]
  /// (`RateLimiter::tooManyAttempts(..., 5)`, 15-minute window). The API
  /// does not return a remaining count.
  static const int maxAttempts = 5;

  static final RegExp _fourDigits = RegExp(r'^\d{4}$');

  static bool isWellFormed(String? code) =>
      code != null && _fourDigits.hasMatch(code.trim());

  /// Maps a completion error to a delivery-code state, or null when the
  /// error has nothing to do with the delivery code.
  static GiftDeliveryCodeError? classify(
    Object error, {
    required bool codeWasSent,
  }) {
    if (error is! AppException) return null;
    final code = _codeOf(error);
    if (code == lockedCode) return GiftDeliveryCodeError.locked;
    if (code == invalidCode) {
      return codeWasSent
          ? GiftDeliveryCodeError.invalid
          : GiftDeliveryCodeError.required;
    }
    return null;
  }

  static String? _codeOf(AppException error) {
    final details = JsonParse.toMap(error.details);
    final fromBody = details?['code']?.toString();
    if (fromBody != null && fromBody.isNotEmpty) return fromBody;
    return error.code;
  }
}
