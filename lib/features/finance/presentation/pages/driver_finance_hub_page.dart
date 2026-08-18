import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hudhud_delivery_driver/core/constants/limit_status.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/models/driver_account_standing.dart';
import 'package:hudhud_delivery_driver/core/models/driver_wallet.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/utils/app_currency.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/pages/delivery_earnings_screen.dart';

class DriverFinanceHubPage extends StatefulWidget {
  const DriverFinanceHubPage({super.key});

  @override
  State<DriverFinanceHubPage> createState() => _DriverFinanceHubPageState();
}

class _DriverFinanceHubPageState extends State<DriverFinanceHubPage> {
  bool _loading = true;
  DriverAccountStanding? _standing;
  DriverWallet? _wallet;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = getIt<ApiService>();
    final results = await Future.wait([
      api.getDriverAccountStanding(),
      api.getDriverWallet(),
    ]);
    if (!mounted) return;
    setState(() {
      _standing = results[0] as DriverAccountStanding?;
      _wallet = results[1] as DriverWallet?;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final standing = _standing;
    final wallet = _wallet;
    final limitStatus = standing?.limitStatus ?? LimitStatus.unknown;
    final showAlert = limitStatus.showWarning || limitStatus.blocksAcceptance;

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
          'My Finances',
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
                  if (showAlert && standing != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: limitStatus.blocksAcceptance
                            ? Colors.red.shade50
                            : Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: limitStatus.blocksAcceptance
                              ? Colors.red.shade200
                              : Colors.amber.shade200,
                        ),
                      ),
                      child: Text(
                        standing.displayStanding,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: limitStatus.blocksAcceptance
                              ? Colors.red.shade900
                              : Colors.amber.shade900,
                        ),
                      ),
                    ),
                  _summaryCard(
                    title: 'Wallet balance',
                    amount: wallet?.balance,
                    currency: wallet?.currency ?? 'ETB',
                    subtitle: 'Stored wallet funds',
                  ),
                  const SizedBox(height: 12),
                  _summaryCard(
                    title: 'Amount owed to HudHud',
                    amount: standing?.displayAmountOwed,
                    currency: standing?.currency ?? 'ETB',
                    subtitle: 'Outstanding platform obligation',
                    highlight: (standing?.displayAmountOwed ?? 0) > 0,
                  ),
                  const SizedBox(height: 24),
                  _tile(
                    icon: Icons.trending_up,
                    title: 'Earnings',
                    subtitle: 'View reported earnings and transactions',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DeliveryEarningsScreen(),
                        ),
                      );
                    },
                  ),
                  _tile(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Wallet',
                    subtitle: 'Balance and transaction history',
                    onTap: () => context.pushNamed(AppRouter.deliveryWallet),
                  ),
                  _tile(
                    icon: Icons.account_balance_outlined,
                    title: 'Account standing',
                    subtitle: standing?.displayStanding ?? 'Limits and debt status',
                    onTap: () =>
                        context.pushNamed(AppRouter.deliveryAccountStanding),
                  ),
                  _tile(
                    icon: Icons.receipt_long_outlined,
                    title: 'Settlements',
                    subtitle: 'Settlement batches and net payable',
                    onTap: () =>
                        context.pushNamed(AppRouter.deliverySettlements),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _summaryCard({
    required String title,
    required double? amount,
    required String currency,
    required String subtitle,
    bool highlight = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
          Text(title, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          const SizedBox(height: 6),
          Text(
            amount != null
                ? AppCurrency.format(amount, currency: currency)
                : '—',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: highlight ? Colors.red.shade800 : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.orange.shade700),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
