import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/models/driver_account_standing.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/utils/app_currency.dart';

class AccountStandingPage extends StatefulWidget {
  const AccountStandingPage({super.key});

  @override
  State<AccountStandingPage> createState() => _AccountStandingPageState();
}

class _AccountStandingPageState extends State<AccountStandingPage> {
  bool _loading = true;
  DriverAccountStanding? _standing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final standing = await getIt<ApiService>().getDriverAccountStanding();
    if (!mounted) return;
    setState(() {
      _standing = standing;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _standing;
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
          'Account Standing',
          style: TextStyle(color: Colors.black, fontSize: 18),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : s == null
                ? const Center(child: Text('Unable to load account standing'))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _statusCard(s),
                      const SizedBox(height: 16),
                      _section('Balances', [
                        _row('Wallet balance', s.walletBalance, s.currency),
                        _row('Held collateral', s.heldCollateral, s.currency),
                        _row(
                          'Amount owed to HudHud',
                          s.displayAmountOwed,
                          s.currency,
                          highlight: s.displayAmountOwed > 0,
                        ),
                      ]),
                      const SizedBox(height: 16),
                      _section('Limits', [
                        _row(
                          'Available acceptance limit',
                          s.availableAcceptanceLimit,
                          s.currency,
                        ),
                        _row(
                          'Warning threshold',
                          s.limitWarningThreshold,
                          s.currency,
                        ),
                        _row(
                          'Block threshold',
                          s.limitBlockThreshold,
                          s.currency,
                        ),
                      ]),
                      if (s.debtReasonSummary.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _section('Debt reasons', [
                          for (final reason in s.debtReasonSummary)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text('• $reason'),
                            ),
                        ]),
                      ],
                      if (s.actions.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _section('Recommended actions', [
                          for (final action in s.actions)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text('• $action'),
                            ),
                        ]),
                      ],
                    ],
                  ),
      ),
    );
  }

  Widget _statusCard(DriverAccountStanding s) {
    final status = s.limitStatus;
    Color bg;
    Color fg;
    if (status.blocksAcceptance) {
      bg = Colors.red.shade50;
      fg = Colors.red.shade900;
    } else if (status.showWarning) {
      bg = Colors.amber.shade50;
      fg = Colors.amber.shade900;
    } else {
      bg = Colors.green.shade50;
      fg = Colors.green.shade900;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.displayStanding,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
          if (s.debtStatus != null) ...[
            const SizedBox(height: 6),
            Text('Status: ${s.debtStatus}', style: TextStyle(color: fg)),
          ],
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _row(
    String label,
    double? amount,
    String currency, {
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            amount != null
                ? AppCurrency.format(amount, currency: currency)
                : '—',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: highlight ? Colors.red.shade800 : null,
            ),
          ),
        ],
      ),
    );
  }
}
