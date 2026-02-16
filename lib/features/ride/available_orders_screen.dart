import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';

class AvailableOrdersScreen extends StatefulWidget {
  const AvailableOrdersScreen({Key? key}) : super(key: key);

  @override
  State<AvailableOrdersScreen> createState() => _AvailableOrdersScreenState();
}

class _AvailableOrdersScreenState extends State<AvailableOrdersScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    try {
      final api = getIt<ApiService>();
      final list = await api.getDriverAvailableOrders();
      if (!mounted) return;
      setState(() {
        _orders = list;
        _loading = false;
      });
    } catch (_) {
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
          'Available orders',
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
            : _orders.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.25),
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
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _orders.length,
                    itemBuilder: (context, index) {
                      final order = _orders[index];
                      return _OrderCard(order: order);
                    },
                  ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final Map<String, dynamic> order;

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
                      '$deliveryFee',
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
                      totalAmount,
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
                    onPressed: () {
                      // TODO: decline order API
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Decline not implemented yet')),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: accept order API
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Accept not implemented yet')),
                      );
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
                    child: const Text('Accept order'),
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
