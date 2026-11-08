import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/models/driver_food_order.dart';
import 'package:hudhud_delivery_driver/core/models/food_dispatch_offer.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/utils/driver_error_messages.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/pages/assigned_orders_page.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/pages/food_order_detail_page.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/widgets/food_offer_card.dart';

typedef AcceptFoodOffer = Future<Map<String, dynamic>> Function(int offerId);
typedef DeclineFoodOffer = Future<Map<String, dynamic>> Function(
  int offerId, {
  String? reason,
});

/// Full-screen system-dispatch offer (Phase 10). Accept → the existing food
/// order flow (start → complete, gift delivery code); Decline / expiry →
/// back, and the system offers the order to the next rider.
///
/// Pops with `true` when accepted, `false` otherwise.
class FoodOfferPage extends StatefulWidget {
  const FoodOfferPage({
    super.key,
    required this.offer,
    this.acceptOffer,
    this.declineOffer,
    this.clock,
  });

  final FoodDispatchOffer offer;

  /// Overridable for tests; default is [ApiService.acceptFoodDispatchOffer].
  final AcceptFoodOffer? acceptOffer;

  /// Overridable for tests; default is [ApiService.declineFoodDispatchOffer].
  final DeclineFoodOffer? declineOffer;
  final DateTime Function()? clock;

  static FoodOfferCardText localizedText() => FoodOfferCardText(
        title: 'dispatch_offer.title'.tr(),
        pickupDistance: 'dispatch_offer.pickup_distance'.tr(),
        dropoff: 'dispatch_offer.dropoff'.tr(),
        earnings: 'dispatch_offer.earnings'.tr(),
        accept: 'dispatch_offer.accept'.tr(),
        decline: 'dispatch_offer.decline'.tr(),
        expired: 'dispatch_offer.expired'.tr(),
        cash: 'dispatch_offer.cash'.tr(),
        gift: 'dispatch_offer.gift'.tr(),
        stillCooking: 'dispatch_offer.still_cooking'.tr(),
        secondsUnit: 'dispatch_offer.seconds'.tr(),
        items: 'dispatch_offer.items'.tr(),
      );

  @override
  State<FoodOfferPage> createState() => _FoodOfferPageState();
}

class _FoodOfferPageState extends State<FoodOfferPage> {
  bool _busy = false;
  bool _closing = false;

  AcceptFoodOffer get _accept =>
      widget.acceptOffer ?? getIt<ApiService>().acceptFoodDispatchOffer;

  DeclineFoodOffer get _decline =>
      widget.declineOffer ?? getIt<ApiService>().declineFoodDispatchOffer;

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : null,
      ),
    );
  }

  Future<void> _closeLater(bool accepted) async {
    if (_closing) return;
    _closing = true;
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (mounted) Navigator.of(context).pop(accepted);
  }

  Future<void> _onAccept() async {
    if (_busy || _closing) return;
    setState(() => _busy = true);
    try {
      final res = await _accept(widget.offer.offerId);
      if (!mounted) return;
      final order = DriverFoodOrder.fromJson(res['order']);
      await _openAccepted(order);
    } catch (e) {
      if (!mounted) return;
      // Lost response: the accept may have gone through. If the order is
      // now ours, continue as accepted instead of showing an error.
      if (DriverErrorMessages.isRetryable(e)) {
        final mine = await _findAssigned(widget.offer.orderId);
        if (!mounted) return;
        if (mine != null) {
          await _openAccepted(mine);
          return;
        }
      }
      await _onAcceptFailed(e);
    }
  }

  Future<DriverFoodOrder?> _findAssigned(int orderId) async {
    if (!getIt.isRegistered<ApiService>()) return null;
    try {
      final active = await getIt<ApiService>().getActiveFoodOrders();
      for (final order in active) {
        if (order.id == orderId) return order;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _openAccepted(DriverFoodOrder? order) async {
    _snack('dispatch_offer.accepted'.tr());
    _closing = true;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<bool>(
        builder: (_) => order != null
            ? FoodOrderDetailPage(order: order)
            : const AssignedOrdersPage(),
      ),
      result: true,
    );
  }

  Future<void> _onAcceptFailed(Object e) async {
    setState(() => _busy = false);
    final kind = FoodOfferErrors.classify(e);
    // Unlisted codes (DRIVER_NOT_ELIGIBLE, timeouts, ...) get their own
    // localized text instead of the generic "check your connection".
    _snack(
      kind == FoodOfferError.other
          ? DriverErrorMessages.message(
              e,
              fallbackKey: FoodOfferErrors.messageKey(kind),
            )
          : FoodOfferErrors.messageKey(kind).tr(),
      error: true,
    );
    // Low balance / active job: the rider may fix it within the window.
    if (kind == FoodOfferError.expired ||
        kind == FoodOfferError.gone ||
        kind == FoodOfferError.otherCity) {
      await _closeLater(false);
    }
  }

  Future<void> _onDecline() async {
    if (_busy || _closing) return;
    setState(() => _busy = true);
    try {
      await _decline(widget.offer.offerId);
    } catch (_) {
      // Declining is best effort: an unanswered offer expires on its own.
    }
    if (!mounted) return;
    _closing = true;
    Navigator.of(context).pop(false);
  }

  void _onExpired() {
    _snack('dispatch_offer.error_expired'.tr());
    _closeLater(false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Back = decline, so the next rider gets the order without waiting.
      canPop: _closing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onDecline();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: FoodOfferCard(
          offer: widget.offer,
          text: FoodOfferPage.localizedText(),
          busy: _busy,
          clock: widget.clock,
          onAccept: _onAccept,
          onDecline: _onDecline,
          onExpired: _onExpired,
        ),
      ),
    );
  }
}
