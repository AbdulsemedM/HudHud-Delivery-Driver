import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hudhud_delivery_driver/core/constants/limit_status.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/models/driver_account_standing.dart';
import 'package:hudhud_delivery_driver/core/models/finance_data_source.dart';
import 'package:hudhud_delivery_driver/core/models/driver_wallet.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/pages/delivery_earnings_screen.dart';
import 'package:hudhud_delivery_driver/features/finance/presentation/finance_display.dart';
import 'package:hudhud_delivery_driver/features/finance/presentation/finance_page_helper.dart';
import 'package:hudhud_delivery_driver/features/finance/presentation/pages/wallet_topup_page.dart';

class DriverFinanceHubPage extends StatefulWidget {
  const DriverFinanceHubPage({super.key});

  @override
  State<DriverFinanceHubPage> createState() => _DriverFinanceHubPageState();
}

class _DriverFinanceHubPageState extends State<DriverFinanceHubPage> {
  bool _loading = true;
  bool _forbidden = false;
  String? _statusMessage;
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
      api.getDriverAccountStanding(cached: _standing),
      api.getDriverWallet(cached: _wallet),
    ]);
    if (!mounted) return;

    final standingResult =
        results[0] as FinanceFetchResult<DriverAccountStanding>;
    final walletResult = results[1] as FinanceFetchResult<DriverWallet>;

    for (final result in [standingResult, walletResult]) {
      if (result.isUnauthorized) {
        await FinancePageHelper.handleFetchOutcome(
          context,
          FinanceFetchOutcome.unauthorized,
        );
        return;
      }
    }

    if (standingResult.isForbidden || walletResult.isForbidden) {
      setState(() {
        _forbidden = true;
        _loading = false;
        _statusMessage =
            standingResult.message ?? walletResult.message ?? '';
      });
      return;
    }

    setState(() {
      _standing = standingResult.data ?? _standing;
      _wallet = walletResult.data ?? _wallet;
      _forbidden = false;
      _statusMessage = standingResult.isUnavailable
          ? standingResult.message
          : walletResult.isUnavailable
              ? walletResult.message
              : null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_forbidden) {
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
        body: FinancePageHelper.forbiddenBody(message: _statusMessage),
      );
    }

    final standing = _standing;
    final wallet = _wallet;
    final walletBalance = wallet?.balance;
    final walletCurrency = wallet?.currency ?? standing?.currency ?? 'ETB';
    final limitStatus = standing?.limitStatus ?? LimitStatus.unknown;
    final standingSource = standing?.source ?? FinanceDataSource.primary;
    final walletSource = wallet?.source ?? FinanceDataSource.primary;
    final showSourceBanner =
        FinancePageHelper.isUsingFallbackOrCache(standingSource) ||
            FinancePageHelper.isUsingFallbackOrCache(walletSource);
    final sourceMessage = standing?.sourceMessage ??
        wallet?.sourceMessage ??
        _statusMessage ??
        '';

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
                  if (showSourceBanner)
                    FinancePageHelper.sourceBanner(
                      source: standingSource == FinanceDataSource.cached ||
                              walletSource == FinanceDataSource.cached
                          ? FinanceDataSource.cached
                          : FinanceDataSource.fallback,
                      message: sourceMessage,
                    ),
                  if (limitStatus.showFinanceAlert && standing != null)
                    _limitBanner(standing),
                  _summaryCard(
                    title: 'Wallet balance',
                    amount: walletBalance,
                    currency: walletCurrency,
                    subtitle: 'Stored wallet funds',
                    trailing: TextButton(
                      onPressed: () => _openTopUp(wallet),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Top up',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  if (wallet?.totalIncome != null ||
                      wallet?.totalExpenses != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _summaryCard(
                            title: 'Total income',
                            amount: wallet?.totalIncome,
                            currency: walletCurrency,
                            subtitle: 'Completed credits',
                            compact: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _summaryCard(
                            title: 'Total expenses',
                            amount: wallet?.totalExpenses,
                            currency: walletCurrency,
                            subtitle: 'Completed debits',
                            compact: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (standing != null) ...[
                    if (standing.totalCommitmentCount > 0) ...[
                      const SizedBox(height: 12),
                      _infoTile(
                        icon: Icons.assignment_outlined,
                        title: 'Active commitments',
                        subtitle:
                            '${standing.totalCommitmentCount} active item(s)',
                      ),
                    ],
                    if (standing.actions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Recommended actions',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            for (final action in standing.actions)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Text('• $action'),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
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

  Future<void> _openTopUp(DriverWallet? wallet) async {
    final refreshed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WalletTopUpPage(
          defaultCurrency: wallet?.currency ?? 'ETB',
        ),
      ),
    );
    if (refreshed == true && mounted) await _load();
  }

  Widget _limitBanner(DriverAccountStanding standing) {
    final status = standing.limitStatus;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: status.financeBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: status.financeBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            standing.displayStanding,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: status.financeForegroundColor,
            ),
          ),
          if (standing.actions.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              standing.actions.first,
              style: TextStyle(
                fontSize: 12,
                color: status.financeForegroundColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryCard({
    required String title,
    required double? amount,
    required String currency,
    required String subtitle,
    bool highlight = false,
    bool compact = false,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 6),
          Text(
            formatFinanceAmount(amount, currency),
            style: TextStyle(
              fontSize: compact ? 18 : 24,
              fontWeight: FontWeight.bold,
              color: highlight ? Colors.red.shade800 : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.orange.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(subtitle, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
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
