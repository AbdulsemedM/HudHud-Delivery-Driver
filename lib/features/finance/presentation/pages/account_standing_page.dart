import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hudhud_delivery_driver/core/constants/limit_status.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/models/driver_account_standing.dart';
import 'package:hudhud_delivery_driver/core/models/finance_data_source.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/features/finance/presentation/finance_display.dart';
import 'package:hudhud_delivery_driver/features/finance/presentation/finance_page_helper.dart';

class AccountStandingPage extends StatefulWidget {
  const AccountStandingPage({super.key});

  @override
  State<AccountStandingPage> createState() => _AccountStandingPageState();
}

class _AccountStandingPageState extends State<AccountStandingPage> {
  bool _loading = true;
  bool _forbidden = false;
  String? _statusMessage;
  DriverAccountStanding? _standing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result =
        await getIt<ApiService>().getDriverAccountStanding(cached: _standing);
    if (!mounted) return;

    if (result.isUnauthorized) {
      await FinancePageHelper.handleFetchOutcome(
        context,
        FinanceFetchOutcome.unauthorized,
      );
      return;
    }

    if (result.isForbidden) {
      setState(() {
        _forbidden = true;
        _loading = false;
        _statusMessage = result.message;
      });
      return;
    }

    setState(() {
      _standing = result.data ?? _standing;
      _forbidden = false;
      _statusMessage = result.message;
      _loading = false;
    });
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

    final s = _standing;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _appBar(),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : s == null
                ? const Center(
                    child: Text('Unable to load account standing'),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (FinancePageHelper.isUsingFallbackOrCache(s.source))
                        FinancePageHelper.sourceBanner(
                          source: s.source,
                          message: s.sourceMessage ?? _statusMessage,
                        ),
                      _statusCard(s),
                      const SizedBox(height: 16),
                      _section('Account status', [
                        _infoRow('Application status', s.applicationStatus),
                        _infoRow('Risk level', s.riskLevel),
                        _infoRow(
                          'COD acceptance',
                          s.canAcceptCod == null
                              ? null
                              : s.canAcceptCod!
                                  ? 'Eligible'
                                  : 'Restricted',
                        ),
                        if (s.debtAsOf != null)
                          _infoRow(
                            'As of',
                            s.debtAsOf!.toLocal().toString().split('.').first,
                          ),
                      ]),
                      const SizedBox(height: 16),
                      _section('Balances', [
                        _row('Wallet balance', s.walletBalance, s.currency),
                        _row('Held collateral', s.heldCollateral, s.currency),
                        _row(
                          'Active platform fee commitment',
                          s.activePlatformFeeCommitment,
                          s.currency,
                        ),
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
                      if (s.foodAndVendorCodCommitments.isNotEmpty ||
                          s.packageDeliveryPlatformFeeCommitments
                              .isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _section('Commitments', [
                          if (s.foodAndVendorCodCommitments.isNotEmpty)
                            _commitmentList(
                              'Food and vendor COD',
                              s.foodAndVendorCodCommitments,
                            ),
                          if (s.packageDeliveryPlatformFeeCommitments
                              .isNotEmpty)
                            _commitmentList(
                              'Package delivery platform fees',
                              s.packageDeliveryPlatformFeeCommitments,
                            ),
                        ]),
                      ],
                      if (s.outstandingSettlements.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _section('Outstanding settlements', [
                          _commitmentList('', s.outstandingSettlements),
                        ]),
                      ],
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
                      if (s.limitStatus == LimitStatus.overdue) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => context
                                .pushNamed(AppRouter.deliverySettlements),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade700,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('View settlements'),
                          ),
                        ),
                      ],
                      if (s.totalDeliveries != null ||
                          s.totalEarnings != null ||
                          s.completionRate != null) ...[
                        const SizedBox(height: 16),
                        _section('Profile statistics', [
                          _infoRow(
                            'Total deliveries',
                            s.totalDeliveries?.toString(),
                          ),
                          _row('Total earnings', s.totalEarnings, s.currency),
                          _percentRow('Completion rate', s.completionRate),
                        ]),
                      ],
                      if (s.calculationBasis.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _section('Calculation basis', [
                          for (final entry in s.calculationBasis.entries)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                '${_formatBasisKey(entry.key)}: ${entry.value}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            'This is an operational account summary, not a bank '
                            'statement or personalized financial advice.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ]),
                      ],
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
        'Account Standing',
        style: TextStyle(color: Colors.black, fontSize: 18),
      ),
    );
  }

  String _formatBasisKey(String key) {
    return key
        .split('_')
        .map((part) =>
            part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  Widget _statusCard(DriverAccountStanding s) {
    final status = s.limitStatus;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: status.financeBackgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: status.financeBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.displayStanding,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: status.financeForegroundColor,
            ),
          ),
          if (s.debtStatus != null) ...[
            const SizedBox(height: 6),
            Text(
              'Status: ${s.debtStatus}',
              style: TextStyle(color: status.financeForegroundColor),
            ),
          ],
          if (s.limitStatus == LimitStatus.blocked &&
              s.applicationStatus != null) ...[
            const SizedBox(height: 6),
            Text(
              'Application: ${s.applicationStatus}',
              style: TextStyle(color: status.financeForegroundColor),
            ),
          ],
        ],
      ),
    );
  }

  Widget _commitmentList(String title, List<Map<String, dynamic>> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) ...[
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
        ],
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              item.entries
                  .map((e) => '${e.key}: ${e.value}')
                  .join(' · '),
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ],
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
            formatFinanceAmount(amount, currency),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: highlight ? Colors.red.shade800 : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value?.isNotEmpty == true ? value! : financeNotAvailableText,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _percentRow(String label, double? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            formatFinancePercent(value),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
