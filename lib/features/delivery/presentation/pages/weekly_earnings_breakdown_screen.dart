import 'package:flutter/material.dart';

class WeeklyEarningsBreakdownScreen extends StatefulWidget {
  const WeeklyEarningsBreakdownScreen({Key? key}) : super(key: key);

  @override
  State<WeeklyEarningsBreakdownScreen> createState() => _WeeklyEarningsBreakdownScreenState();
}

class _WeeklyEarningsBreakdownScreenState extends State<WeeklyEarningsBreakdownScreen> {
  String selectedDateRange = '21 MAR - 28 MAR';

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
          'Go Back',
          style: TextStyle(color: Colors.black, fontSize: 16),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Earning_Weekly_Breakdown',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 16),
              const Text(
                'Weekly Earnings Breakdown',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.arrow_back_ios, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        Text(
                          selectedDateRange,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.arrow_forward_ios, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'ETB 40,206.20',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.access_time, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          '13 deliveries in 12hours 24mins',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatColumn('12 hr 11 min', 'Online time'),
                        Container(height: 40, width: 1, color: Colors.grey.shade300),
                        _buildStatColumn('13', 'Deliveries'),
                        Container(height: 40, width: 1, color: Colors.grey.shade300),
                        _buildStatColumn('7 hr 24 mins', 'Booked time'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildEarningsRow('Earnings', 'ETB 40,206.20', isHeader: true),
                    const SizedBox(height: 16),
                    _buildEarningsRow('Delivery Earnings', 'ETB 40,206.20'),
                    const SizedBox(height: 16),
                    _buildEarningsRow('Tips', 'ETB 40,206.20'),
                    const SizedBox(height: 16),
                    _buildEarningsRow('Bonuses', 'ETB 40,206.20'),
                    const SizedBox(height: 16),
                    _buildEarningsRow('Deductions', 'ETB 0.00'),
                  ],
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildEarningsRow(String label, String amount, {bool isHeader = false}) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                color: isHeader ? Colors.black : Colors.grey.shade700,
              ),
            ),
            Text(
              amount,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isHeader ? FontWeight.bold : FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ],
        ),
        if (!isHeader) ...[
          const SizedBox(height: 8),
          Divider(color: Colors.grey.shade200, thickness: 1),
        ],
      ],
    );
  }
}
