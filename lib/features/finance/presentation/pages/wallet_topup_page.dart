import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hudhud_delivery_driver/core/constants/payment_method_codes.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/models/payment_initiate_result.dart';
import 'package:hudhud_delivery_driver/core/models/payment_method.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/services/secure_storage_service.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';
import 'package:hudhud_delivery_driver/core/utils/ethiopian_phone_number.dart';
import 'package:hudhud_delivery_driver/core/utils/payment_details_builder.dart';
import 'package:hudhud_delivery_driver/core/utils/payment_idempotency.dart';
import 'package:hudhud_delivery_driver/core/utils/payment_poller.dart';
import 'package:hudhud_delivery_driver/features/payments/presentation/widgets/qpay_qr_sheet.dart';
import 'package:url_launcher/url_launcher.dart';

class WalletTopUpPage extends StatefulWidget {
  const WalletTopUpPage({
    super.key,
    this.defaultCurrency = 'ETB',
  });

  final String defaultCurrency;

  @override
  State<WalletTopUpPage> createState() => _WalletTopUpPageState();
}

class _WalletTopUpPageState extends State<WalletTopUpPage> {
  final _amountController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cashNoteController = TextEditingController();

  List<PaymentMethod> _methods = [];
  PaymentMethod? _selectedMethod;
  bool _loadingMethods = true;
  bool _submitting = false;
  String? _statusMessage;
  String? _idempotencyKey;
  PaymentPoller? _poller;
  int? _paymentId;

  @override
  void initState() {
    super.initState();
    _loadMethods();
  }

  @override
  void dispose() {
    _poller?.stop();
    _amountController.dispose();
    _phoneController.dispose();
    _cashNoteController.dispose();
    super.dispose();
  }

  Future<void> _loadMethods() async {
    final api = getIt<ApiService>();
    final methods = await api.getPaymentMethods(
      allowedCodes: PaymentMethodCodes.kWalletFundingMethodCodes,
    );
    if (!mounted) return;
    setState(() {
      _methods = methods.isNotEmpty
          ? methods
          : api.defaultWalletFundingMethods();
      _selectedMethod = _methods.isNotEmpty ? _methods.first : null;
      _loadingMethods = false;
    });
  }

  Future<String> _resolveIdempotencyKey() async {
    const scope = 'wallet-topup';
    final storage = getIt<SecureStorageService>();
    _idempotencyKey ??= await storage.getIdempotencyKey(scope);
    _idempotencyKey = PaymentIdempotency.walletTopUpKey(
      existingKey: _idempotencyKey,
    );
    await storage.saveIdempotencyKey(scope, _idempotencyKey!);
    return _idempotencyKey!;
  }

  Future<void> _submit() async {
    final method = _selectedMethod;
    if (method == null) return;

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _snack('wallet.invalid_amount'.tr(), error: true);
      return;
    }

    if (method.code != PaymentMethodCodes.cash &&
        method.code != PaymentMethodCodes.qpay &&
        PaymentMethodCodes.requiresPhone(method.code)) {
      final phone = _phoneController.text.trim();
      if (phone.isEmpty) {
        _snack('wallet.phone_required'.tr(), error: true);
        return;
      }
      if (method.code != PaymentMethodCodes.edahab &&
          EthiopianPhoneNumber.tryNormalize(phone) == null) {
        _snack('wallet.invalid_phone'.tr(), error: true);
        return;
      }
    }

    setState(() {
      _submitting = true;
      _statusMessage = null;
    });

