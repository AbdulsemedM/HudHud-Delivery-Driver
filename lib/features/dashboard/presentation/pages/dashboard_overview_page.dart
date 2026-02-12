import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/core/constants/user_type_constants.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';

class DashboardOverviewPage extends StatefulWidget {
  const DashboardOverviewPage({super.key, required this.onNavigateToTab});

  final void Function(int index) onNavigateToTab;

  @override
  State<DashboardOverviewPage> createState() => _DashboardOverviewPageState();
}

class _DashboardOverviewPageState extends State<DashboardOverviewPage> {
  int _driversCount = 0;
  int _couriersCount = 0;
  int _handymenCount = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = getIt<ApiService>();
      final drivers = await api.listUsersByType(UserTypeConstants.driver);
      final couriers = await api.listUsersByType(UserTypeConstants.courier);
      final handymen = await api.listUsersByType(UserTypeConstants.handyman);
      if (mounted) {
        setState(() {
          _driversCount = drivers.length;
          _couriersCount = couriers.length;
          _handymenCount = handymen.length;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadCounts,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadCounts,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Overview',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _SummaryCard(
                                title: 'Drivers',
                                count: _driversCount,
                                icon: Icons.directions_car,
                                color: Colors.blue,
                                onTap: () => widget.onNavigateToTab(1),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _SummaryCard(
                                title: 'Couriers',
                                count: _couriersCount,
                                icon: Icons.local_shipping,
                                color: Colors.orange,
                                onTap: () => widget.onNavigateToTab(2),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _SummaryCard(
                          title: 'Handymen',
                          count: _handymenCount,
                          icon: Icons.build,
                          color: Colors.green,
                          onTap: () => widget.onNavigateToTab(3),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
