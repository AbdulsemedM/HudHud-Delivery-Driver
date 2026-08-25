import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/models/driver_wallet.dart';
import 'package:hudhud_delivery_driver/core/models/finance_data_source.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/services/wallet_topup_recovery_service.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';
import 'package:hudhud_delivery_driver/features/finance/presentation/finance_display.dart';
import 'package:hudhud_delivery_driver/features/finance/presentation/finance_page_helper.dart';
import 'package:hudhud_delivery_driver/features/finance/presentation/pages/wallet_topup_page.dart';
import 'package:hudhud_delivery_driver/features/finance/presentation/pages/wallet_transfer_page.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  bool _loading = true;
  bool _forbidden = false;
  String? _statusMessage;
  DriverWallet? _wallet;
  WalletTransactionsPage? _transactionsPage;
  bool _pendingTopUp = false;

  WalletTopUpRecoveryService get _recovery =>
      getIt<WalletTopUpRecoveryService>();

  @override
  void initState() {
    super.initState();
    _recovery.addListener(_onTopUpRecovery);
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    await _load();
    await _recovery.syncPendingTopUps();
  }

  @override
  void dispose() {
    _recovery.removeListener(_onTopUpRecovery);
    super.dispose();
  }

  void _onTopUpRecovery() {
    if (!mounted) return;
    setState(() {
      _pendingTopUp = _recovery.hasPending;
    });
    if (_recovery.lastSyncSettled) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = getIt<ApiService>();
    final results = await Future.wait([
      api.getDriverWallet(cached: _wallet),
      api.getWalletTransactions(cached: _transactionsPage),
    ]);
    if (!mounted) return;

    final walletResult = results[0] as FinanceFetchResult<DriverWallet>;
    final txResult =
        results[1] as FinanceFetchResult<WalletTransactionsPage>;

    for (final result in [walletResult, txResult]) {
      if (result.isUnauthorized) {
        await FinancePageHelper.handleFetchOutcome(
          context,
          FinanceFetchOutcome.unauthorized,
        );
        return;
      }
    }

    if (walletResult.isForbidden || txResult.isForbidden) {
      setState(() {
        _forbidden = true;
        _loading = false;
        _statusMessage = walletResult.message ?? txResult.message;
      });
      return;
    }

    setState(() {
      _wallet = walletResult.data ?? _wallet;
      _transactionsPage = txResult.data ?? _transactionsPage;
      _forbidden = false;
      _statusMessage = walletResult.isUnavailable
          ? walletResult.message
          : txResult.isUnavailable
              ? txResult.message
              : null;
      _loading = false;
    });
  }

  Future<void> _withdraw() async {
    final wallet = _wallet;
    if (wallet?.balance == null || wallet!.balance! <= 0) return;

    final amountController = TextEditingController(
      text: wallet.balance!.toStringAsFixed(2),
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cash out'),
        content: TextField(
          controller: amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Amount (${wallet.currency})',
          ),
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
      final res = await getIt<ApiService>().postWalletWithdraw(amount: amount);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res['message']?.toString() ?? 'Withdrawal request submitted',
          ),
          backgroundColor: Colors.green,
        ),
      );
      await _load();
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

  Future<void> _openTransfer(DriverWallet? wallet) async {
    final refreshed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WalletTransferPage(
          defaultCurrency: wallet?.currency ?? 'ETB',
        ),
      ),
    );
    if (refreshed == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_forbidden) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: _appBar(),
        body: FinancePageHelper.forbiddenBody(message: _statusMessage),
      );
    }

    final wallet = _wallet;
    final transactions = _transactionsPage?.transactions ?? const [];
    final walletSource = wallet?.source ?? FinanceDataSource.primary;
    final txSource = _transactionsPage != null && _statusMessage != null
        ? FinanceDataSource.cached
        : FinanceDataSource.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _appBar(),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (FinancePageHelper.isUsingFallbackOrCache(walletSource) ||
                      FinancePageHelper.isUsingFallbackOrCache(txSource))
                    FinancePageHelper.sourceBanner(
                      source: walletSource == FinanceDataSource.cached ||
                              txSource == FinanceDataSource.cached
                          ? FinanceDataSource.cached
                          : FinanceDataSource.fallback,
                      message: wallet?.sourceMessage ?? _statusMessage,
                    ),
                  if (_pendingTopUp)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'wallet.verification_in_progress'.tr(),
                        style: TextStyle(color: Colors.orange.shade800),
                      ),
                    ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Wallet balance',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formatFinanceAmount(
                            wallet?.balance,
                            wallet?.currency ?? 'ETB',
                          ),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (wallet?.totalIncome != null ||
                            wallet?.totalExpenses != null) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _metric(
                                  'Total income',
                                  wallet?.totalIncome,
                                  wallet?.currency ?? 'ETB',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _metric(
                                  'Total expenses',
                                  wallet?.totalExpenses,
                                  wallet?.currency ?? 'ETB',
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (wallet?.heldCollateral != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Held collateral: ${formatFinanceAmount(wallet!.heldCollateral, wallet.currency)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _openTopUp(wallet),
                                child: const Text('Top up'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _openTransfer(wallet),
                                child: const Text('Transfer'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: wallet?.balance != null &&
                                    wallet!.balance! > 0
                                ? _withdraw
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade700,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Cash out'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'TRANSACTIONS',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (transactions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('No transactions yet')),
                    )
                  else
                    ...transactions.map(_transactionTile),
                ],
              ),
      ),
    );
  }

  AppBar _appBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Wallet',
        style: TextStyle(color: Colors.black, fontSize: 18),
      ),
    );
  }

  Widget _metric(String label, double? amount, String currency) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text(
          formatFinanceAmount(amount, currency),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _transactionTile(WalletTransaction tx) {
    final isReward = tx.isDriverWalletReward;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isReward ? Colors.green.shade50 : null,
      child: ListTile(
        title: Text(
          isReward ? 'Driver wallet reward' : (tx.description ?? tx.type ?? 'Transaction'),
          style: TextStyle(
            fontWeight: isReward ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        subtitle: Text(tx.date?.toLocal().toString().split('.').first ?? ''),
        trailing: Text(
          formatFinanceAmount(tx.amount, tx.currency),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isReward ? Colors.green.shade800 : null,
          ),
        ),
      ),
    );
  }
}
