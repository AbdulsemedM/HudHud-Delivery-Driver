import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/models/driver_food_order.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/utils/app_currency.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';
import 'package:hudhud_delivery_driver/core/utils/phone_launcher.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/widgets/gift_delivery_code_card.dart';

typedef StartFoodOrder = Future<Map<String, dynamic>> Function(int orderId);
typedef CompleteFoodOrder = Future<Map<String, dynamic>> Function(
  int orderId, {
  String? deliveryOtp,
});

/// Food / gift order assigned to the driver (DriverController lifecycle:
/// start → complete).
///
/// Gift orders (Phase 6) show "Gift — deliver to <recipient>" and call / SMS
/// the recipient. When the order says `delivery_otp_required`, or the API
/// answers INVALID_DELIVERY_OTP, the driver enters the recipient's 4-digit
/// code; DELIVERY_OTP_LOCKED (5 wrong codes / 15 min) locks the entry.
class FoodOrderDetailPage extends StatefulWidget {
  const FoodOrderDetailPage({
    super.key,
    required this.order,
    this.startOrder,
    this.completeOrder,
  });

  final DriverFoodOrder order;

  /// Overridable for tests; default is [ApiService.startFoodOrder].
  final StartFoodOrder? startOrder;

  /// Overridable for tests; default is [ApiService.completeFoodOrder].
  final CompleteFoodOrder? completeOrder;

  static const Color brandOrange = Color(0xFFF55905);

  @override
  State<FoodOrderDetailPage> createState() => _FoodOrderDetailPageState();
}

class _FoodOrderDetailPageState extends State<FoodOrderDetailPage> {
  final TextEditingController _codeController = TextEditingController();
  late DriverFoodOrder _order;
  bool _busy = false;
  bool _showCode = false;
  bool _codeLocked = false;
  String? _codeError;

  /// Wrong codes sent from this screen. The API does not return a remaining
  /// count, so "tries left" is counted here against its limit of 5.
  int _wrongCodes = 0;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _showCode = _order.isGift && _order.deliveryOtpRequired;
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  StartFoodOrder get _start =>
      widget.startOrder ?? getIt<ApiService>().startFoodOrder;

  CompleteFoodOrder get _complete =>
      widget.completeOrder ?? getIt<ApiService>().completeFoodOrder;