    try {
      final key = await _resolveIdempotencyKey();
      final details = PaymentDetailsBuilder.build(
        methodCode: method.code,
        phone: _phoneController.text.trim(),
        cashReceiptNote: _cashNoteController.text.trim(),
      );

      final result = await getIt<ApiService>().postWalletTopUp(
        paymentMethodCode: method.code,
        amount: amount,
        currency: widget.defaultCurrency,
        paymentDetails: details,
        idempotencyKey: key,
      );

      if (!mounted) return;
      await _handleResult(result, method.code);
    } on AppException catch (e) {
      if (!mounted) return;
      await _handleQpayInitiateError(e);
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _handleResult(
    PaymentInitiateResult result,
    String methodCode,
  ) async {
    if (!result.isSuccess) {
      _snack(result.message ?? 'wallet.payment_failed'.tr(), error: true);
      return;
    }

    _paymentId = result.paymentId;

    if (result.awaitAdminCashConfirmation) {
      setState(() {
        _statusMessage = 'wallet.awaiting_finance'.tr();
      });
      _snack('wallet.awaiting_finance'.tr());
      return;
    }

    if (result.isCompleted) {
      await getIt<SecureStorageService>().deleteIdempotencyKey('wallet-topup');
      _snack('wallet.topup_success'.tr());
      if (mounted) Navigator.pop(context, true);
      return;
    }

    if (qpayInitiateLooksValid(result) &&
        methodCode == PaymentMethodCodes.qpay) {
      final sheetResult = await showQPayQrSheet(
        context: context,
        paymentId: result.paymentId!,
        qrCode: result.qrCode!,
        expiresAt: result.expiresAt,
      );
      if (!mounted) return;
      await _handleQpaySheetResult(sheetResult);
      return;
    }

    if (result.redirectUrl != null) {
      final uri = Uri.tryParse(result.redirectUrl!);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }

    setState(() {
      _statusMessage = result.customerMessage ?? 'wallet.payment_pending'.tr();
    });

    if (result.shouldPoll && _paymentId != null) {
      _poller?.stop();
      _poller = PaymentPoller(api: getIt<ApiService>());
      _poller!.start(
        paymentId: _paymentId!,
        onUpdate: (status) {
          if (!mounted) return;
          if (status.isCompleted) {
            _poller?.stop();
            getIt<SecureStorageService>().deleteIdempotencyKey('wallet-topup');
            _snack('wallet.topup_success'.tr());
            Navigator.pop(context, true);
          } else if (status.isTerminalFailure) {
            _poller?.stop();
            setState(() {
              _statusMessage = status.message ?? 'wallet.payment_failed'.tr();
            });
          }
        },
      );
    }
  }

  Future<void> _handleQpaySheetResult(QPayQrSheetResult? result) async {
    switch (result) {
      case QPayQrSheetResult.completed:
        await getIt<SecureStorageService>().deleteIdempotencyKey('wallet-topup');
        _snack('wallet.topup_success'.tr());
        if (mounted) Navigator.pop(context, true);
        break;
      case QPayQrSheetResult.failed:
      case QPayQrSheetResult.expired:
        await getIt<SecureStorageService>().deleteIdempotencyKey('wallet-topup');
        _idempotencyKey = null;
        setState(() {
          _statusMessage = result == QPayQrSheetResult.expired
              ? 'wallet.qpay_expired'.tr()
              : 'wallet.payment_failed'.tr();
        });
        break;
      case QPayQrSheetResult.unavailable:
        setState(() {
          _statusMessage = 'wallet.qpay_unavailable'.tr();
        });
        break;
      case QPayQrSheetResult.dismissed:
      case null:
        break;
    }
  }

  Future<void> _handleQpayInitiateError(AppException e) async {
    final code = e.code;
    if (code == PaymentMethodCodes.qpayNotConfigured) {
      _snack(e.message, error: true);
      return;
    }
    if (code == PaymentMethodCodes.qpayQrGenerationFailed ||
        code == PaymentMethodCodes.qpayQrGenerationUnavailable) {
      await getIt<SecureStorageService>().deleteIdempotencyKey('wallet-topup');
      _idempotencyKey = null;
      _snack(e.message, error: true);
      return;
    }
    _snack(e.message, error: true);
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final method = _selectedMethod;
    final isCash = method?.code == PaymentMethodCodes.cash;
    final needsPhone =
        method != null && PaymentMethodCodes.requiresPhone(method.code);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text('wallet.top_up'.tr()),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _loadingMethods
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'wallet.amount'.tr(
                      namedArgs: {'currency': widget.defaultCurrency},
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Text('wallet.select_payment_method'.tr()),
                ..._methods.map(
                  (m) => RadioListTile<String>(
                    value: m.code,
                    groupValue: _selectedMethod?.code,
                    onChanged: (code) {
                      if (code == null) return;
                      setState(() {
                        _selectedMethod =
                            _methods.firstWhere((x) => x.code == code);
                      });
                    },
                    title: Text(m.name ?? m.code),
                  ),
                ),
                if (needsPhone) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'wallet.payment_phone'.tr(),
                      border: const OutlineInputBorder(),
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ],
                if (isCash) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _cashNoteController,
                    decoration: InputDecoration(
                      labelText: 'wallet.cash_receipt_note'.tr(),
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
                if (_statusMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _statusMessage!,
                    style: TextStyle(color: Colors.orange.shade800),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text('wallet.top_up'.tr()),
                  ),
                ),
              ],
            ),
    );
  }
}
