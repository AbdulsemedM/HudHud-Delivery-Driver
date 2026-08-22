import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hudhud_delivery_driver/core/constants/payment_method_codes.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/models/collection_payment_result.dart';
import 'package:hudhud_delivery_driver/core/models/payment_method.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/services/secure_storage_service.dart';
import 'package:hudhud_delivery_driver/core/utils/app_currency.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';
import 'package:hudhud_delivery_driver/core/utils/ethiopian_phone_number.dart';
import 'package:hudhud_delivery_driver/core/utils/payment_details_builder.dart';
import 'package:hudhud_delivery_driver/core/utils/payment_idempotency.dart';
import 'package:hudhud_delivery_driver/features/payments/presentation/widgets/qpay_qr_sheet.dart';

enum DropOffPaymentMode { choose, cash, electronic, pending, confirmed }

/// Drop-off collection after OTP verification (settlement-v2 collect-payment).
class DeliveryPaymentCollectionCard extends StatefulWidget {
  const DeliveryPaymentCollectionCard({
    super.key,
    required this.deliveryId,
    required this.amount,
    required this.currency,
    this.receiverPhone,
    this.initialPaymentStatus,
    this.cashFallbackAllowed = true,
    required this.onPaymentConfirmed,
  });

  final int deliveryId;
  final double amount;
  final String currency;
  final String? receiverPhone;
  final String? initialPaymentStatus;
  final bool cashFallbackAllowed;
  final ValueChanged<bool> onPaymentConfirmed;

  @override
  State<DeliveryPaymentCollectionCard> createState() =>
      _DeliveryPaymentCollectionCardState();
}

