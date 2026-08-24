import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hudhud_delivery_driver/core/constants/payment_method_codes.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/models/collection_payment_result.dart';
import 'package:hudhud_delivery_driver/core/models/payment_method.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/utils/app_currency.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';
import 'package:hudhud_delivery_driver/core/utils/ethiopian_phone_number.dart';
import 'package:hudhud_delivery_driver/core/utils/payment_details_builder.dart';
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
      type: 'delivery',
      currency: widget.currency.isNotEmpty
          ? widget.currency
          : AppCurrency.code,
    );
    if (!mounted) return;
    setState(() {
      final loaded = methods.isNotEmpty
          ? methods
          : api.defaultDropOffElectronicMethods();
      _methods = PaymentMethodCodes.sortDropOffMethods(
        loaded,
        codeOf: (m) => m.code,
      );
      _loadingMethods = false;
      final selectedCode = _selectedMethod?.code;
      PaymentMethod? nextSelected;
      for (final m in _methods) {
        if (m.code == selectedCode) {
          nextSelected = m;
          break;
        }
      }
      _selectedMethod =
          nextSelected ?? (_methods.isNotEmpty ? _methods.first : null);
    });
  }

  Future<void> _initiateElectronic() async {
    final method = _selectedMethod;
    if (method == null) return;

    if (method.code == PaymentMethodCodes.qpay) {
      if (!method.canInitiateQpay) {
        setState(() {
          _methods = _methods.where((m) => !m.isQpay).toList();
          _selectedMethod = _methods.isNotEmpty ? _methods.first : null;
          _statusMessage = 'wallet.qpay_unavailable'.tr();
        });
        _showSnack(_statusMessage!, isError: true);
        return;
      }
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
      final result = await getIt<ApiService>().collectDeliveryPayment(
        deliveryId: widget.deliveryId,
        collectionMethod: PaymentMethodCodes.collectionMethodFor(method.code),
        paymentPhone: normalizedPhone,
        paymentDetails: paymentDetails,
      );
      if (!mounted) return;
      await _handleCollectResult(result, methodCode: method.code);
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

  Future<void> _initiateQPay() async {
    setState(() {
      _initiating = true;
      _statusMessage = null;
      _pollStatus = null;
    });

    try {
      final result = await getIt<ApiService>().collectDeliveryPayment(
        deliveryId: widget.deliveryId,
        collectionMethod: PaymentMethodCodes.qpay,
      );
      if (!mounted) return;
      await _handleCollectResult(result, methodCode: PaymentMethodCodes.qpay);
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
        await _markConfirmed();
        break;
      case QPayQrSheetResult.failed:
      case QPayQrSheetResult.expired:
        setState(() {
          _mode = _cashFallbackAllowed
              ? DropOffPaymentMode.choose
              : DropOffPaymentMode.electronic;
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

  Future<void> _handleCollectResult(
    CollectionPaymentResult result, {
    String? methodCode,
  }) async {
    if (result.cashFallbackAllowed) {
      _cashFallbackAllowed = true;
    }
    _paymentReference = result.paymentReference ?? _paymentReference;
    _pollStatus = result.status;

    if (result.isSettled) {
      await _markConfirmed(result.message);
      return;
    }

    final isQpay = PaymentMethodCodes.isQpay(methodCode ?? '');
    if (isQpay && result.shouldShowQpayQr) {
      setState(() {
        _mode = DropOffPaymentMode.pending;
        _statusMessage = result.message ?? 'wallet.qpay_waiting'.tr();
      });
      final sheetResult = await showQPayQrSheet(
        context: context,
        deliveryId: widget.deliveryId,
        qrCode: result.qrCode!,
        expiresAt: result.expiresAt,
        paymentId: result.paymentId,
      );
      if (!mounted) return;
      await _handleQpaySheetResult(sheetResult);
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

    if (result.shouldPoll || result.isUssdAction) {
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
      return _buildConfirmed();
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.deepOrange.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildAmountHero(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_mode == DropOffPaymentMode.choose) _buildChoiceButtons(),
                if (_mode == DropOffPaymentMode.cash) _buildCashConfirm(),
                if (_mode == DropOffPaymentMode.electronic)
                  _buildElectronicForm(),
                if (_mode == DropOffPaymentMode.pending) _buildPending(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountHero() {
    final amount = AppCurrency.format(
      widget.amount,
      currency: widget.currency,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.deepOrange.shade600,
            Colors.orange.shade500,
            const Color(0xFFFFB347),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.payments_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'wallet.dropoff_payment_title'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Amount due',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 12,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'wallet.ask_recipient_payment'.tr(),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Pick how they will settle this delivery.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        if (_statusMessage != null) ...[
          const SizedBox(height: 10),
          _hintBanner(_statusMessage!),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _choiceTile(
                title: 'wallet.pay_cash'.tr(),
                subtitle: 'Collect notes in hand',
                icon: Icons.payments_outlined,
                accent: Colors.teal,
                onTap: _initiating ? null : _selectCash,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _choiceTile(
                title: 'Mobile',
                subtitle: 'QR or USSD',
                icon: Icons.qr_code_2_rounded,
                accent: Colors.deepOrange,
                highlighted: true,
                onTap: _initiating ? null : _selectElectronic,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _choiceTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required VoidCallback? onTap,
    bool highlighted = false,
  }) {
    return Material(
      color: highlighted ? accent.withOpacity(0.08) : Colors.grey.shade50,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: highlighted
                  ? accent.withOpacity(0.45)
                  : Colors.grey.shade200,
              width: highlighted ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: 26),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCashConfirm() {
    final amount = AppCurrency.format(
      widget.amount,
      currency: widget.currency,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.teal.shade100),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.handshake_outlined, color: Colors.teal.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'I confirm I received $amount in cash from the recipient.',
                  style: TextStyle(
                    color: Colors.teal.shade900,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _primaryAction(
          label: 'Confirm cash received',
          onPressed: _initiating ? null : _confirmCashReceived,
          loading: _initiating,
        ),
        _backButton(),
      ],
    );
  }

  Widget _buildElectronicForm() {
    if (_loadingMethods) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final needsPhone = _selectedMethod != null &&
        PaymentMethodCodes.requiresPhone(_selectedMethod!.code);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'wallet.select_payment_method'.tr(),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade900,
          ),
        ),
        const SizedBox(height: 12),
        ..._methods.map(_methodTile),
        if (needsPhone) ...[
          const SizedBox(height: 14),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'wallet.payment_phone'.tr(),
              hintText: 'wallet.payment_phone_hint'.tr(),
              prefixIcon: const Icon(Icons.smartphone_outlined),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ],
        if (_statusMessage != null) ...[
          const SizedBox(height: 10),
          _hintBanner(_statusMessage!),
        ],
        const SizedBox(height: 16),
        _primaryAction(
          label: _selectedMethod?.isQpay == true
              ? 'Show QPay QR'
              : 'Send USSD request',
          onPressed: _initiating ? null : _initiateElectronic,
          loading: _initiating,
          icon: _selectedMethod?.isQpay == true
              ? Icons.qr_code_2_rounded
              : Icons.send_rounded,
        ),
        _backButton(),
      ],
    );
  }

  Widget _methodTile(PaymentMethod method) {
    final selected = _selectedMethod?.code == method.code;
    final look = _lookFor(method.code);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? look.color.withOpacity(0.08) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => setState(() => _selectedMethod = method),
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? look.color : Colors.grey.shade200,
                width: selected ? 1.8 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: look.color.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(look.icon, color: look.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        look.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        look.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  color: selected ? look.color : Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPending() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Colors.orange.shade400, Colors.deepOrange.shade600],
            ),
          ),
          child: const Padding(
            padding: EdgeInsets.all(18),
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _statusMessage ?? 'wallet.payment_pending'.tr(),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        if (_pollStatus != null) ...[
          const SizedBox(height: 6),
          Text(
            'Status: $_pollStatus',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
        if (_cashFallbackAllowed) ...[
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () {
              _pollTimer?.cancel();
              setState(() => _mode = DropOffPaymentMode.choose);
            },
            icon: const Icon(Icons.payments_outlined),
            label: Text('wallet.pay_cash'.tr()),
          ),
        ],
      ],
    );
  }

  Widget _buildConfirmed() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade600, Colors.teal.shade500],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded, color: Colors.white, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paid',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _statusMessage ?? 'wallet.payment_confirmed'.tr(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.92),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryAction({
    required String label,
    required VoidCallback? onPressed,
    required bool loading,
    IconData? icon,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon ?? Icons.check_rounded),
        label: Text(
          loading ? '' : label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepOrange.shade600,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _backButton() {
    return TextButton.icon(
      onPressed: _initiating
          ? null
          : () => setState(() => _mode = DropOffPaymentMode.choose),
      icon: const Icon(Icons.arrow_back_rounded, size: 18),
      label: Text('common.back'.tr()),
    );
  }

  Widget _hintBanner(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.deepOrange.shade800,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  _MethodLook _lookFor(String code) {
    switch (code) {
      case PaymentMethodCodes.qpay:
        return const _MethodLook(
          title: 'QPay',
          subtitle: 'Receiver scans a QR code',
          icon: Icons.qr_code_2_rounded,
          color: Color(0xFF6D28D9),
        );
      case PaymentMethodCodes.ebirrCoop:
        return const _MethodLook(
          title: 'eBirr Coop',
          subtitle: 'USSD on the recipient phone',
          icon: Icons.account_balance_rounded,
          color: Color(0xFF0F766E),
        );
      case PaymentMethodCodes.ebirrKaafi:
        return const _MethodLook(
          title: 'eBirr Kaafi',
          subtitle: 'USSD on the recipient phone',
          icon: Icons.phone_iphone_rounded,
          color: Color(0xFFEA580C),
        );
      case PaymentMethodCodes.sahay:
        return const _MethodLook(
          title: 'Sahay',
          subtitle: 'USSD on the recipient phone',
          icon: Icons.bolt_rounded,
          color: Color(0xFF2563EB),
        );
      default:
        return _MethodLook(
          title: code,
          subtitle: 'Mobile payment',
          icon: Icons.wallet_rounded,
          color: Colors.blueGrey.shade700,
        );
    }
  }
}

class _MethodLook {
  const _MethodLook({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
}
