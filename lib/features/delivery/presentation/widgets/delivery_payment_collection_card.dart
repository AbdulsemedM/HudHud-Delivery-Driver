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
import 'package:hudhud_delivery_driver/core/utils/app_currency.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';
import 'package:hudhud_delivery_driver/core/utils/ethiopian_phone_number.dart';
import 'package:hudhud_delivery_driver/core/utils/payment_details_builder.dart';
import 'package:hudhud_delivery_driver/core/utils/payment_idempotency.dart';
import 'package:hudhud_delivery_driver/core/utils/payment_poller.dart';
import 'package:url_launcher/url_launcher.dart';

enum DropOffPaymentMode { choose, cash, electronic, pending, confirmed }

/// Drop-off payment collection before OTP verification.
class DeliveryPaymentCollectionCard extends StatefulWidget {
  const DeliveryPaymentCollectionCard({
    super.key,
    required this.deliveryId,
    required this.amount,
    required this.currency,
    this.receiverPhone,
    this.initialPaymentStatus,
    required this.onPaymentConfirmed,
  });

  final int deliveryId;
  final double amount;
  final String currency;
  final String? receiverPhone;
  final String? initialPaymentStatus;
  final ValueChanged<bool> onPaymentConfirmed;

  @override
  State<DeliveryPaymentCollectionCard> createState() =>
      _DeliveryPaymentCollectionCardState();
}

