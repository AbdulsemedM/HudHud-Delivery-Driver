import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/models/driver_earnings_summary.dart';
import 'package:hudhud_delivery_driver/core/models/driver_wallet.dart';
import 'package:hudhud_delivery_driver/core/notifications/notification_navigation_extra.dart';
import 'package:hudhud_delivery_driver/core/notifications/wallet_notification_banner.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/utils/app_currency.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/pages/weekly_earnings_breakdown_screen.dart';

class DeliveryEarningsScreen extends StatefulWidget {
  const DeliveryEarningsScreen({super.key, this.navigationExtra});

  final NotificationNavigationExtra? navigationExtra;

  @override
  State<DeliveryEarningsScreen> createState() => _DeliveryEarningsScreenState();
}

class _DeliveryEarningsScreenState extends State<DeliveryEarningsScreen> {
  bool _loading = true;
  DriverEarningsSummary? _summary;
  DriverWallet? _wallet;
  List<dynamic> _transactions = [];
  String _currency = 'ETB';

  @override
  void initState() {
    super.initState();
    _loadEarnings();
  }

  Future<void> _loadEarnings() async {
    setState(() => _loading = true);
    try {
      final api = getIt<ApiService>();
      final stats = await api.getDriverEarningsStats();
      DriverEarningsSummary? summary = stats;
      List<dynamic> transactions = [];

      if (summary == null) {
        final legacy = await api.getDriverEarnings();
        if (legacy != null) {
          summary = DriverEarningsSummary.fromLegacyJson(legacy);
          final tx = legacy['transactions'];
          transactions = tx is List ? List<dynamic>.from(tx) : [];
        }
      } else {
        final legacy = await api.getDriverEarnings();
        final tx = legacy?['transactions'];
        transactions = tx is List ? List<dynamic>.from(tx) : [];
      }

      final wallet = await api.getDriverWallet();

      if (!mounted) return;
      setState(() {
        _summary = summary;
        _wallet = wallet;
        _transactions = transactions;
        _currency = summary?.currency ?? wallet?.currency ?? 'ETB';
      });
    } catch (_) {
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cashOut() async {
    final balance = _wallet?.balance;
    if (balance == null || balance <= 0) return;

    final amountController =
        TextEditingController(text: balance.toStringAsFixed(2));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cash out'),
        content: TextField(
          controller: amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Amount ($_currency)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final amount = double.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0) return;

    try {
      final res =
          await getIt<ApiService>().postWalletWithdraw(amount: amount);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res['message']?.toString() ?? 'Withdrawal request submitted',
          ),
          backgroundColor: Colors.green,
        ),
      );
      await _loadEarnings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is AppException
                ? e.message
                : e.toString().replaceFirst('Exception: ', ''),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final wallet = _wallet;
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
          'My Earnings',
          style: TextStyle(color: Colors.black, fontSize: 18),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadEarnings,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.navigationExtra?.bannerMessage != null)
                      WalletNotificationBanner(
                        message: widget.navigationExtra!.bannerMessage!,
                      ),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _amountRow(
                            'Reported earnings',
                            summary?.totalEarnings,
                          ),
                          const SizedBox(height: 12),
                          _amountRow(
                            'Weekly earnings',
                            summary?.weeklyEarnings,
                          ),
                          if (summary?.netDriverEarnings != null) ...[
                            const SizedBox(height: 12),
                            _amountRow(
                              'Net earnings',
                              summary!.netDriverEarnings,
                            ),
                          ],
                          if (summary?.platformCommission != null) ...[
                            const SizedBox(height: 12),
                            _amountRow(
                              'Platform commission',
                              summary!.platformCommission,
                            ),
                          ],
                          const SizedBox(height: 12),
                          _amountRow(
                            'Wallet balance',
                            wallet?.balance ?? summary?.currentBalance,
                            isBalance: true,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Wallet balance is not the same as amount owed to HudHud.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: wallet?.balance != null &&
                                      wallet!.balance! > 0
                                  ? _cashOut
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade700,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Cash out',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    AppCurrency.format(
                                      wallet?.balance ?? summary?.currentBalance,
                                      currency: _currency,
                                    ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const WeeklyEarningsBreakdownScreen(),
                                  ),
                                );
                              },
                              child: Text(
                                'See Weekly Breakdown',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          Center(
                            child: TextButton(
                              onPressed: () =>
                                  context.pushNamed(AppRouter.deliveryWallet),
                              child: Text(
                                'View wallet transactions',
                                style: TextStyle(
                                  color: Colors.orange.shade800,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'RECENT TRANSACTIONS',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_transactions.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'No transactions yet',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _transactions.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: Colors.grey.shade200),
                          itemBuilder: (context, index) {
                            final t = _transactions[index];
                            if (t is! Map<String, dynamic>) {
                              return const SizedBox.shrink();
                            }
                            final amount = t['amount']?.toString() ?? '0.00';
                            final description =
                                t['description']?.toString() ?? '—';
                            final date = t['date']?.toString() ?? '—';
                            final status = t['status']?.toString() ?? '—';
                            return ListTile(
                              title: Text(
                                description,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              subtitle: Text(date),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    AppCurrency.format(amount, currency: _currency),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(status, style: const TextStyle(fontSize: 10)),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 100),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _amountRow(String label, double? value, {bool isBalance = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
        Text(
          value != null
              ? AppCurrency.format(value, currency: _currency)
              : '—',
          style: TextStyle(
            fontSize: isBalance ? 20 : 16,
            fontWeight: isBalance ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