  String get _contactName {
    final name = _order.contactName;
    if (name != null) return name;
    return _order.isGift ? 'gift.recipient'.tr() : 'gift.customer'.tr();
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : null,
      ),
    );
  }

  Future<void> _onStart() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _start(_order.id);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _order = _order.withStatus('in_transit', newNextAction: 'complete');
      });
      _snack('gift.started'.tr());
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(e.message.isNotEmpty ? e.message : 'gift.action_failed'.tr(),
          error: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('gift.action_failed'.tr(), error: true);
    }
  }

  Future<void> _onComplete() async {
    if (_busy || _codeLocked) return;
    String? code;
    if (_showCode) {
      code = _codeController.text.trim();
      if (!GiftDeliveryCode.isWellFormed(code)) {
        setState(() => _codeError = 'gift.code_format'.tr());
        return;
      }
    }
    setState(() {
      _busy = true;
      _codeError = null;
    });
    try {
      await _complete(_order.id, deliveryOtp: code);
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('gift.delivered'.tr());
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final kind = GiftDeliveryCode.classify(e, codeWasSent: code != null);
      setState(() {
        _busy = false;
        switch (kind) {
          case GiftDeliveryCodeError.required:
            _showCode = true;
            _codeError = 'gift.code_required'.tr();
            break;
          case GiftDeliveryCodeError.invalid:
            _wrongCodes += 1;
            _codeController.clear();
            final left = math.max(0, GiftDeliveryCode.maxAttempts - _wrongCodes);
            _codeError = left > 0
                ? 'gift.code_invalid_left'.tr(namedArgs: {'left': '$left'})
                : 'gift.code_invalid'.tr();
            break;
          case GiftDeliveryCodeError.locked:
            _showCode = true;
            _codeLocked = true;
            _codeError = 'gift.code_locked'.tr();
            break;
          case null:
            break;
        }
      });
      if (kind == null) {
        final message = e is AppException && e.message.isNotEmpty
            ? e.message
            : 'gift.action_failed'.tr();
        _snack(message, error: true);
      }
    }
  }

  Future<void> _call() async {
    final ok = await PhoneLauncher.call(_order.contactPhone);
    if (!ok) _snack('gift.no_phone'.tr(), error: true);
  }

  Future<void> _sms() async {
    final ok = await PhoneLauncher.sms(_order.contactPhone);
    if (!ok) _snack('gift.no_phone'.tr(), error: true);
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: Text(
          order.isGift ? 'gift.order_title'.tr() : order.displayNumber,
          style: const TextStyle(color: Colors.black, fontSize: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (order.isGift) ...[
            _GiftHeader(
              text: 'gift.deliver_to'.tr(namedArgs: {'name': _contactName}),
              codeRequired: _showCode,
            ),
            const SizedBox(height: 12),
          ],
          _ContactCard(
            label: order.isGift ? 'gift.recipient'.tr() : 'gift.customer'.tr(),
            name: _contactName,
            phone: order.contactPhone,
            callLabel: order.isGift
                ? 'gift.call_recipient'.tr()
                : 'gift.call_customer'.tr(),
            smsLabel: order.isGift
                ? 'gift.sms_recipient'.tr()
                : 'gift.sms_customer'.tr(),
            onCall: _call,
            onSms: _sms,
          ),
          const SizedBox(height: 12),
          _InfoCard(
            rows: [
              if (order.vendorName != null || order.pickupAddress != null)
                _InfoRow(
                  icon: Icons.storefront_outlined,
                  label: 'gift.pickup'.tr(),
                  value: [order.vendorName, order.pickupAddress]
                      .whereType<String>()
                      .join('\n'),
                ),
              if (order.deliveryAddress != null)
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'gift.dropoff'.tr(),
                  value: order.deliveryAddress!,
                ),
              if (order.deliveryNotes != null)
                _InfoRow(
                  icon: Icons.notes_outlined,
                  label: 'gift.notes'.tr(),
                  value: order.deliveryNotes!,
                ),
              if (order.totalAmount != null)
                _InfoRow(
                  icon: Icons.receipt_long_outlined,
                  label: 'gift.total'.tr(),
                  value: AppCurrency.format(
                    order.totalAmount,
                    currency: order.currency,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (order.canStart)
            _ActionButton(
              key: const ValueKey('food-order-start'),
              label: 'gift.start'.tr(),
              busy: _busy,
              onPressed: _onStart,
            )
          else if (order.canComplete && _showCode)
            GiftDeliveryCodeCard(
              controller: _codeController,
              title: 'gift.code_title'.tr(),
              prompt: 'gift.code_prompt'.tr(namedArgs: {'name': _contactName}),
              hint: 'gift.code_hint'.tr(),
              submitLabel: 'gift.code_submit'.tr(),
              errorText: _codeError,
              locked: _codeLocked,
              busy: _busy,
              onSubmit: _onComplete,
            )
          else if (order.canComplete)
            _ActionButton(
              key: const ValueKey('food-order-complete'),
              label: 'gift.complete'.tr(),
              busy: _busy,
              onPressed: _onComplete,
            ),
        ],
      ),
    );
  }
}

class _GiftHeader extends StatelessWidget {
  const _GiftHeader({required this.text, required this.codeRequired});

  final String text;
  final bool codeRequired;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FoodOrderDetailPage.brandOrange,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.card_giftcard, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (codeRequired)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'gift.code_badge'.tr(),
                style: const TextStyle(
                  color: FoodOrderDetailPage.brandOrange,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.label,
    required this.name,
    required this.phone,
    required this.callLabel,
    required this.smsLabel,
    required this.onCall,
    required this.onSms,
  });

  final String label;
  final String name;
  final String? phone;
  final String callLabel;
  final String smsLabel;
  final VoidCallback onCall;
  final VoidCallback onSms;

  @override
  Widget build(BuildContext context) {
    final hasPhone = phone != null && phone!.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 2),
          Text(
            name,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          if (hasPhone) ...[
            const SizedBox(height: 2),
            Text(phone!, style: TextStyle(color: Colors.grey.shade800)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('food-order-call'),
                  onPressed: hasPhone ? onCall : null,
                  icon: const Icon(Icons.call_outlined),
                  label: Text(callLabel),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('food-order-sms'),
                  onPressed: hasPhone ? onSms : null,
                  icon: const Icon(Icons.sms_outlined),
                  label: Text(smsLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});

  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(row.icon, size: 20, color: Colors.grey.shade700),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(row.value, style: const TextStyle(fontSize: 15)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: busy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: FoodOrderDetailPage.brandOrange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(label, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}