class _DeliveryPaymentCollectionCardState
    extends State<DeliveryPaymentCollectionCard> {
  DropOffPaymentMode _mode = DropOffPaymentMode.choose;
  late TextEditingController _phoneController;
  Timer? _pollTimer;
  String? _statusMessage;
  String? _paymentReference;
  bool _initiating = false;
  String? _pollStatus;
  bool _cashFallbackAllowed = true;

  List<PaymentMethod> _methods = [];
  PaymentMethod? _selectedMethod;
  bool _loadingMethods = false;
  bool _qpayQrRetryUsed = false;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.receiverPhone ?? '');
    _cashFallbackAllowed = widget.cashFallbackAllowed;
    if (_isPaymentSettled(widget.initialPaymentStatus)) {
      _mode = DropOffPaymentMode.confirmed;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onPaymentConfirmed(true);
      });
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _phoneController.dispose();
    super.dispose();
  }

  bool _isPaymentSettled(String? status) {
    final s = status?.toLowerCase();
    return s == 'completed' ||
        s == 'paid' ||
        s == 'settled' ||
        s == 'success';
  }

  /// Step 1: select cash (no API yet).
  void _selectCash() {
    setState(() {
      _mode = DropOffPaymentMode.cash;
      _statusMessage = null;
    });
  }

  /// Step 2: confirm cash received → collect-payment.
  Future<void> _confirmCashReceived() async {
    setState(() {
      _initiating = true;
      _statusMessage = null;
    });
    try {
      final result = await getIt<ApiService>().collectDeliveryPayment(
        deliveryId: widget.deliveryId,
        collectionMethod: 'cash',
      );
      if (!mounted) return;
      await _handleCollectResult(result);
    } on AppException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _initiating = false);
    }
  }

  Future<void> _selectElectronic() async {
    setState(() {
      _mode = DropOffPaymentMode.electronic;
      _statusMessage = null;
    });
    await _loadMethods();
  }

  Future<void> _loadMethods() async {
    setState(() => _loadingMethods = true);
    final api = getIt<ApiService>();
    final methods = await api.getPaymentMethods(
      allowedCodes: PaymentMethodCodes.kDropOffElectronicCodes,
    );
    if (!mounted) return;
    setState(() {
      _methods = methods.isNotEmpty
          ? methods
          : api.defaultDropOffElectronicMethods();
      _loadingMethods = false;
      if (_selectedMethod == null && _methods.isNotEmpty) {
        _selectedMethod = _methods.first;
      }
    });
  }

  Future<void> _initiateElectronic() async {
    final method = _selectedMethod;
    if (method == null) return;

    if (method.code == PaymentMethodCodes.qpay) {
      await _initiateQPay();
      return;
    }

    if (PaymentMethodCodes.requiresPhone(method.code)) {
      final phone = _phoneController.text.trim();
      if (phone.isEmpty) {
        _showSnack('wallet.phone_required'.tr(), isError: true);
        return;
      }
      if (method.code != PaymentMethodCodes.edahab &&
          EthiopianPhoneNumber.tryNormalize(phone) == null) {
        _showSnack('wallet.invalid_phone'.tr(), isError: true);
        return;
      }
    }

    setState(() {
      _initiating = true;
      _statusMessage = null;
      _pollStatus = null;
    });

    final phone = _phoneController.text.trim();
    final normalizedPhone = EthiopianPhoneNumber.tryNormalize(phone) ?? phone;
    final paymentDetails = PaymentDetailsBuilder.build(
      methodCode: method.code,
      phone: normalizedPhone,
    );
    paymentDetails['payment_method_code'] = method.code;
    paymentDetails['phone'] = normalizedPhone;

    try {
      // Handbook settlement-v2 uses collection_method ebirr for electronic;
      // API requires top-level payment_phone when method is ebirr.
      final result = await getIt<ApiService>().collectDeliveryPayment(
        deliveryId: widget.deliveryId,
        collectionMethod: 'ebirr',
        paymentPhone: normalizedPhone,
        paymentDetails: paymentDetails,
      );
      if (!mounted) return;
      await _handleCollectResult(result);
    } on AppException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _initiating = false);
    }
  }

  Future<String> _resolveQpayIdempotencyKey() async {
    final scope = PaymentIdempotency.qpayDeliveryScope(widget.deliveryId);
    final storage = getIt<SecureStorageService>();
    final existing = await storage.getIdempotencyKey(scope);
    final key = PaymentIdempotency.qpayDeliveryKey(
      deliveryId: widget.deliveryId,
      existingKey: existing,
    );
    await storage.saveIdempotencyKey(scope, key);
    return key;
  }

  Future<void> _clearQpayIdempotencyKey() async {
    await getIt<SecureStorageService>().deleteIdempotencyKey(
      PaymentIdempotency.qpayDeliveryScope(widget.deliveryId),
    );
  }

  Future<void> _initiateQPay() async {
    setState(() {
      _initiating = true;
      _statusMessage = null;
      _pollStatus = null;
    });

    try {
      final key = await _resolveQpayIdempotencyKey();
      final result = await getIt<ApiService>().initiatePayment(
        paymentMethodCode: PaymentMethodCodes.qpay,
        type: 'delivery',
        amount: widget.amount,
        paymentDetails: const {},
        currency: widget.currency,
        packageDeliveryId: widget.deliveryId,
        idempotencyKey: key,
      );
      if (!mounted) return;
      if (!qpayInitiateLooksValid(result)) {
        _showSnack(
          result.message ?? 'wallet.payment_failed'.tr(),
          isError: true,
        );
        return;
      }
      final sheetResult = await showQPayQrSheet(
        context: context,
        paymentId: result.paymentId!,
        qrCode: result.qrCode!,
        expiresAt: result.expiresAt,
      );
      if (!mounted) return;
      await _handleQpaySheetResult(sheetResult);
    } on AppException catch (e) {
      if (!mounted) return;
      await _handleQpayInitiateError(e);
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _initiating = false);
    }
  }

  Future<void> _handleQpaySheetResult(QPayQrSheetResult? result) async {
    switch (result) {
      case QPayQrSheetResult.completed:
        await _clearQpayIdempotencyKey();
        await _markConfirmed();
        break;
      case QPayQrSheetResult.failed:
      case QPayQrSheetResult.expired:
        await _clearQpayIdempotencyKey();
        setState(() {
          _statusMessage = result == QPayQrSheetResult.expired
              ? 'wallet.qpay_expired'.tr()
              : 'wallet.payment_failed'.tr();
        });
        _showSnack(_statusMessage!, isError: true);
        break;
      case QPayQrSheetResult.unavailable:
        setState(() {
          _statusMessage = 'wallet.qpay_unavailable'.tr();
        });
        _showSnack(_statusMessage!, isError: true);
        break;
      case QPayQrSheetResult.dismissed:
      case null:
        break;
    }
  }

  Future<void> _handleQpayInitiateError(AppException e) async {
    final code = e.code;
    if (code == PaymentMethodCodes.qpayNotConfigured) {
      setState(() {
        _mode = DropOffPaymentMode.choose;
        _statusMessage = e.message;
      });
      _showSnack(e.message, isError: true);
      return;
    }
    if (code == PaymentMethodCodes.qpayQrGenerationFailed ||
        code == PaymentMethodCodes.qpayQrGenerationUnavailable) {
      if (!_qpayQrRetryUsed) {
        _qpayQrRetryUsed = true;
        await _clearQpayIdempotencyKey();
        _showSnack(e.message, isError: true);
        return;
      }
      setState(() {
        _mode = DropOffPaymentMode.choose;
        _statusMessage = e.message;
      });
      _showSnack(e.message, isError: true);
      return;
    }
    _showSnack(e.message, isError: true);
  }

  Future<void> _handleCollectResult(CollectionPaymentResult result) async {
    if (result.cashFallbackAllowed) {
      _cashFallbackAllowed = true;
    }
    _paymentReference = result.paymentReference ?? _paymentReference;
    _pollStatus = result.status;

    if (result.isSettled) {
      await _markConfirmed(result.message);
      return;
    }

    if (result.isTerminalFailure) {
      setState(() {
        _mode = DropOffPaymentMode.choose;
        _statusMessage = result.message ?? 'wallet.payment_failed'.tr();
      });
      _showSnack(_statusMessage!, isError: true);
      return;
    }

    setState(() {
      _mode = DropOffPaymentMode.pending;
      _statusMessage = result.message ?? 'wallet.payment_pending'.tr();
    });

    if (result.shouldPoll) {
      _startPolling();
    } else if (result.isSettled) {
      await _markConfirmed(result.message);
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    final deadline = DateTime.now().add(const Duration(minutes: 3));

    Future<void> poll() async {
      if (!mounted) return;
      if (DateTime.now().isAfter(deadline)) {
        _pollTimer?.cancel();
        setState(() {
          _mode = _cashFallbackAllowed
              ? DropOffPaymentMode.choose
              : DropOffPaymentMode.electronic;
          _statusMessage = 'wallet.payment_failed'.tr();
        });
        return;
      }
      try {
        final status =
            await getIt<ApiService>().getDeliveryCollectionPaymentStatus(
          widget.deliveryId,
          paymentReference: _paymentReference,
        );
        if (!mounted) return;
        setState(() => _pollStatus = status.status);
        if (status.cashFallbackAllowed) {
          _cashFallbackAllowed = true;
        }
        if (status.isSettled) {
          _pollTimer?.cancel();
          await _markConfirmed(status.message);
        } else if (status.isTerminalFailure) {
          _pollTimer?.cancel();
          setState(() {
            _mode = _cashFallbackAllowed
                ? DropOffPaymentMode.choose
                : DropOffPaymentMode.electronic;
            _statusMessage = status.message ?? 'wallet.payment_failed'.tr();
          });
        }
      } catch (_) {
        // Keep polling on transient errors until deadline.
      }
    }

    poll();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => poll());
  }

  Future<void> _markConfirmed([String? message]) async {
    _pollTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _mode = DropOffPaymentMode.confirmed;
      _statusMessage = message ?? 'wallet.payment_confirmed'.tr();
    });
    widget.onPaymentConfirmed(true);
    _showSnack('wallet.payment_confirmed'.tr());
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_mode == DropOffPaymentMode.confirmed) {
      return _statusBanner(
        Icons.check_circle,
        Colors.green,
        _statusMessage ?? 'wallet.payment_confirmed'.tr(),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
          Text(
            'wallet.dropoff_payment_title'.tr(),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'wallet.dropoff_amount'.tr(
              namedArgs: {
                'amount': AppCurrency.format(
                  widget.amount,
                  currency: widget.currency,
                ),
              },
            ),
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 16),
          if (_mode == DropOffPaymentMode.choose) _buildChoiceButtons(),
          if (_mode == DropOffPaymentMode.cash) _buildCashConfirm(),
          if (_mode == DropOffPaymentMode.electronic) _buildElectronicForm(),
          if (_mode == DropOffPaymentMode.pending) _buildPending(),
        ],
      ),
    );
  }

  Widget _buildChoiceButtons() {
    return Column(
      children: [
        Text('wallet.ask_recipient_payment'.tr()),
        const SizedBox(height: 12),
        if (_statusMessage != null) ...[
          Text(
            _statusMessage!,
            style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _initiating ? null : _selectCash,
            icon: const Icon(Icons.money),
            label: Text('wallet.pay_cash'.tr()),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _initiating ? null : _selectElectronic,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.phone_android),
            label: Text('wallet.pay_electronic'.tr()),
          ),
        ),
      ],
    );
  }

  Widget _buildCashConfirm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Text(
            'I confirm I received ${AppCurrency.format(widget.amount, currency: widget.currency)} in cash from the recipient.',
            style: TextStyle(
              color: Colors.orange.shade900,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _initiating ? null : _confirmCashReceived,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
            ),
            child: _initiating
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Confirm cash received'),
          ),
        ),
        TextButton(
          onPressed: _initiating
              ? null
              : () => setState(() => _mode = DropOffPaymentMode.choose),
          child: Text('common.back'.tr()),
        ),
      ],
    );
  }

  Widget _buildElectronicForm() {
    if (_loadingMethods) {
      return const Center(child: CircularProgressIndicator());
    }

    final needsPhone = _selectedMethod != null &&
        PaymentMethodCodes.requiresPhone(_selectedMethod!.code);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('wallet.select_payment_method'.tr()),
        const SizedBox(height: 8),
        ..._methods.map(
          (m) => RadioListTile<PaymentMethod>(
            value: m,
            groupValue: _selectedMethod,
            onChanged: (v) => setState(() => _selectedMethod = v),
            title: Text(m.name ?? m.code),
            subtitle: m.description != null ? Text(m.description!) : null,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        if (needsPhone) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'wallet.payment_phone'.tr(),
              hintText: 'wallet.payment_phone_hint'.tr(),
              border: const OutlineInputBorder(),
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ],
        if (_statusMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _statusMessage!,
            style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _initiating ? null : _initiateElectronic,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
            ),
            child: _initiating
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text('wallet.confirm_payment'.tr()),
          ),
        ),
        TextButton(
          onPressed: _initiating
              ? null
              : () => setState(() => _mode = DropOffPaymentMode.choose),
          child: Text('common.back'.tr()),
        ),
      ],
    );
  }

  Widget _buildPending() {
    return Column(
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 12),
        Text(
          _statusMessage ?? 'wallet.payment_pending'.tr(),
          textAlign: TextAlign.center,
        ),
        if (_pollStatus != null)
          Text(
            'Status: $_pollStatus',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        if (_cashFallbackAllowed) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              _pollTimer?.cancel();
              setState(() => _mode = DropOffPaymentMode.choose);
            },
            child: Text('wallet.pay_cash'.tr()),
          ),
        ],
      ],
    );
  }

  Widget _statusBanner(IconData icon, Color color, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
