import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/models/driver_wallet.dart';
import 'package:hudhud_delivery_driver/core/models/finance_data_source.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';
import 'package:hudhud_delivery_driver/features/finance/presentation/finance_display.dart';
import 'package:hudhud_delivery_driver/features/finance/presentation/finance_page_helper.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(tx.description ?? tx.type ?? 'Transaction'),
        subtitle: Text(tx.date?.toLocal().toString().split('.').first ?? ''),
        trailing: Text(
          formatFinanceAmount(tx.amount, tx.currency),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
