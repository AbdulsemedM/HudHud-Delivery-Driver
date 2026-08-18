import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/models/settlement.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/utils/app_currency.dart';

class SettlementDetailPage extends StatefulWidget {
  const SettlementDetailPage({super.key, required this.settlementId});

  final String settlementId;

  @override
  State<SettlementDetailPage> createState() => _SettlementDetailPageState();
}

class _SettlementDetailPageState extends State<SettlementDetailPage> {
  bool _loading = true;
  SettlementBatch? _batch;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final batch =
        await getIt<ApiService>().getSettlementDetail(widget.settlementId);
    if (!mounted) return;
    setState(() {
      _batch = batch;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final batch = _batch;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          batch?.id ?? 'Settlement',
          style: const TextStyle(color: Colors.black, fontSize: 18),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : batch == null
              ? const Center(child: Text('Settlement not found'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _card([
                      _row('Status', batch.status ?? '—'),
                      _row(
                        'Net amount',
                        batch.netAmount != null
                            ? AppCurrency.format(
                                batch.netAmount,
                                currency: batch.currency,
                              )
                            : '—',
                      ),
                      _row(
                        'Gross earnings',
                        batch.grossEarnings != null
                            ? AppCurrency.format(
                                batch.grossEarnings,
                                currency: batch.currency,
                              )
                            : '—',
                      ),
                      _row(
                        'Commission',
                        batch.commission != null
                            ? AppCurrency.format(
                                batch.commission,
                                currency: batch.currency,
                              )
                            : '—',
                      ),
                      _row(
                        'Adjustments',
                        batch.adjustments != null
                            ? AppCurrency.format(
                                batch.adjustments,
                                currency: batch.currency,
                              )
                            : '—',
                      ),
                      if (batch.periodFrom != null)
                        _row('Period from', batch.periodFrom!),
                      if (batch.periodTo != null)
                        _row('Period to', batch.periodTo!),
                      if (batch.createdAt != null)
                        _row(
                          'Created',
                          batch.createdAt!.toLocal().toString().split('.').first,
                        ),
                      if (batch.paidAt != null)
                        _row(
                          'Paid',
                          batch.paidAt!.toLocal().toString().split('.').first,
                        ),
                    ]),
                  ],
                ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: children),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
