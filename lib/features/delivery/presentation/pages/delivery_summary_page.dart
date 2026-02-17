import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/features/ride_service/presentation/pages/rate_customer_page.dart';

class DeliverySummaryPage extends StatefulWidget {
  const DeliverySummaryPage({
    Key? key,
    this.orderId,
    required this.totalAmount,
    required this.currency,
    required this.customerName,
    required this.rideDuration,
    this.baseFare = '12.20',
    this.distanceCharges = '0.00',
    this.minutesCharges = '0.00',
    this.tips = '0.00',
  }) : super(key: key);

  final int? orderId;
  final String totalAmount;
  final String currency;
  final String customerName;
  final String rideDuration;
  final String baseFare;
  final String distanceCharges;
  final String minutesCharges;
  final String tips;

  @override
  State<DeliverySummaryPage> createState() => _DeliverySummaryPageState();
}

class _DeliverySummaryPageState extends State<DeliverySummaryPage> {
  bool _isCompleting = false;

  Future<void> _completeDelivery() async {
    setState(() => _isCompleting = true);
    try {
      if (widget.orderId != null) {
        final api = getIt<ApiService>();
        final res = await api.completeDriverOrder(widget.orderId!);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message']?.toString() ?? 'Delivery completed'), backgroundColor: Colors.green),
        );
      }
      if (!mounted) return;
      final rated = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => RateCustomerPage(
            customerName: widget.customerName,
            ridesCount: 37,
            rating: 5.0,
            yearsWithApp: 2.3,
          ),
        ),
      );
      if (mounted && rated == true) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: const Text(
          'HUDHUD delivery',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Delivery completed',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 4),
              Text(
                'Collect payment from the customer to proceed',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 24),
              Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            widget.customerName,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          Text(
                            '${widget.currency} ${widget.totalAmount}',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange.shade700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '1 delivery in ${widget.rideDuration}',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Bill Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _billRow('Base Fare', '${widget.currency} ${widget.baseFare}'),
                      _billRow('Distance Charges', '${widget.currency} ${widget.distanceCharges}'),
                      _billRow('Minutes Charges', '${widget.currency} ${widget.minutesCharges}'),
                      _billRow('Tips', '${widget.currency} ${widget.tips}'),
                      Divider(height: 24, color: Colors.grey.shade300),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Balance',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          Text(
                            '${widget.currency} ${widget.totalAmount}',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange.shade700),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isCompleting ? null : _completeDelivery,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isCompleting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Complete Delivery'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _billRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87)),
        ],
      ),
    );
  }
}
