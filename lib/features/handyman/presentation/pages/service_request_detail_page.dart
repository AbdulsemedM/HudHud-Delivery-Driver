import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/theme/auth_colors.dart';

class ServiceRequestDetailPage extends StatefulWidget {
  const ServiceRequestDetailPage({
    super.key,
    required this.request,
  });

  final Map<String, dynamic> request;

  @override
  State<ServiceRequestDetailPage> createState() =>
      _ServiceRequestDetailPageState();
}

class _ServiceRequestDetailPageState extends State<ServiceRequestDetailPage> {
  late Map<String, dynamic> _request;
  bool _loading = false;

  static int? _requestId(Map<String, dynamic> r) {
    final id = r['id'];
    if (id == null) return null;
    if (id is int) return id;
    return int.tryParse(id.toString());
  }

  @override
  void initState() {
    super.initState();
    _request = Map<String, dynamic>.from(widget.request);
  }

  Future<void> _accept() async {
    final id = _requestId(_request);
    if (id == null) return;
    setState(() => _loading = true);
    try {
      final api = getIt<ApiService>();
      await api.acceptHandymanServiceRequest(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request accepted'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        _request['status'] = 'accepted';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _loading = false);
    }
  }

  Future<void> _startService() async {
    final id = _requestId(_request);
    if (id == null) return;
    setState(() => _loading = true);
    try {
      final api = getIt<ApiService>();
      await api.startHandymanServiceRequest(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Service started'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        _request['status'] = 'in_progress';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _loading = false);
    }
  }

  Future<void> _complete() async {
    final id = _requestId(_request);
    if (id == null) return;
    setState(() => _loading = true);
    try {
      final api = getIt<ApiService>();
      await api.completeHandymanServiceRequest(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Service completed'),
          backgroundColor: Colors.green,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _loading = false);
    }
  }

  Future<void> _cancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel request'),
        content: const Text(
            'Are you sure you want to cancel this service request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final id = _requestId(_request);
    if (id == null) return;
    setState(() => _loading = true);
    try {
      final api = getIt<ApiService>();
      await api.cancelHandymanServiceRequest(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request cancelled'),
          backgroundColor: Colors.green,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _request['status']?.toString().toLowerCase() ?? '';
    final serviceType = _request['service_type']?.toString() ?? 'Service';
    final clientName = _request['client_name']?.toString() ??
        _request['customer']?['name']?.toString() ??
        '—';
    final address = _request['address']?.toString() ??
        _request['location']?.toString() ??
        '—';
    final description = _request['description']?.toString() ?? '';
    final requiredSkills = _request['required_skills'];
    final skillsList = requiredSkills is List
        ? requiredSkills.map((e) => e.toString()).toList()
        : <String>[];
    final estimatedDuration = _request['estimated_duration']?.toString() ?? '—';
    final estimatedPay = _request['estimated_pay']?.toString() ??
        _request['amount']?.toString() ??
        '—';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Service request',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    serviceType.isNotEmpty
                        ? '${serviceType[0].toUpperCase()}${serviceType.substring(1)}'
                        : 'Service',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AuthColors.title,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _detailRow(Icons.person_outline, 'Client', clientName),
                  _detailRow(Icons.location_on_outlined, 'Location', address),
                  if (description.isNotEmpty)
                    _detailRow(
                        Icons.description_outlined, 'Description', description),
                  if (skillsList.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Required skills',
                      style: TextStyle(
                        fontSize: 12,
                        color: AuthColors.hint,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: skillsList.map((s) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AuthColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            s,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AuthColors.primary,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _detailRow(Icons.schedule, 'Est. duration', estimatedDuration),
                  _detailRow(Icons.payments_outlined, 'Est. pay',
                      estimatedPay.startsWith(r'$') ? estimatedPay : '\$$estimatedPay'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_buildActions(status).isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _buildActions(status),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AuthColors.hint),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AuthColors.hint,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AuthColors.title,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActions(String status) {
    final list = <Widget>[];
    if (_loading) {
      list.add(const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ));
      return list;
    }
    if (status == 'pending' || status == 'available') {
      list.add(ElevatedButton(
        onPressed: _accept,
        style: ElevatedButton.styleFrom(
          backgroundColor: AuthColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: const Text('Accept'),
      ));
      list.add(const SizedBox(height: 12));
      list.add(OutlinedButton(
        onPressed: _cancel,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text('Decline'),
      ));
    } else if (status == 'accepted') {
      list.add(ElevatedButton(
        onPressed: _startService,
        style: ElevatedButton.styleFrom(
          backgroundColor: AuthColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: const Text('Start service'),
      ));
      list.add(const SizedBox(height: 12));
      list.add(OutlinedButton(
        onPressed: _cancel,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text('Cancel'),
      ));
    } else if (status == 'in_progress') {
      list.add(ElevatedButton(
        onPressed: _complete,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: const Text('Complete'),
      ));
    }
    return list;
  }
}
