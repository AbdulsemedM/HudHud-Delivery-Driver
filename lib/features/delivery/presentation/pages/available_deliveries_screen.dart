import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';

class AvailableDeliveriesScreen extends StatefulWidget {
  const AvailableDeliveriesScreen({Key? key}) : super(key: key);

  @override
  State<AvailableDeliveriesScreen> createState() => _AvailableDeliveriesScreenState();
}

class _AvailableDeliveriesScreenState extends State<AvailableDeliveriesScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _deliveries = [];
  int? _acceptingId;
  int? _decliningId;

  static int? _parseId(Map<String, dynamic> d) {
    final id = d['id'];
    if (id == null) return null;
    if (id is int) return id;
    return int.tryParse(id.toString());
  }

  @override
  void initState() {
    super.initState();
    _loadDeliveries();
  }

  Future<void> _loadDeliveries() async {
    setState(() => _loading = true);
    try {
      final api = getIt<ApiService>();
      final list = await api.getAvailableDeliveryRequests();
      if (!mounted) return;
      setState(() {
        _deliveries = list;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _deliveries = [];
        _loading = false;
      });
    }
  }

  Future<void> _acceptDelivery(int deliveryId) async {
    setState(() => _acceptingId = deliveryId);
    try {
      final api = getIt<ApiService>();
      final res = await api.acceptDeliveryRequest(deliveryId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'Delivery accepted'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _acceptingId = null);
    }
  }

  Future<void> _declineDelivery(int deliveryId) async {
    setState(() => _decliningId = deliveryId);
    try {
      final api = getIt<ApiService>();
      final res = await api.cancelDriverOrder(deliveryId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'Delivery declined'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() => _deliveries.removeWhere((d) => _parseId(d) == deliveryId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _decliningId = null);
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
          'Available Deliveries',
          style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadDeliveries,
        child: _loading
            ? const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : _deliveries.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                      Icon(Icons.local_shipping_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No available deliveries',
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _deliveries.length,
                    itemBuilder: (context, index) {
                      final delivery = _deliveries[index];
                      return _DeliveryCard(
                        delivery: delivery,
                        onAccept: _acceptDelivery,
                        isAccepting: _acceptingId == _parseId(delivery),
                        onDecline: _declineDelivery,
                        isDeclining: _decliningId == _parseId(delivery),
                      );
                    },
                  ),
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({
    required this.delivery,
    required this.onAccept,
    this.isAccepting = false,
    required this.onDecline,
    this.isDeclining = false,
  });

  final Map<String, dynamic> delivery;
  final void Function(int id) onAccept;
  final bool isAccepting;
  final void Function(int id) onDecline;
  final bool isDeclining;

  @override
  Widget build(BuildContext context) {
    final packageType = _capitalize(delivery['package_type']?.toString() ?? 'Package');
    final packageDesc = delivery['package_description']?.toString();
    final pickupLocation = delivery['pickup_location']?.toString() ?? '—';
    final dropoffLocation = delivery['dropoff_location']?.toString() ?? '—';
    final senderName = delivery['sender_name']?.toString() ?? '—';
    final senderPhone = delivery['sender_phone']?.toString();
    final receiverName = delivery['receiver_name']?.toString() ?? '—';
    final receiverPhone = delivery['receiver_phone']?.toString();
    final estimatedCost = delivery['estimated_cost']?.toString() ?? '—';
    final estimatedDistance = delivery['estimated_distance']?.toString();
    final estimatedDuration = delivery['estimated_duration'];
    final serviceType = _capitalize(delivery['service_type']?.toString() ?? '');
    final vehicleType = _capitalize(delivery['vehicle_type']?.toString() ?? '');
    final status = delivery['status']?.toString() ?? 'pending';
    final packageWeight = delivery['package_weight']?.toString();
    final fragile = delivery['fragile'] == true;
    final perishable = delivery['perishable'] == true;
    final requiresSignature = delivery['requires_signature'] == true;
    final specialInstructions = delivery['special_instructions']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: package type + status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(_packageIcon(delivery['package_type']?.toString()), size: 20, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Text(
                      packageType,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _capitalize(status.replaceAll('_', ' ')),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _statusColor(status)),
                  ),
                ),
              ],
            ),

            if (packageDesc != null && packageDesc.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                packageDesc,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 12),

            // Badges row: service type, vehicle, weight, flags
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (serviceType.isNotEmpty) _buildBadge(serviceType, Colors.blue),
                if (vehicleType.isNotEmpty) _buildBadge(vehicleType, Colors.indigo),
                if (packageWeight != null) _buildBadge('${packageWeight}kg', Colors.brown),
                if (fragile) _buildBadge('Fragile', Colors.red),
                if (perishable) _buildBadge('Perishable', Colors.teal),
                if (requiresSignature) _buildBadge('Signature', Colors.purple),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Pickup
            _buildLocationRow(
              icon: Icons.radio_button_checked,
              iconColor: Colors.green.shade600,
              label: 'PICKUP',
              location: pickupLocation,
              personName: senderName,
              phone: senderPhone,
            ),

            Padding(
              padding: const EdgeInsets.only(left: 11),
              child: Container(
                width: 2,
                height: 20,
                color: Colors.grey.shade300,
              ),
            ),

            // Dropoff
            _buildLocationRow(
              icon: Icons.location_on,
              iconColor: Colors.red.shade600,
              label: 'DROPOFF',
              location: dropoffLocation,
              personName: receiverName,
              phone: receiverPhone,
            ),

            if (specialInstructions != null && specialInstructions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.amber.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      specialInstructions,
                      style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Estimate row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (estimatedDistance != null)
                  _buildEstimateTile(Icons.straighten, '${estimatedDistance} km'),
                if (estimatedDuration != null)
                  _buildEstimateTile(Icons.schedule, '$estimatedDuration min'),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Estimated', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    Text(
                      '\$$estimatedCost',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isDeclining
                        ? null
                        : () {
                            final id = delivery['id'];
                            if (id == null) return;
                            final parsedId = id is int ? id : int.tryParse(id.toString());
                            if (parsedId != null) onDecline(parsedId);
                          },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: isDeclining
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: isAccepting
                        ? null
                        : () {
                            final id = delivery['id'];
                            if (id == null) return;
                            final parsedId = id is int ? id : int.tryParse(id.toString());
                            if (parsedId != null) onAccept(parsedId);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: isAccepting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Accept Delivery'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String location,
    required String personName,
    String? phone,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade500, letterSpacing: 1)),
              const SizedBox(height: 2),
              Text(location, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(
                phone != null ? '$personName  ·  $phone' : personName,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEstimateTile(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(value, style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  static IconData _packageIcon(String? packageType) {
    switch (packageType) {
      case 'document':
        return Icons.description_outlined;
      case 'food':
        return Icons.restaurant_outlined;
      case 'fragile':
        return Icons.warning_amber_outlined;
      case 'electronics':
        return Icons.devices_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'assigned':
      case 'accepted':
        return Colors.blue;
      case 'picked_up':
      case 'in_transit':
        return Colors.indigo;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
