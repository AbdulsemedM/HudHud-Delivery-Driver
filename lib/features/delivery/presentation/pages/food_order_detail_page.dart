import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/models/driver_food_order.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/services/notification_service.dart';
import 'package:hudhud_delivery_driver/core/utils/app_currency.dart';
import 'package:hudhud_delivery_driver/core/utils/driver_error_messages.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';
import 'package:hudhud_delivery_driver/core/utils/phone_launcher.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/widgets/gift_delivery_code_card.dart';

typedef StartFoodOrder = Future<Map<String, dynamic>> Function(
  int orderId, {
  String? pickupOtp,
});
typedef CompleteFoodOrder = Future<Map<String, dynamic>> Function(
  int orderId, {
  String? deliveryOtp,
  File? proofPhoto,
  String? customerUnavailableReason,
});

/// Food / gift order assigned to the driver (DriverController lifecycle:
/// start → complete).
///
/// Gift orders (Phase 6) show "Gift — deliver to <recipient>" and call / SMS
/// the recipient. When the order says `delivery_otp_required`, or the API
/// answers INVALID_DELIVERY_OTP, the driver enters the recipient's 4-digit
/// code; DELIVERY_OTP_LOCKED (5 wrong codes / 15 min) locks the entry.
///
/// Ordinary orders can need the same 4-digit code, and the difference is
/// where it comes from: a gift recipient was SENT theirs, while for any other
/// order the rider taps "ask for code" and the CUSTOMER reads it off their own
/// app screen. Nothing is sent in that case, so there is no SMS that can fail
/// to arrive and leave the rider stuck at the door. The rider never sees the
/// digits - if this app received them the code would prove nothing.
///
/// `delivery_photo_required` additionally demands a photo at the door
/// (422 DELIVERY_PROOF_REQUIRED), and a customer who cannot show the code at
/// all is completed through "customer unavailable", which still costs a photo
/// and a reason and is recorded server-side so the overrides are countable.
///
/// Phase 10: an order the system dispatched before it was ready may still be
/// `preparing` (shown as "still cooking") and may need the restaurant's
/// 4-digit pickup code at start (`pickup_otp_required`, 422 INVALID_PICKUP_OTP).
class FoodOrderDetailPage extends StatefulWidget {
  const FoodOrderDetailPage({
    super.key,
    required this.order,
    this.startOrder,
    this.completeOrder,
    this.requestDeliveryCode,
  });

  final DriverFoodOrder order;

  /// Overridable for tests; default is [ApiService.startFoodOrder].
  final StartFoodOrder? startOrder;

  /// Overridable for tests; default is [ApiService.completeFoodOrder].
  final CompleteFoodOrder? completeOrder;

  /// Overridable for tests; default is [ApiService.requestDeliveryCode].
  final Future<Map<String, dynamic>> Function(int)? requestDeliveryCode;

  static const Color brandOrange = Color(0xFFF55905);

  @override
  State<FoodOrderDetailPage> createState() => _FoodOrderDetailPageState();
}