class _DeliveryPaymentCollectionCardState
    extends State<DeliveryPaymentCollectionCard> {
  DropOffPaymentMode _mode = DropOffPaymentMode.choose;
  List<PaymentMethod> _methods = [];
  PaymentMethod? _selectedMethod;
  late TextEditingController _phoneController;
  PaymentPoller? _poller;
  int? _paymentId;
  String? _statusMessage;
  String? _customerMessage;
  String? _idempotencyKey;
  bool _loadingMethods = false;
  bool _initiating = false;
  String? _pollStatus;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.receiverPhone ?? '');
    if (_isPaymentCompleted(widget.initialPaymentStatus)) {
      _mode = DropOffPaymentMode.confirmed;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onPaymentConfirmed(true);
      });
    }
  }

  @override
  void dispose() {
    _poller?.stop();
    _phoneController.dispose();
    super.dispose();
  }

  bool _isPaymentCompleted(String? status) {
    final s = status?.toLowerCase();
    return s == 'completed' || s == 'paid';
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

  void _selectCash() {
    setState(() {
      _mode = DropOffPaymentMode.cash;
      _statusMessage = 'wallet.dropoff_cash_selected'.tr();
    });
    widget.onPaymentConfirmed(true);
  }

  Future<void> _selectElectronic() async {
    setState(() => _mode = DropOffPaymentMode.electronic);
    await _loadMethods();
  }

  Future<String> _resolveIdempotencyKey() async {
    final scope = 'delivery-payment-${widget.deliveryId}';
    final storage = getIt<SecureStorageService>();
    _idempotencyKey ??= await storage.getIdempotencyKey(scope);
    _idempotencyKey = PaymentIdempotency.paymentAttemptKey(
      type: 'delivery',
      entityId: widget.deliveryId,
      existingKey: _idempotencyKey,
    );
    await storage.saveIdempotencyKey(scope, _idempotencyKey!);
    return _idempotencyKey!;
  }

  Future<void> _clearIdempotencyKey() async {
    final scope = 'delivery-payment-${widget.deliveryId}';
    await getIt<SecureStorageService>().deleteIdempotencyKey(scope);
    _idempotencyKey = null;
  }

  Future<void> _initiatePayment({bool retry = false}) async {
    final method = _selectedMethod;
    if (method == null) return;

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

    final api = getIt<ApiService>();
  final phone = _phoneController.text.trim();
    final paymentDetails = PaymentDetailsBuilder.build(
      methodCode: method.code,
      phone: phone,
    );

    try {
      PaymentInitiateResult result;
      if (retry) {
        final normalizedPhone = EthiopianPhoneNumber.tryNormalize(phone);
        result = await api.retryDeliveryPayment(
          deliveryId: widget.deliveryId,
          paymentMethod: method.code,
          paymentPhone: normalizedPhone,
        );
      } else {
        final key = await _resolveIdempotencyKey();
        result = await api.initiatePayment(
          paymentMethodCode: method.code,
          type: 'delivery',
          amount: widget.amount,
          paymentDetails: paymentDetails,
          currency: widget.currency,
          packageDeliveryId: widget.deliveryId,
          idempotencyKey: key,
        );
      }

      if (!mounted) return;
      await _handleInitiateResult(result);
    } on AppException catch (e) {
      if (!mounted) return;
      if (e is ConflictException && !retry) {
        try {
          final result = await api.retryDeliveryPayment(
            deliveryId: widget.deliveryId,
            paymentMethod: method.code,
            paymentPhone: EthiopianPhoneNumber.tryNormalize(_phoneController.text),
          );
          if (!mounted) return;
          await _handleInitiateResult(result);
          return;
        } catch (retryError) {
          if (!mounted) return;
          _showSnack(
            retryError is AppException
                ? retryError.message
                : retryError.toString(),
            isError: true,
          );
        }
      } else {
        _showSnack(e.message, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _initiating = false);
    }
  }

  Future<void> _handleInitiateResult(PaymentInitiateResult result) async {
    if (!result.isSuccess) {
      _showSnack(
        result.message ?? 'wallet.payment_failed'.tr(),
        isError: true,
      );
      return;
    }

    _paymentId = result.paymentId;
    _customerMessage = result.customerMessage ?? result.message;
    _pollStatus = result.paymentStatus;

    if (result.isCompleted) {
      await _markConfirmed();
      return;
    }

    if (result.redirectUrl != null && result.redirectUrl!.isNotEmpty) {
      final uri = Uri.tryParse(result.redirectUrl!);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }

    if (result.qrCode != null && result.qrCode!.isNotEmpty) {
      await _showQrDialog(result.qrCode!);
    }

    setState(() {
      _mode = DropOffPaymentMode.pending;
      _statusMessage = _customerMessage ?? 'wallet.payment_pending'.tr();
    });

    if (result.shouldPoll && _paymentId != null) {
      _startPolling(_paymentId!);
    } else if (result.awaitAdminCashConfirmation) {
      setState(() {
        _statusMessage = 'wallet.awaiting_finance'.tr();
      });
    }
  }

  void _startPolling(int paymentId) {
    _poller?.stop();
    _poller = PaymentPoller(api: getIt<ApiService>());
    _poller!.start(
      paymentId: paymentId,
      onUpdate: (status) {
        if (!mounted) return;
        setState(() => _pollStatus = status.status);
        if (status.isCompleted) {
          _markConfirmed();
        } else if (status.isTerminalFailure) {
          _poller?.stop();
          setState(() {
            _mode = DropOffPaymentMode.electronic;
            _statusMessage = status.message ?? 'wallet.payment_failed'.tr();
          });
          _clearIdempotencyKey();
        }
      },
    );
  }

  Future<void> _markConfirmed() async {
    _poller?.stop();
    await _clearIdempotencyKey();
    if (!mounted) return;
    setState(() {
      _mode = DropOffPaymentMode.confirmed;
      _statusMessage = 'wallet.payment_confirmed'.tr();
    });
    widget.onPaymentConfirmed(true);
    _showSnack('wallet.payment_confirmed'.tr());
  }

  Future<void> _showQrDialog(String qr) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('wallet.scan_qr'.tr()),
        content: SelectableText(qr),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.done'.tr()),
          ),
        ],
      ),
    );
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
                'amount': AppCurrency.format(widget.amount, currency: widget.currency),
              },
            ),
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 16),
          if (_mode == DropOffPaymentMode.choose) _buildChoiceButtons(),
          if (_mode == DropOffPaymentMode.cash) _buildCashConfirmed(),
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
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _selectCash,
            icon: const Icon(Icons.money),
            label: Text('wallet.pay_cash'.tr()),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _selectElectronic,
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

  Widget _buildCashConfirmed() {
    return _statusBanner(
      Icons.money,
      Colors.orange.shade700,
      'wallet.dropoff_cash_selected'.tr(),
    );
  }

  Widget _buildElectronicForm() {
    if (_loadingMethods) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('wallet.select_payment_method'.tr()),
        const SizedBox(height: 8),
        ..._methods.map((m) => RadioListTile<PaymentMethod>(
              value: m,
              groupValue: _selectedMethod,
              onChanged: (v) => setState(() => _selectedMethod = v),
              title: Text(m.name ?? m.code),
              subtitle: m.description != null ? Text(m.description!) : null,
            )),
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
            onPressed: _initiating ? null : () => _initiatePayment(),
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
          onPressed: () => setState(() => _mode = DropOffPaymentMode.choose),
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
        if (_customerMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _customerMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
          ),
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
