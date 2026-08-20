import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/models/collection_payment_result.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/utils/app_currency.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';
import 'package:hudhud_delivery_driver/core/utils/ethiopian_phone_number.dart';

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

  Future<void> _selectCash() async {
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
    setState(() => _mode = DropOffPaymentMode.electronic);
  }

  Future<void> _initiateEbirr() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showSnack('wallet.phone_required'.tr(), isError: true);
      return;
    }
    final normalized = EthiopianPhoneNumber.tryNormalize(phone);
    if (normalized == null) {
      _showSnack('wallet.invalid_phone'.tr(), isError: true);
      return;
    }

    setState(() {
      _initiating = true;
      _statusMessage = null;
      _pollStatus = null;
    });

    try {
      final result = await getIt<ApiService>().collectDeliveryPayment(
        deliveryId: widget.deliveryId,
        collectionMethod: 'ebirr',
        paymentDetails: {'phone': normalized},
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
          if (_mode == DropOffPaymentMode.cash) _buildCashPending(),
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
            icon: _initiating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.money),
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

  Widget _buildCashPending() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildElectronicForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('wallet.payment_phone'.tr()),
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
            onPressed: _initiating ? null : _initiateEbirr,
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
        if (_cashFallbackAllowed)
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