class _FoodOrderDetailPageState extends State<FoodOrderDetailPage>
    with WidgetsBindingObserver {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _pickupController = TextEditingController();
  late DriverFoodOrder _order;
  bool _showPickupCode = false;
  String? _pickupError;
  bool _busy = false;
  bool _showCode = false;
  bool _codeLocked = false;
  String? _codeError;

  /// Wrong codes sent from this screen. The API does not return a remaining
  /// count, so "tries left" is counted here against its limit of 5.
  int _wrongCodes = 0;

  /// The photo taken at the door. Sent as multipart on completion.
  File? _proofPhoto;

  /// True once the server has issued a code for this order, so the rider is
  /// told to ask the customer rather than being offered the button again.
  bool _codeIssued = false;
  bool _askingForCode = false;

  /// An order cancelled or unassigned on the portal drops off
  /// GET /driver/orders/active; re-check so the driver is not left on a
  /// screen whose every action fails. Pushes trigger an immediate check.
  static const Duration _assignmentCheckInterval = Duration(seconds: 20);
  Timer? _assignmentTimer;
  bool _checkingAssignment = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    // NOT `isGift && ...` any more: delivery_otp_required now covers an
    // ordinary order whose customer reads the code from their own app, and
    // that order needs the same entry field. `isGift` only decides whether
    // the rider has to ask for a code first.
    _showCode = _order.deliveryOtpRequired;
    _showPickupCode = _order.canStart && _order.pickupOtpRequired;
    WidgetsBinding.instance.addObserver(this);
    if (getIt.isRegistered<NotificationService>()) {
      getIt<NotificationService>().homeRefreshTick.addListener(_onPush);
    }
    _assignmentTimer = Timer.periodic(
      _assignmentCheckInterval,
      (_) => unawaited(_closeIfNoLongerAssigned()),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_closeIfNoLongerAssigned());
    }
  }

  void _onPush() => unawaited(_closeIfNoLongerAssigned());

  /// Returns true when the page was closed because the order is gone.
  /// Errors (offline, 5xx) never close it.
  Future<bool> _closeIfNoLongerAssigned() async {
    if (_closing || _checkingAssignment || !mounted) return _closing;
    // Mid start / complete: a just-completed order also leaves the active
    // list, which must not read as "cancelled".
    if (_busy) return false;
    if (!getIt.isRegistered<ApiService>()) return false;
    _checkingAssignment = true;
    try {
      final orders = await getIt<ApiService>().getActiveFoodOrders();
      if (!mounted || orders.any((o) => o.id == _order.id)) return false;
      _closeForEndedOrder();
      return true;
    } catch (_) {
      return false;
    } finally {
      _checkingAssignment = false;
    }
  }

  void _closeForEndedOrder() {
    if (_closing || !mounted) return;
    _closing = true;
    _assignmentTimer?.cancel();
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text(
          'This order was cancelled or is no longer assigned to you.',
        ),
        backgroundColor: Colors.orange.shade800,
      ),
    );
    final navigator = Navigator.of(context);
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      navigator.popUntil((r) => r == route);
    }
    navigator.pop(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (getIt.isRegistered<NotificationService>()) {
      getIt<NotificationService>().homeRefreshTick.removeListener(_onPush);
    }
    _assignmentTimer?.cancel();
    _codeController.dispose();
    _pickupController.dispose();
    super.dispose();
  }

  StartFoodOrder get _start =>
      widget.startOrder ?? getIt<ApiService>().startFoodOrder;

  CompleteFoodOrder get _complete =>
      widget.completeOrder ?? getIt<ApiService>().completeFoodOrder;

  Future<Map<String, dynamic>> Function(int) get _requestCode =>
      widget.requestDeliveryCode ?? getIt<ApiService>().requestDeliveryCode;

  String get _contactName {
    final name = _order.contactName;
    if (name != null) return name;
    return _order.isGift ? 'gift.recipient'.tr() : 'gift.customer'.tr();
  }

  void _snack(String message, {bool error = false, VoidCallback? retry}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : null,
        duration: Duration(seconds: retry != null ? 8 : 4),
        action: retry == null
            ? null
            : SnackBarAction(
                label: 'common.retry'.tr(),
                textColor: Colors.white,
                onPressed: retry,
              ),
      ),
    );
  }

  Future<void> _onStart() async {
    if (_busy) return;
    String? pickupCode;
    if (_showPickupCode) {
      pickupCode = _pickupController.text.trim();
      if (!GiftDeliveryCode.isWellFormed(pickupCode)) {
        setState(() => _pickupError = 'gift.code_format'.tr());
        return;
      }
    }
    setState(() {
      _busy = true;
      _pickupError = null;
    });
    try {
      await _start(_order.id, pickupOtp: pickupCode);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _showPickupCode = false;
        _order = _order.withStatus('in_transit', newNextAction: 'complete');
      });
      _snack('gift.started'.tr());
    } on AppException catch (e) {
      if (!mounted) return;
      if (FoodPickupCode.isInvalid(e)) {
        setState(() {
          _busy = false;
          _pickupController.clear();
          _pickupError = pickupCode == null
              ? 'dispatch_offer.pickup_code_required'.tr()
              : 'dispatch_offer.pickup_code_invalid'.tr();
          _showPickupCode = true;
        });
        return;
      }
      setState(() => _busy = false);
      if (await _closeIfNoLongerAssigned()) return;
      if (!mounted) return;
      // Start is safe to repeat (the API keeps an in-transit order as is).
      _snack(
        DriverErrorMessages.message(e, fallbackKey: 'gift.action_failed'),
        error: true,
        retry: DriverErrorMessages.isRetryable(e) ? _onStart : null,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(
        DriverErrorMessages.message(e, fallbackKey: 'gift.action_failed'),
        error: true,
      );
    }
  }

  /// Ask the server to issue the customer's code.
  ///
  /// The response does NOT contain it - the customer reads it off their own
  /// screen. A rider who could see the digits could close a delivery from the
  /// next street over, which is the whole reason the code exists.
  Future<void> _askForCode() async {
    if (_askingForCode || _busy) return;
    setState(() {
      _askingForCode = true;
      _codeError = null;
    });
    try {
      await _requestCode(_order.id);
      if (!mounted) return;
      setState(() {
        _askingForCode = false;
        _codeIssued = true;
        _showCode = true;
        // A new code resets the server's attempt counter, so the entry must
        // not stay locked from a previous one.
        _codeLocked = false;
        _wrongCodes = 0;
      });
      _codeController.clear();
      _snack('gift.code_sent_to_customer'.tr());
    } catch (e) {
      if (!mounted) return;
      setState(() => _askingForCode = false);
      _snack(
        DriverErrorMessages.message(e, fallbackKey: 'gift.code_request_failed'),
        error: true,
        retry: DriverErrorMessages.isRetryable(e) ? _askForCode : null,
      );
    }
  }

  /// The photo at the door. Camera only: a gallery pick is not proof of
  /// having been there.
  Future<void> _capturePhoto() async {
    if (_busy) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;
      setState(() => _proofPhoto = File(picked.path));
    } catch (e) {
      if (!mounted) return;
      _snack('gift.photo_failed'.tr(), error: true);
    }
  }

  /// The customer cannot show the code - flat battery, an old app build, a
  /// doorman taking the order. The server still demands the photo and a
  /// reason and records the override, so this is a documented exception
  /// rather than a way round the code.
  Future<void> _completeUnavailable() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text('gift.unavailable_title'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('gift.unavailable_prompt'.tr()),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 255,
                decoration: InputDecoration(
                  hintText: 'gift.unavailable_hint'.tr(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('gift.unavailable_cancel'.tr()),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: Text('gift.unavailable_confirm'.tr()),
            ),
          ],
        );
      },
    );

    if (reason == null || reason.isEmpty || !mounted) return;

    if (_proofPhoto == null) {
      await _capturePhoto();
      if (!mounted || _proofPhoto == null) {
        _snack('gift.photo_required'.tr(), error: true);
        return;
      }
    }

    await _onComplete(unavailableReason: reason);
  }

  Future<void> _onComplete({String? unavailableReason}) async {
    if (_busy || (_codeLocked && unavailableReason == null)) return;
    final overriding = unavailableReason != null && unavailableReason.isNotEmpty;
    String? code;

    // No code is read when the customer could not show one; the override
    // carries the photo and the reason instead.
    if (_showCode && !overriding) {
      code = _codeController.text.trim();
      if (!GiftDeliveryCode.isWellFormed(code)) {
        setState(() => _codeError = 'gift.code_format'.tr());
        return;
      }
    }

    // Asked for here rather than refused by the server, so the rider is not
    // sent back to the start of the screen for a missing photo.
    if (_order.deliveryPhotoRequired && _proofPhoto == null) {
      await _capturePhoto();
      if (!mounted) return;
      if (_proofPhoto == null) {
        setState(() => _codeError = 'gift.photo_required'.tr());
        return;
      }
    }

    setState(() {
      _busy = true;
      _codeError = null;
    });
    try {
      await _complete(
        _order.id,
        deliveryOtp: code,
        proofPhoto: _proofPhoto,
        customerUnavailableReason: overriding ? unavailableReason : null,
      );
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
          case GiftDeliveryCodeError.proofRequired:
            // The photo is normally asked for before the request is sent;
            // this covers the setting being switched on mid-delivery.
            _codeError = 'gift.photo_required'.tr();
            break;
          case null:
            break;
        }
      });
      if (kind == null) {
        if (await _closeIfNoLongerAssigned()) return;
        if (!mounted) return;
        // Lost connection / 503 EXCHANGE_RATE_MISSING: completing again is
        // safe (the API answers "already completed" for a delivered order).
        _snack(
          DriverErrorMessages.message(e, fallbackKey: 'gift.action_failed'),
          error: true,
          retry: DriverErrorMessages.isRetryable(e) ? () => _onComplete() : null,
        );
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
          if (order.canStart && order.waitingForFood) ...[
            _NoteStrip(
              key: const ValueKey('food-order-still-cooking'),
              text: 'dispatch_offer.still_cooking'.tr(),
            ),
            const SizedBox(height: 12),
          ],
          if (order.canStart && _showPickupCode)
            GiftDeliveryCodeCard(
              controller: _pickupController,
              title: 'dispatch_offer.pickup_code_title'.tr(),
              prompt: 'dispatch_offer.pickup_code_prompt'.tr(),
              hint: 'gift.code_hint'.tr(),
              submitLabel: 'gift.start'.tr(),
              errorText: _pickupError,
              locked: false,
              busy: _busy,
              onSubmit: _onStart,
            )
          else if (order.canStart)
            _ActionButton(
              key: const ValueKey('food-order-start'),
              label: 'gift.start'.tr(),
              busy: _busy,
              onPressed: _onStart,
            )
          else if (order.canComplete && _showCode) ...[
            // A gift recipient was sent their code already. For any other
            // order the rider asks, and the customer reads it off their own
            // screen - so this button comes first and the entry follows.
            if (!order.isGift && !_codeIssued)
              _ActionButton(
                key: const ValueKey('food-order-ask-code'),
                label: 'gift.code_ask'.tr(),
                busy: _askingForCode,
                onPressed: _askForCode,
              )
            else
              GiftDeliveryCodeCard(
                controller: _codeController,
                title: 'gift.code_title'.tr(),
                prompt: order.isGift
                    ? 'gift.code_prompt'.tr(namedArgs: {'name': _contactName})
                    : 'gift.code_prompt_in_app'
                        .tr(namedArgs: {'name': _contactName}),
                hint: 'gift.code_hint'.tr(),
                submitLabel: 'gift.code_submit'.tr(),
                errorText: _codeError,
                locked: _codeLocked,
                busy: _busy,
                onSubmit: _onComplete,
              ),
            if (order.deliveryPhotoRequired) _proofRow(),
            // The way out when the customer cannot show the code at all. It
            // still costs a photo and a reason, and the server records it.
            if (_codeIssued || order.isGift)
              TextButton(
                key: const ValueKey('food-order-customer-unavailable'),
                onPressed: _busy ? null : _completeUnavailable,
                child: Text('gift.unavailable_action'.tr()),
              ),
          ]
          else if (order.canComplete) ...[
            if (order.deliveryPhotoRequired) _proofRow(),
            _ActionButton(
              key: const ValueKey('food-order-complete'),
              label: 'gift.complete'.tr(),
              busy: _busy,
              onPressed: _onComplete,
            ),
          ],
        ],
      ),
    );
  }

  /// The photo at the door: take it, then see that it is attached.
  Widget _proofRow() {
    final taken = _proofPhoto != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          if (taken)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                _proofPhoto!,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                // A thumbnail that cannot be decoded must not take the screen
                // down with it; the rider still needs the button beside it.
                errorBuilder: (_, __, ___) => const SizedBox(
                  width: 56,
                  height: 56,
                  child: Icon(Icons.image_not_supported_outlined),
                ),
              ),
            )
          else
            const SizedBox(
              width: 56,
              height: 56,
              child: Icon(Icons.photo_camera_outlined, size: 28),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              taken ? 'gift.photo_attached'.tr() : 'gift.photo_prompt'.tr(),
            ),
          ),
          TextButton(
            key: const ValueKey('food-order-take-photo'),
            onPressed: _busy ? null : _capturePhoto,
            child: Text(
              taken ? 'gift.photo_retake'.tr() : 'gift.photo_take'.tr(),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteStrip extends StatelessWidget {
  const _NoteStrip({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.soup_kitchen_outlined,
              color: FoodOrderDetailPage.brandOrange),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
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
