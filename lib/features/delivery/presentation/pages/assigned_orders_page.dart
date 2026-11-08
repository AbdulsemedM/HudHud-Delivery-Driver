import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/models/driver_food_order.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/utils/app_currency.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/pages/food_order_detail_page.dart';

/// Food / gift orders assigned to the driver (GET /api/driver/orders/active).
class AssignedOrdersPage extends StatefulWidget {
  const AssignedOrdersPage({super.key, this.initialOrders = const []});

  final List<DriverFoodOrder> initialOrders;

  @override
  State<AssignedOrdersPage> createState() => _AssignedOrdersPageState();
}

class _AssignedOrdersPageState extends State<AssignedOrdersPage> {
  late List<DriverFoodOrder> _orders;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _orders = widget.initialOrders;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = _orders.isEmpty);
    try {
      final orders = await getIt<ApiService>().getActiveFoodOrders();
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _open(DriverFoodOrder order) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => FoodOrderDetailPage(order: order)),
    );
    if (mounted) await _load();
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
          'gift.orders_title'.tr(),
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
          Icon(Icons.inbox_outlined, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            _failed ? 'gift.load_failed'.tr() : 'gift.empty'.tr(),
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
      itemBuilder: (context, index) {
        final order = _orders[index];
        final name = order.contactName ??
            (order.isGift ? 'gift.recipient'.tr() : 'gift.customer'.tr());
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onTap: () => _open(order),
            leading: Icon(
              order.isGift ? Icons.card_giftcard : Icons.delivery_dining,
              color: FoodOrderDetailPage.brandOrange,
            ),
            title: Text(
              order.isGift
                  ? 'gift.deliver_to'.tr(namedArgs: {'name': name})
                  : '${order.displayNumber} · $name',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: order.deliveryAddress == null
                ? null
                : Text(
                    order.deliveryAddress!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
            trailing: order.totalAmount == null
                ? const Icon(Icons.chevron_right)
                : Text(
                    AppCurrency.format(
                      order.totalAmount,
                      currency: order.currency,
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
        );
      },
    );
  }
}
