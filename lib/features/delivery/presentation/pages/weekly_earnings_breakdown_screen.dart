import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/models/driver_earnings_summary.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/utils/app_currency.dart';

class WeeklyEarningsBreakdownScreen extends StatefulWidget {
  const WeeklyEarningsBreakdownScreen({super.key});

  @override
  State<WeeklyEarningsBreakdownScreen> createState() =>
      _WeeklyEarningsBreakdownScreenState();
}

class _WeeklyEarningsBreakdownScreenState
    extends State<WeeklyEarningsBreakdownScreen> {
  bool _loading = true;
  DateTime _weekStart = _mondayOf(DateTime.now());
  WeeklyEarningsSummary? _summary;

  static DateTime _mondayOf(DateTime date) {
    final weekday = date.weekday;
    return DateTime(date.year, date.month, date.day - (weekday - 1));
  }

  String get _dateRangeLabel {
    final end = _weekStart.add(const Duration(days: 6));
    return '${_formatShort(_weekStart)} - ${_formatShort(end)}';
  }

  String _formatShort(DateTime d) {
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final summary = await getIt<ApiService>().getWeeklyEarningsSummary(
      weekStart: _weekStart,
    );
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _loading = false;
    });
  }

  void _shiftWeek(int delta) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: 7 * delta));
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final currency = summary?.currency ?? 'ETB';
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
          'Weekly Breakdown',
          style: TextStyle(color: Colors.black, fontSize: 18),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: () => _shiftWeek(-1),
                              icon: const Icon(Icons.arrow_back_ios, size: 20),
                            ),
                            Text(
                              _dateRangeLabel,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            IconButton(
                              onPressed: () => _shiftWeek(1),
                              icon: const Icon(Icons.arrow_forward_ios, size: 20),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          summary?.totalEarnings != null
                              ? AppCurrency.format(
                                  summary!.totalEarnings,
                                  currency: currency,
                                )
                              : '—',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _stat(
                              '${summary?.deliveryCount ?? 0}',
                              'Deliveries',
                            ),
                            _stat(
                              '${summary?.rideCount ?? 0}',
                              'Rides',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _row(
                          'Delivery earnings',
                          summary?.deliveriesEarnings,
                          currency,
                        ),
                        _row(
                          'Ride earnings',
                          summary?.ridesEarnings,
                          currency,
                        ),
                        if (summary?.platformCommission != null)
                          _row(
                            'Platform commission',
                            summary!.platformCommission,
                            currency,
                          ),
                        if (summary?.netEarnings != null)
                          _row(
                            'Net earnings',
                            summary!.netEarnings,
                            currency,
                            bold: true,
                          ),
                      ],
                    ),
                  ),
                  if (summary?.dailyBreakdown.isNotEmpty == true) ...[
                    const SizedBox(height: 16),
                    Text(
                      'DAILY BREAKDOWN',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...summary!.dailyBreakdown.map(
                      (day) => Card(
                        child: ListTile(
                          title: Text(
                            day.date?.toLocal().toString().split(' ').first ??
                                '—',
                          ),
                          subtitle: Text(
                            '${day.deliveryCount ?? 0} deliveries',
                          ),
                          trailing: Text(
                            AppCurrency.format(day.earnings, currency: currency),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _row(
    String label,
    double? amount,
    String currency, {
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            amount != null
                ? AppCurrency.format(amount, currency: currency)
                : '—',
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
