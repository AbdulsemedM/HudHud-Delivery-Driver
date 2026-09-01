import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hudhud_delivery_driver/core/constants/payment_method_codes.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/models/payment_initiate_result.dart';
import 'package:hudhud_delivery_driver/core/models/payment_method.dart';
import 'package:hudhud_delivery_driver/core/models/payment_status_result.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/services/secure_storage_service.dart';
import 'package:hudhud_delivery_driver/core/services/wallet_topup_recovery_service.dart';
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

class _WalletTopUpPageState extends State<WalletTopUpPage>
    with WidgetsBindingObserver {
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
    WidgetsBinding.instance.addObserver(this);
    _loadMethods();
    unawaited(_restorePendingTopUp());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poller?.stop();
    _amountController.dispose();
    _phoneController.dispose();
    _cashNoteController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_poller?.pollOnce() ?? _restorePendingTopUp());
    }
  }

  Future<void> _loadMethods() async {
    final api = getIt<ApiService>();
    final methods = await api.getPaymentMethods(
      allowedCodes: PaymentMethodCodes.kWalletFundingMethodCodes,
      type: 'wallet',
      currency: widget.defaultCurrency,
    );
    if (!mounted) return;
    final loaded = List<PaymentMethod>.from(
      methods.isNotEmpty ? methods : api.defaultWalletFundingMethods(),
    );

    // type=wallet often omits QPay even when delivery already offers it.
    final hasUsableQpay =
        loaded.any((m) => m.isQpay && m.canInitiateQpay);
    if (!hasUsableQpay) {
      loaded.removeWhere((m) => m.isQpay);
      final qpay = await api.resolveUsableQpay(
        currency: widget.defaultCurrency,
      );
      if (!mounted) return;
      if (qpay != null && qpay.canInitiateQpay) {
        loaded.insert(0, qpay);
      }
    }

    loaded.sort((a, b) {
      if (a.isQpay && !b.isQpay) return -1;
      if (!a.isQpay && b.isQpay) return 1;
      return a.code.compareTo(b.code);
    });
    setState(() {
      _methods = loaded;
      _selectedMethod = _methods.isNotEmpty ? _methods.first : null;
      _loadingMethods = false;
    });
  }

  Future<String> _resolveIdempotencyKey(String fingerprint) async {
    final storage = getIt<SecureStorageService>();
    final storedKey = _idempotencyKey ??
        await storage.getIdempotencyKey(PaymentIdempotency.walletTopUpScope);
    final storedFingerprint = await storage.getIdempotencyKey(
      PaymentIdempotency.walletTopUpFingerprintScope,
    );
    final key = PaymentIdempotency.resolveWalletTopUpKey(
      fingerprint: fingerprint,
      storedKey: storedKey,
      storedFingerprint: storedFingerprint,
    );
    _idempotencyKey = key;
    await storage.saveIdempotencyKey(PaymentIdempotency.walletTopUpScope, key);
    await storage.saveIdempotencyKey(
      PaymentIdempotency.walletTopUpFingerprintScope,
      fingerprint,
    );
    return key;
  }

  Future<void> _clearIdempotency() async {
    _idempotencyKey = null;
    final storage = getIt<SecureStorageService>();
    await storage.deleteIdempotencyKey(PaymentIdempotency.walletTopUpScope);
    await storage.deleteIdempotencyKey(
      PaymentIdempotency.walletTopUpFingerprintScope,
    );
  }

  Future<void> _clearPayment(int? paymentId) async {
    if (paymentId != null) {
      await getIt<WalletTopUpRecoveryService>().clearPayment(paymentId);
    }
    if (_paymentId == paymentId) _paymentId = null;
  }

  Future<void> _restorePendingTopUp() async {
    final ids =
        await getIt<SecureStorageService>().getPendingWalletTopUpPaymentIds();
    if (ids.isEmpty || !mounted) return;
    _paymentId = ids.last;
    setState(() {
      _statusMessage = 'wallet.verification_in_progress'.tr();
    });
    _startWalletPolling(_paymentId!);
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

    final fingerprint = PaymentIdempotency.walletTopUpFingerprint(
      methodCode: method.code,
      amount: amount,
      currency: widget.defaultCurrency,
      phone: _phoneController.text,
      cashNote: _cashNoteController.text,
    );

    final storage = getIt<SecureStorageService>();
    final storedFingerprint = await storage.getIdempotencyKey(
      PaymentIdempotency.walletTopUpFingerprintScope,
    );
    final pendingIds = await storage.getPendingWalletTopUpPaymentIds();
    // QPay needs a fresh initiate (idempotent) so the QR payload is returned;
    // polling alone never opens the QR sheet.
    final isQpay = method.code == PaymentMethodCodes.qpay;
    if (!isQpay &&
        storedFingerprint == fingerprint &&
        pendingIds.isNotEmpty) {
      _paymentId = pendingIds.last;
      setState(() {
        _statusMessage = 'wallet.payment_pending'.tr();
      });
      _startWalletPolling(_paymentId!);
      return;
    }

    setState(() {
      _submitting = true;
      _statusMessage = null;
    });

    try {
      final details = PaymentDetailsBuilder.build(
        methodCode: method.code,
        phone: _phoneController.text.trim(),
        cashReceiptNote: _cashNoteController.text.trim(),
      );
      final result = await _postTopUp(
        methodCode: method.code,
        amount: amount,
        details: details,
        fingerprint: fingerprint,
      );

      if (!mounted) return;
      await _handleResult(result, method.code, amount: amount);
    } on AppException catch (e) {
      if (!mounted) return;
      await _handleInitiateError(e);
    } catch (e) {
      if (!mounted) return;
      _snack('wallet.payment_error_generic'.tr(), error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<PaymentInitiateResult> _postTopUp({
    required String methodCode,
    required double amount,
    required Map<String, dynamic> details,
    required String fingerprint,
    bool retriedConflict = false,
  }) async {
    final api = getIt<ApiService>();
    final key = await _resolveIdempotencyKey(fingerprint);
    try {
      return await api.postWalletTopUp(
        paymentMethodCode: methodCode,
        amount: amount,
        currency: widget.defaultCurrency,
        paymentDetails: details,
        idempotencyKey: key,
      );
    } on AppException catch (e) {
      if (retriedConflict || !PaymentIdempotency.isIdempotencyConflict(e)) {
        rethrow;
      }
      await _clearIdempotency();
      return _postTopUp(
        methodCode: methodCode,
        amount: amount,
        details: details,
        fingerprint: fingerprint,
        retriedConflict: true,
      );
    }
  }

  Future<void> _handleResult(
    PaymentInitiateResult result,
    String methodCode, {
    required double amount,
  }) async {
    if (!result.isSuccess) {
      await _clearIdempotency();
      _snack(result.message ?? 'wallet.payment_failed'.tr(), error: true);
      return;
    }

    _paymentId = result.paymentId;
    if (_paymentId != null) {
      await getIt<SecureStorageService>()
          .savePendingWalletTopUpPaymentId(_paymentId!);
    }

    if (result.awaitAdminCashConfirmation) {
      setState(() {
        _statusMessage = 'wallet.awaiting_finance'.tr();
      });
      _snack('wallet.awaiting_finance'.tr());
      return;
    }

    if (result.isCompleted) {
      await _onWalletSettled();
      return;
    }

    if (methodCode == PaymentMethodCodes.qpay) {
      if (qpayInitiateLooksValid(result)) {
        final sheetResult = await showQPayQrSheet(
          context: context,
          flowContext: QPayFlowContext.walletTopUp,
          paymentId: result.paymentId!,
          qrCode: result.qrCode!,
          expiresAt: result.expiresAt,
          amount: amount,
          currency: widget.defaultCurrency,
        );
        if (!mounted) return;
        await _handleQpaySheetResult(sheetResult);
        return;
      }
      setState(() {
        _statusMessage = result.customerMessage ??
            result.message ??
            'wallet.qpay_unavailable'.tr();
      });
      if (_paymentId != null && result.shouldPoll) {
        _startWalletPolling(_paymentId!);
      }
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
      _startWalletPolling(_paymentId!);
    }
  }

  void _startWalletPolling(int paymentId) {
    _poller?.stop();
    _poller = PaymentPoller(api: getIt<ApiService>());
    _poller!.startWalletTopUp(
      paymentId: paymentId,
      onUpdate: (status) {
        if (!mounted) return;
        unawaited(_applyStatus(status));
      },
      onFatal: (error) {
        if (!mounted) return;
        setState(() {
          _statusMessage = error.message.isNotEmpty
              ? error.message
              : 'wallet.qpay_unavailable'.tr();
        });
        _snack(_statusMessage!, error: true);
      },
    );
  }

  Future<void> _applyStatus(PaymentStatusResult status) async {
    if (status.isCompleted) {
      _poller?.stop();
      await _onWalletSettled(paymentId: status.paymentId ?? _paymentId);
      return;
    }
    if (status.isTerminalFailure) {
      _poller?.stop();
      await _clearPayment(status.paymentId ?? _paymentId);
      await _clearIdempotency();
      setState(() {
        _statusMessage = status.message ?? 'wallet.payment_failed'.tr();
      });
      return;
    }
    setState(() {
      _statusMessage = status.isAwaitingProvider || status.isEbirrRetryRequired
          ? 'wallet.verification_in_progress'.tr()
          : (status.message ?? 'wallet.payment_pending'.tr());
    });
  }

  Future<void> _onWalletSettled({int? paymentId}) async {
    await _clearPayment(paymentId ?? _paymentId);
    await _clearIdempotency();
    if (!mounted) return;
    _snack('wallet.wallet_credited'.tr());
    Navigator.pop(context, true);
  }

  Future<void> _handleQpaySheetResult(QPayQrSheetResult? result) async {
    switch (result) {
      case QPayQrSheetResult.completed:
        await _onWalletSettled();
        break;
      case QPayQrSheetResult.failed:
      case QPayQrSheetResult.expired:
        await _clearPayment(_paymentId);
        await _clearIdempotency();
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
        if (_paymentId != null) {
          setState(() {
            _statusMessage = 'wallet.verification_in_progress'.tr();
          });
          _startWalletPolling(_paymentId!);
        }
        break;
    }
  }

  Future<void> _handleInitiateError(AppException e) async {
    final code = e.code;
    if (code == PaymentMethodCodes.qpayNotConfigured) {
      _snack(e.message, error: true);
      return;
    }
    if (code == PaymentMethodCodes.qpayQrGenerationFailed ||
        code == PaymentMethodCodes.qpayQrGenerationUnavailable) {
      await _clearIdempotency();
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
                    subtitle: m.isQpay
                        ? Text('wallet.qpay_banks_hint'.tr())
                        : (m.description != null && m.description!.isNotEmpty
                            ? Text(m.description!)
                            : null),
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
