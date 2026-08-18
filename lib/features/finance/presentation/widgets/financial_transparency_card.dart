import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/core/constants/limit_status.dart';
import 'package:hudhud_delivery_driver/core/models/cod_preview.dart';
import 'package:hudhud_delivery_driver/core/models/driver_financial_preview.dart';
import 'package:hudhud_delivery_driver/core/utils/app_currency.dart';

/// Pre-accept financial transparency card per Driver Mobile Transparency Guide.
class FinancialTransparencyCard extends StatelessWidget {
  const FinancialTransparencyCard({
    super.key,
    this.preview,
    this.codFallback,
    this.loading = false,
    this.currency = 'ETB',
  });

  final DriverFinancialPreview? preview;
  final CodPreview? codFallback;
  final bool loading;
  final String currency;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(context),
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final effectiveCurrency = preview?.currency ?? currency;
    final earning = preview?.driverEarning;
    final account = preview?.account;
    final cod = preview?.cod ?? codFallback;
    final limitStatus = account?.limitStatus ?? LimitStatus.unknown;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(context, limitStatus: limitStatus),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Financial preview',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          if (earning?.expectedNetEarning != null)
            _row('Expected earning', earning!.expectedNetEarning!, effectiveCurrency),
          if (earning?.platformCommission != null)
            _row(
              'Platform commission',
              earning!.platformCommission!,
              effectiveCurrency,
            ),
          if (preview?.pricing.customerTotal != null)
            _row(
              'Customer delivery',
              preview!.pricing.customerTotal!,
              effectiveCurrency,
            ),
          if (earning == null && preview?.pricing.customerTotal == null)
            Text(
              'Earning preview unavailable',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          if (cod != null) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            _row(
              'COD collateral',
              cod.requiredAmount ?? 0,
              effectiveCurrency,
            ),
            if (cod.availableBalance != null)
              _row(
                'Available COD balance',
                cod.availableBalance!,
                effectiveCurrency,
              ),
            if (cod.currentBalance != null)
              _row('Wallet balance', cod.currentBalance!, effectiveCurrency),
            if (cod.heldCollateral != null)
              _row('Held collateral', cod.heldCollateral!, effectiveCurrency),
          ],
          if (account != null) ...[
            if (account.availableAcceptanceLimit != null)
              _row(
                'Available limit',
                account.availableAcceptanceLimit!,
                effectiveCurrency,
              ),
            if (account.limitAfterAcceptance != null)
              _row(
                'After accepting',
                account.limitAfterAcceptance!,
                effectiveCurrency,
              ),
            if (account.displayAmountOwed > 0)
              _row(
                'Amount owed to HudHud',
                account.displayAmountOwed,
                effectiveCurrency,
                highlight: true,
              ),
          ],
          if (limitStatus == LimitStatus.nearLimit &&
              account?.limitAfterAcceptance != null) ...[
            const SizedBox(height: 10),
            _warningBox(
              'You are approaching your acceptance limit.\n'
              'After accepting this delivery, your available limit will be '
              '${AppCurrency.format(account!.limitAfterAcceptance, currency: effectiveCurrency)}.',
            ),
          ],
          if (limitStatus.blocksAcceptance) ...[
            const SizedBox(height: 10),
            _warningBox(
              _blockedMessage(preview, account),
              isError: true,
            ),
          ] else if (cod != null && !cod.canAccept) ...[
            const SizedBox(height: 10),
            _warningBox(cod.blockedMessage, isError: true),
          ],
        ],
      ),
    );
  }

  static String _blockedMessage(
    DriverFinancialPreview? preview,
    DriverAccountPreview? account,
  ) {
    final reasons = preview?.acceptance.blockingReasons ?? const [];
    if (reasons.isNotEmpty) return reasons.join('\n');
    if (account != null && account.displayAmountOwed > 0) {
      return 'Acceptance unavailable.\n'
          'Amount owed to HudHud: ${AppCurrency.format(account.displayAmountOwed, currency: preview?.currency)}.\n'
          'Please settle the outstanding amount or contact support.';
    }
    return 'Acceptance unavailable. Please contact support.';
  }

  BoxDecoration _cardDecoration(
    BuildContext context, {
    LimitStatus limitStatus = LimitStatus.unknown,
  }) {
    Color borderColor = Colors.grey.shade200;
    if (limitStatus == LimitStatus.nearLimit) {
      borderColor = Colors.amber.shade300;
    } else if (limitStatus.blocksAcceptance) {
      borderColor = Colors.red.shade200;
    }
    return BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: borderColor),
    );
  }

  Widget _row(
    String label,
    double amount,
    String currency, {
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: highlight ? Colors.red.shade800 : Colors.grey.shade800,
              ),
            ),
          ),
          Text(
            AppCurrency.format(amount, currency: currency),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: highlight ? Colors.red.shade800 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _warningBox(String message, {bool isError = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isError ? Colors.red.shade50 : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isError ? Colors.red.shade200 : Colors.amber.shade200,
        ),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 12,
          color: isError ? Colors.red.shade900 : Colors.amber.shade900,
        ),
      ),
    );
  }
}

/// Compact COD details for list cards.
class CodPreviewCompact extends StatelessWidget {
  const CodPreviewCompact({super.key, required this.cod});

  final CodPreview cod;

  @override
  Widget build(BuildContext context) {
    if (!cod.hasCodDetails) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (cod.requiredAmount != null)
            _miniRow('COD collateral', cod.requiredAmount!),
          if (cod.availableBalance != null)
            _miniRow('Available balance', cod.availableBalance!),
          if (cod.heldCollateral != null)
            _miniRow('Held collateral', cod.heldCollateral!),
          if (cod.currentBalance != null)
            _miniRow('Wallet balance', cod.currentBalance!),
        ],
      ),
    );
  }

  Widget _miniRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 11)),
          ),
          Text(
            AppCurrency.format(amount),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
