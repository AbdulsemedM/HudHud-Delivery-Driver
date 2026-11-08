import 'package:hudhud_delivery_driver/core/models/driver_food_order.dart';
import 'package:hudhud_delivery_driver/core/models/food_dispatch_offer.dart';
import 'package:hudhud_delivery_driver/core/utils/json_parse.dart';

/// One row of the legacy food list (`GET /api/driver/orders/available`,
/// `DriverController::availableOrders`): a ready order in the rider's city,
/// within the pickup radius, not yet taken.
///
/// - `pickup_otp_required`: the restaurant's 4-digit pickup code is asked
///   at start ("Picked up"), not at accept.
/// - `dispatch_offer`: the order is under system dispatch and offered to
///   this rider; accept through the offer (code checked at start instead).
/// - `cod_acceptance.eligible == false`: cash order the rider cannot take
///   until the wallet is topped up (accept answers LOW_WALLET_BALANCE).
class AvailableFoodOrder {
  const AvailableFoodOrder({
    required this.order,
    this.dispatchOffer,
    this.pickupOtpRequired = false,
    this.codEligible = true,
    this.codMessage,
    this.vendorAddress,
  });

  final DriverFoodOrder order;
  final FoodDispatchOffer? dispatchOffer;
  final bool pickupOtpRequired;
  final bool codEligible;
  final String? codMessage;
  final String? vendorAddress;

  int get id => order.id;

  /// Accept goes through the system-dispatch offer, not the legacy route.
  bool get viaDispatchOffer => dispatchOffer != null;

  static AvailableFoodOrder? fromJson(dynamic raw, {DateTime? receivedAt}) {
    final map = JsonParse.toMap(raw);
    if (map == null) return null;
    final order = DriverFoodOrder.fromJson(map);
    if (order == null) return null;
    final cod = JsonParse.toMap(map['cod_acceptance']);
    final vendor = JsonParse.toMap(map['vendor']);
    final eligible = cod == null
        ? true
        : cod.containsKey('eligible')
            ? JsonParse.toBool(cod['eligible'])
            : JsonParse.toBool(cod['can_accept'], defaultValue: true);
    final message = cod?['message']?.toString().trim();
    final vendorAddress = vendor?['address']?.toString().trim();
    return AvailableFoodOrder(
      order: order,
      dispatchOffer:
          FoodDispatchOffer.fromJson(map['dispatch_offer'], receivedAt: receivedAt),
      pickupOtpRequired: JsonParse.toBool(map['pickup_otp_required']),
      codEligible: eligible,
      codMessage: eligible || message == null || message.isEmpty ? null : message,
      vendorAddress:
          vendorAddress == null || vendorAddress.isEmpty ? null : vendorAddress,
    );
  }

  /// Bare list (the API returns a JSON array) or `{data: [...]}`.
  static List<AvailableFoodOrder> listFromResponse(
    dynamic res, {
    DateTime? receivedAt,
  }) {
    final map = JsonParse.toMap(res);
    final raw = map != null ? map['data'] : res;
    if (raw is! List) return const [];
    final now = receivedAt ?? DateTime.now();
    return raw
        .map((e) => fromJson(e, receivedAt: now))
        .whereType<AvailableFoodOrder>()
        .toList();
  }
}
