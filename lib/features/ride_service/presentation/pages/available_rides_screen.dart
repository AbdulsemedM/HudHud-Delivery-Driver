import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/core/auth/application_status_gate.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/models/active_job.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/services/notification_service.dart';
import 'package:hudhud_delivery_driver/core/utils/app_currency.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/active_job_conflict.dart';

class AvailableRidesScreen extends StatefulWidget {
  const AvailableRidesScreen({Key? key}) : super(key: key);

  @override
  State<AvailableRidesScreen> createState() => _AvailableRidesScreenState();
}

class _AvailableRidesScreenState extends State<AvailableRidesScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _orders = [];
  int? _acceptingOrderId;
  int? _cancellingOrderId;
  ActiveJob? _activeJob;

  static int? _orderId(Map<String, dynamic> order) {
    final id = order['id'];
    if (id == null) return null;
    if (id is int) return id;
    return int.tryParse(id.toString());
  }

  @override
  void initState() {
    super.initState();
    _loadOrders();
    getIt<NotificationService>().homeRefreshTick.addListener(_onPushRefresh);
  }

  @override
  void dispose() {
    getIt<NotificationService>().homeRefreshTick.removeListener(_onPushRefresh);
    super.dispose();
  }

  void _onPushRefresh() {
    _loadOrders();
  }

  Future<void> _cancelOrder(int orderId) async {
    setState(() => _cancellingOrderId = orderId);
    try {
      final api = getIt<ApiService>();
      final res = await api.cancelDriverOrder(orderId);
      if (!mounted) return;
      final message = res['message']?.toString() ?? 'Delivery cancelled successfully';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
      setState(() {
        _orders.removeWhere((o) => _orderId(o) == orderId);
      });
    } catch (e) {
      if (!mounted) return;
      final message = e is AppException
          ? e.message
          : e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _cancellingOrderId = null);
    }
  }

  Future<void> _acceptOrder(int orderId) async {
    if (_activeJob != null) {
      await ActiveJobConflict.show(context, _activeJob);
      return;
    }
    setState(() => _acceptingOrderId = orderId);
    try {
      final api = getIt<ApiService>();
      final res = await api.acceptDriverOrder(orderId);
      if (!mounted) return;
      final message = res['message']?.toString() ?? 'Order accepted successfully';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } on ConflictException catch (e) {
      if (!mounted) return;
      if (e.isActiveJobConflict) {
        setState(() => _activeJob = e.activeJob ?? _activeJob);
        await ActiveJobConflict.show(context, e.activeJob ?? _activeJob);
        if (mounted) await _loadOrders();
        return;
      }
      setState(() {
        _orders.removeWhere((o) => _orderId(o) == orderId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      await _loadOrders();
    } catch (e) {
      if (await ApplicationStatusGate.handleForbidden(context, e)) return;
      if (!mounted) return;
      final message = e is AppException
          ? e.message
          : e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _acceptingOrderId = null);
    }
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    try {
      final api = getIt<ApiService>();
      final results = await Future.wait([
        api.getDriverAvailableOrders(),
        api.getDriverProfile(),
      ]);
      if (!mounted) return;
      setState(() {
        _orders = List<Map<String, dynamic>>.from(results[0] as List);
        _activeJob = ActiveJob.fromDriverProfile(results[1]);
        _loading = false;
      });
    } catch (e) {
      if (await ApplicationStatusGate.handleForbidden(context, e)) return;
      if (mounted) setState(() {
        _orders = [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Available rides',
          style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadOrders,
        child: _loading
            ? const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_activeJob != null)
                        ActiveJobConflict.banner(
                          job: _activeJob,
                          onView: () => ActiveJobConflict.openCurrentJob(
                            context,
                            _activeJob!,
                          ),
                        ),
                      if (_orders.isEmpty) ...[
                        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                        Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No available orders',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ] else
                        ..._orders.map((order) {
                          return _OrderCard(
                            order: order,
                            onAccept: _acceptOrder,
                            isAccepting: _acceptingOrderId == _orderId(order),
                            onDecline: _cancelOrder,
                            isCancelling: _cancellingOrderId == _orderId(order),
                            acceptBlocked: _activeJob != null,
                          );
                        }),
                    ],
                  ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.onAccept,
    this.isAccepting = false,
    required this.onDecline,
    this.isCancelling = false,
    this.acceptBlocked = false,
  });

  final Map<String, dynamic> order;
  final void Function(int orderId) onAccept;
  final bool isAccepting;
  final void Function(int orderId) onDecline;
  final bool isCancelling;
  final bool acceptBlocked;

  @override
  Widget build(BuildContext context) {
    final orderNumber = order['order_number']?.toString() ?? '—';
    final totalAmount = order['total_amount']?.toString() ?? '—';
    final status = order['status']?.toString() ?? '—';
    final deliveryAddress = order['delivery_address']?.toString() ?? '—';
    final deliveryFee = order['delivery_fee']?.toString() ?? '—';
    final vendor = order['vendor'];
    final vendorName = vendor is Map<String, dynamic>
        ? (vendor['name']?.toString() ?? '—')
        : '—';
    final items = order['items'];
    final itemCount = items is List ? items.length : 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  orderNumber,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.replaceAll('_', ' '),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _statusColor(status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.store, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    vendorName,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    deliveryAddress,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (itemCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                '$itemCount item${itemCount == 1 ? '' : 's'}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delivery fee',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    Text(
                      AppCurrency.format(deliveryFee),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Total',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    Text(
                      AppCurrency.format(totalAmount),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isCancelling
                        ? null
                        : () {
                            final id = order['id'];
                            if (id == null) return;
                            final orderId = id is int ? id : int.tryParse(id.toString());
                            if (orderId != null) onDecline(orderId);
                          },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: isCancelling
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: isAccepting || acceptBlocked
                        ? null
                        : () {
                            final id = order['id'];
                            if (id == null) return;
                            final orderId = id is int ? id : int.tryParse(id.toString());
                            if (orderId != null) onAccept(orderId);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: isAccepting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Accept order'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'ready_for_pickup':
        return Colors.orange;
      case 'preparing':
        return Colors.blue;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
