import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/models/settlement.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/utils/app_currency.dart';

class SettlementPage extends StatefulWidget {
  const SettlementPage({super.key});

  @override
  State<SettlementPage> createState() => _SettlementPageState();
}

class _SettlementPageState extends State<SettlementPage> {
  bool _loading = true;
  SettlementSummary? _summary;
  List<SettlementBatch> _batches = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = getIt<ApiService>();
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1);
    final summary = await api.getSettlementSummary(from: from, to: now);
    final result = await api.getSettlements();
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _batches = result.batches;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
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
          'Settlements',
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
                  if (summary != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Net payable',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            summary.netPayable != null
                                ? AppCurrency.format(
                                    summary.netPayable,
                                    currency: summary.currency,
                                  )
                                : '—',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if ((summary.amountDriverOwesPlatform ?? 0) > 0) ...[
                            const SizedBox(height: 10),
                            Text(
                              'You owe: ${AppCurrency.format(summary.amountDriverOwesPlatform, currency: summary.currency)}',
                              style: TextStyle(
                                color: Colors.red.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          _breakdownRow(
                            'Gross delivery revenue',
                            summary.grossDeliveryRevenue,
                            summary.currency,
                          ),
                          _breakdownRow(
                            'Platform commission',
                            summary.platformCommission,
                            summary.currency,
                          ),
                          _breakdownRow(
                            'Adjustments',
                            summary.refundAdjustments,
                            summary.currency,
                          ),
                          _breakdownRow(
                            'Withdrawals',
                            summary.withdrawals,
                            summary.currency,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  Text(
                    'SETTLEMENT HISTORY',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_batches.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('No settlements yet')),
                    )
                  else
                    ..._batches.map((batch) => _batchTile(batch)),
                ],
              ),
      ),
    );
  }

  Widget _breakdownRow(String label, double? amount, String currency) {
    if (amount == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(
            AppCurrency.format(amount, currency: currency),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _batchTile(SettlementBatch batch) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(batch.id),
        subtitle: Text(
          [
            if (batch.periodFrom != null && batch.periodTo != null)
              '${batch.periodFrom} – ${batch.periodTo}',
            if (batch.status != null) batch.status,
          ].join(' · '),
        ),
        trailing: Text(
          batch.netAmount != null
              ? AppCurrency.format(batch.netAmount, currency: batch.currency)
              : '—',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        onTap: () => context.pushNamed(
          AppRouter.deliverySettlementDetail,
          pathParameters: {'id': batch.id},
        ),
      ),
    );
  }
}
