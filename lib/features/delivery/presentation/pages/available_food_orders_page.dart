import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/core/auth/application_status_gate.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/models/available_food_order.dart';
import 'package:hudhud_delivery_driver/core/models/driver_food_order.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/utils/app_currency.dart';
import 'package:hudhud_delivery_driver/core/utils/driver_error_messages.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/active_job_conflict.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/pages/food_offer_page.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/pages/food_order_detail_page.dart';

/// Legacy food list (`GET /api/driver/orders/available`): ready orders in the
/// rider's city when system dispatch is off for that city (or as a fallback
/// view of the offer this rider holds). Accept →
/// `POST /api/driver/orders/{id}/accept` (the response carries `order`) →
/// the same start / complete screen as a dispatched order, where the
/// restaurant's pickup code is asked at "Picked up".
class AvailableFoodOrdersPage extends StatefulWidget {
  const AvailableFoodOrdersPage({super.key});

  /// Errors after which the row should leave the list (taken, cancelled,
  /// controlled by system dispatch, other city).
  static bool removesRow(Object error) {
    final code = DriverErrorMessages.codeOf(error);
    const codes = {
      DriverErrorMessages.dispatchOfferRequired,
      DriverErrorMessages.cityMismatch,
      'ORDER_ALREADY_ASSIGNED',
      'ORDER_NO_LONGER_AVAILABLE',
      'DISPATCH_OFFER_CLOSED',
      'DISPATCH_OFFER_EXPIRED',
    };
    if (codes.contains(code)) return true;
    if (error is GoneException) return true;
    if (error is ConflictException) {
      return !error.isActiveJobConflict && error.isNoLongerAvailable;
    }
    return false;
  }

  @override
  State<AvailableFoodOrdersPage> createState() =>
      _AvailableFoodOrdersPageState();
}

class _AvailableFoodOrdersPageState extends State<AvailableFoodOrdersPage> {
  List<AvailableFoodOrder> _orders = const [];
  bool _loading = true;
  String? _error;
  int? _acceptingId;

  ApiService get _api => getIt<ApiService>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : null,
      ),
    );
  }

  Future<void> _load() async {
    setState(() => _loading = _orders.isEmpty);
    try {
      final orders = await _api.getAvailableFoodOrders();
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (await ApplicationStatusGate.handleForbidden(context, e)) return;
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = DriverErrorMessages.message(
          e,
          fallbackKey: 'food_orders.load_failed',
        );
      });
    }
  }

  /// After a lost response the accept may still have gone through: look the
  /// order up among the rider's active orders.
  Future<DriverFoodOrder?> _findMine(int orderId) async {
    try {
      final active = await _api.getActiveFoodOrders();
      for (final order in active) {
        if (order.id == orderId) return order;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _openAccepted(
    AvailableFoodOrder row, {
    DriverFoodOrder? fromResponse,
  }) async {
    final mine = fromResponse ??
        await _findMine(row.id) ??
        row.order.withStatus('accepted', newNextAction: 'start');
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<bool>(
        builder: (_) => FoodOrderDetailPage(order: mine),
      ),
      result: true,
    );
  }

  Future<void> _accept(AvailableFoodOrder row) async {
    if (_acceptingId != null) return;
    final offer = row.dispatchOffer;
    if (offer != null) {
      // System dispatch: the full-screen offer (accept / decline + timer).
      final accepted = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          fullscreenDialog: true,
          builder: (_) => FoodOfferPage(offer: offer),
        ),
      );
      // Accepted: the offer page replaced itself with the order screen
      // (on top of this list), so only refresh the list underneath.
      if (!mounted) return;
      if (accepted != true) await _load();
      return;
    }
    if (!row.codEligible) {
      _snack(row.codMessage ?? 'dispatch_offer.error_low_balance'.tr(),
          error: true);
      return;
    }
    setState(() => _acceptingId = row.id);
    try {
      final res = await _api.acceptFoodOrder(row.id);
      if (!mounted) return;
      _snack('dispatch_offer.accepted'.tr());
      await _openAccepted(
        row,
        fromResponse: DriverFoodOrder.fromJson(res['order']),
      );
    } catch (e) {
      if (!mounted) return;
      if (await ApplicationStatusGate.handleForbidden(context, e)) return;
      if (!mounted) return;
      if (e is ConflictException && e.isActiveJobConflict) {
        await ActiveJobConflict.show(context, e.activeJob);
        return;
      }
      if (DriverErrorMessages.isRetryable(e)) {
        final mine = await _findMine(row.id);
        if (!mounted) return;
        if (mine != null) {
          _snack('dispatch_offer.accepted'.tr());
          await _openAccepted(row);
          return;
        }
      }
      _snack(DriverErrorMessages.message(e), error: true);
      if (AvailableFoodOrdersPage.removesRow(e)) {
        setState(() => _orders = _orders.where((o) => o.id != row.id).toList());
      }
    } finally {
      if (mounted) setState(() => _acceptingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: Text(
          'food_orders.title'.tr(),
          style: const TextStyle(color: Colors.black, fontSize: 18),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 160),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _buildList(),
      ),
    );
  }

  Widget _buildList() {
    if (_orders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Icon(Icons.restaurant_outlined, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            _error ?? 'food_orders.empty'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _orders.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _buildRow(_orders[index]),
    );
  }

  Widget _buildRow(AvailableFoodOrder row) {
    final order = row.order;
    final busy = _acceptingId == row.id;
    final badges = <String>[
      if (order.isGift) 'dispatch_offer.gift'.tr(),
      if (order.paymentMethod == 'cash_on_delivery') 'dispatch_offer.cash'.tr(),
      if (row.viaDispatchOffer) 'food_orders.via_offer'.tr(),
    ];
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  order.isGift ? Icons.card_giftcard : Icons.restaurant,
                  color: FoodOrderDetailPage.brandOrange,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    order.vendorName ?? order.displayNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (order.totalAmount != null)
                  Text(
                    AppCurrency.format(
                      order.totalAmount,
                      currency: order.currency,
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
              ],
            ),
            if ((order.pickupAddress ?? row.vendorAddress) != null) ...[
              const SizedBox(height: 6),
              Text(
                '${'gift.pickup'.tr()}: ${order.pickupAddress ?? row.vendorAddress}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (order.deliveryAddress != null) ...[
              const SizedBox(height: 2),
              Text(
                '${'gift.dropoff'.tr()}: ${order.deliveryAddress}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
            if (badges.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final b in badges)
                    Chip(
                      label: Text(b, style: const TextStyle(fontSize: 12)),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
            if (!row.codEligible) ...[
              const SizedBox(height: 8),
              Text(
                row.codMessage ?? 'dispatch_offer.error_low_balance'.tr(),
                style: TextStyle(color: Colors.red.shade700, fontSize: 13),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: busy || !row.codEligible ? null : () => _accept(row),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FoodOrderDetailPage.brandOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text('dispatch_offer.accept'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
