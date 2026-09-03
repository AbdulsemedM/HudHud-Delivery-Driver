import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/models/delivery_otp.dart';
import 'package:hudhud_delivery_driver/core/models/delivery_pricing.dart';
import 'package:hudhud_delivery_driver/core/models/driver_earnings_summary.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/services/location_service.dart';
import 'package:hudhud_delivery_driver/core/utils/app_currency.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/widgets/delivery_payment_collection_card.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/widgets/slide_to_confirm_button.dart';

class DeliveryCompletionPage extends StatefulWidget {
  const DeliveryCompletionPage({
    super.key,
    required this.deliveryId,
    this.estimatedDistance,
    this.estimatedDuration,
    this.estimatedCost,
    this.pickupLocation,
    this.dropoffLocation,
    this.otpRequired = true,
    this.resumeOtp = false,
    this.otpDigitLength = DeliveryOtp.defaultDigitLength,
    this.initialAttemptsRemaining,
    this.initialLocked = false,
    this.receiverPhone,
  });

  final int deliveryId;
  final double? estimatedDistance;
  final int? estimatedDuration;
  final double? estimatedCost;
  final String? pickupLocation;
  final String? dropoffLocation;
  final bool otpRequired;
  final bool resumeOtp;
  final int otpDigitLength;
  final int? initialAttemptsRemaining;
  final bool initialLocked;
  final String? receiverPhone;

  @override
  State<DeliveryCompletionPage> createState() => _DeliveryCompletionPageState();
}

class _DeliveryCompletionPageState extends State<DeliveryCompletionPage> {
  bool _loading = true;
  bool _submitting = false;
  bool _resending = false;
  String? _error;

  double? _distance;
  int? _duration;
  double? _fare;
  String? _pickupLocation;
  String? _dropoffLocation;
  DeliveryEarningBreakdown? _earningBreakdown;

  late int _digitLength;
  int? _attemptsRemaining;
  bool _locked = false;
  bool _supportRequired = false;
  int _resendCooldownSeconds = 0;
  Timer? _resendTimer;

  String? _receiverPhone;
  String? _paymentStatus;
  double? _paymentAmount;
  String _paymentCurrency = 'ETB';
  bool _requiresDropOffPayment = false;
  bool _paymentConfirmed = false;
  bool _otpVerified = false;
  bool _verifyingOtp = false;
  bool _cashFallbackAllowed = true;

  late List<TextEditingController> _otpControllers;
  late List<FocusNode> _otpFocusNodes;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _paymentSectionKey = GlobalKey();

  final LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    _digitLength = widget.otpDigitLength;
    _attemptsRemaining = widget.initialAttemptsRemaining;
    _locked = widget.initialLocked;
    _receiverPhone = widget.receiverPhone;
    _distance = widget.estimatedDistance;
    _duration = widget.estimatedDuration;
    _fare = widget.estimatedCost;
    _pickupLocation = widget.pickupLocation;
    _dropoffLocation = widget.dropoffLocation;
    _initOtpFields();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  void _initOtpFields() {
    _otpControllers =
        List.generate(_digitLength, (_) => TextEditingController());
    _otpFocusNodes = List.generate(_digitLength, (_) => FocusNode());
  }

  void _rebuildOtpFields(int length) {
    if (length == _digitLength) return;
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final n in _otpFocusNodes) {
      n.dispose();
    }
    _digitLength = length;
    _initOtpFields();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _scrollController.dispose();
    for (final c in _otpControllers) {
      c.clear();
      c.dispose();
    }
    for (final n in _otpFocusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _otpValue => _otpControllers.map((c) => c.text).join();

  bool get _canComplete {
    if (_submitting || _locked || _loading) return false;
    if (widget.otpRequired && !_otpVerified) return false;
    if (_requiresDropOffPayment && !_paymentConfirmed) return false;
    return true;
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _loadEstimatesFromDetail();
      if (!mounted) return;
      // Fall back to widget estimates or 0 so the screen stays usable.
      _distance ??= widget.estimatedDistance ?? 0;
      _duration ??= widget.estimatedDuration ?? 0;
      _fare ??= widget.estimatedCost;
      setState(() => _loading = false);
      if (widget.otpRequired && !_locked && !_otpVerified) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _otpFocusNodes.isNotEmpty) {
            _otpFocusNodes[0].requestFocus();
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      _distance ??= widget.estimatedDistance ?? 0;
      _duration ??= widget.estimatedDuration ?? 0;
      setState(() {
        _loading = false;
        _error = e is AppException
            ? e.message
            : e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadEstimatesFromDetail() async {
    final delivery =
        await getIt<ApiService>().getDeliveryDetail(widget.deliveryId);
    if (!mounted) return;

    final otp = DeliveryOtp.fromDelivery(delivery);
    if (otp != null) {
      _rebuildOtpFields(otp.digitLength);
      _attemptsRemaining ??= otp.attemptsRemaining;
      _locked = otp.locked;
      _supportRequired = otp.supportRequired;
      if (otp.verified) {
        _otpVerified = true;
      }
    }
    if (!widget.otpRequired) {
      _otpVerified = true;
    }

    final pickup = delivery['pickup'];
    final dropoff = delivery['dropoff'];

    _distance ??= _asDouble(delivery['estimated_distance']);
    _duration ??= _asInt(delivery['estimated_duration']);
    _fare ??= DeliveryPricing.serverQuoteAmount(delivery);
    _earningBreakdown ??= DeliveryEarningBreakdown.fromDelivery(delivery);

    if (pickup is Map && (_pickupLocation == null || _pickupLocation!.isEmpty)) {
      _pickupLocation = pickup['address']?.toString();
    }
    if (dropoff is Map &&
        (_dropoffLocation == null || _dropoffLocation!.isEmpty)) {
      _dropoffLocation = dropoff['address']?.toString();
    }

    _receiverPhone ??= delivery['receiver_phone']?.toString();
    final payment = delivery['payment'];
    if (payment is Map) {
      _paymentStatus = payment['status']?.toString();
      final paymentAmount = _asDouble(payment['amount']);
      if (paymentAmount != null) _paymentAmount = paymentAmount;
      _paymentCurrency = AppCurrency.resolve(payment['currency']?.toString());
    }

    final collectAmount = _asDouble(delivery['collectable_amount']) ??
        _asDouble(delivery['collection_amount']) ??
        _paymentAmount ??
        _fare ??
        0;
    if (_paymentAmount == null && collectAmount > 0) {
      _paymentAmount = collectAmount;
    }

    final statusLower = _paymentStatus?.toLowerCase();
    final collectionStatus = delivery['collection_status']?.toString().toLowerCase() ??
        delivery['settlement_status']?.toString().toLowerCase();
    _paymentConfirmed = statusLower == 'completed' ||
        statusLower == 'paid' ||
        statusLower == 'settled' ||
        collectionStatus == 'settled' ||
        collectionStatus == 'completed';

    final collectionRequiredFlag = delivery['collection_required'] == true ||
        delivery['requires_collection'] == true ||
        delivery['settlement_version']?.toString() == 'v2' ||
        delivery['settlement_v2'] == true;
    _requiresDropOffPayment =
        (collectionRequiredFlag || collectAmount > 0) && !_paymentConfirmed;
    _cashFallbackAllowed =
        delivery['cash_fallback_allowed'] != false;
  }

  void _startResendCooldown(int seconds) {
    _resendTimer?.cancel();
    setState(() => _resendCooldownSeconds = seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _resendCooldownSeconds = 0);
      } else {
        setState(() => _resendCooldownSeconds -= 1);
      }
    });
  }

  Future<void> _resendOtp() async {
    if (_locked || _resending || _resendCooldownSeconds > 0) return;
    setState(() => _resending = true);
    try {
      final res =
          await getIt<ApiService>().resendDeliveryOtp(widget.deliveryId);
      if (!mounted) return;
      final code = res['code']?.toString() ??
          (res['data'] is Map
              ? (res['data'] as Map)['code']?.toString()
              : null);
      final isInApp = code == DeliveryOtp.inAppReadyCode;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isInApp
                ? 'The verification code is ready in the recipient\'s HudHud app. '
                    'Ask them to open the app and share the code when you are physically present.'
                : res['message']?.toString() ??
                    'A new code was sent to the customer by SMS.',
          ),
          backgroundColor: Colors.green,
        ),
      );
      _startResendCooldown(60);
    } catch (e) {
      if (!mounted) return;
      final otpError =
          e is AppException ? DeliveryOtpError.fromException(e) : null;
      if (otpError?.code == DeliveryOtp.inAppReadyCode) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The verification code is ready in the recipient\'s HudHud app. '
              'Ask them to open the app and share the code when you are physically present.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        _startResendCooldown(60);
        return;
      }
      if (otpError?.isResendCooldown == true &&
          otpError!.retryAfterSeconds != null) {
        _startResendCooldown(otpError.retryAfterSeconds!);
      }
      if (otpError?.isLockedOut == true ||
          otpError?.code == DeliveryOtpError.phoneMissingCode) {
        setState(() {
          _locked = true;
          _supportRequired = true;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is AppException
                ? e.message
                : e.toString().replaceFirst('Exception: ', ''),
          ),
          backgroundColor: Colors.orange.shade800,
        ),
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (!widget.otpRequired || _locked || _otpVerified || _verifyingOtp) return;
    if (_otpValue.length < _digitLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter the full $_digitLength-digit code'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _verifyingOtp = true;
      _error = null;
    });

    try {
      await getIt<ApiService>().verifyDeliveryOtp(widget.deliveryId, _otpValue);
      if (!mounted) return;
      setState(() {
        _otpVerified = true;
        _verifyingOtp = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _requiresDropOffPayment
                ? 'Handover verified. Collect payment to enable complete.'
                : 'Handover verified. You can complete the delivery.',
          ),
          backgroundColor: Colors.green,
        ),
      );
      if (_requiresDropOffPayment) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToPaymentSection();
        });
      }
    } catch (e) {
      if (!mounted) return;
      final otpError =
          e is AppException ? DeliveryOtpError.fromException(e) : null;
      if (otpError != null) {
        if (otpError.attemptsRemaining != null) {
          _attemptsRemaining = otpError.attemptsRemaining;
        }
        if (otpError.isLockedOut || otpError.supportRequired) {
          setState(() {
            _locked = true;
            _supportRequired = true;
          });
        }
      }
      setState(() {
        _verifyingOtp = false;
        _error = e is AppException
            ? e.message
            : e.toString().replaceFirst('Exception: ', '');
      });
      _clearOtpFields();
      if (_otpFocusNodes.isNotEmpty) {
        _otpFocusNodes[0].requestFocus();
      }
    }
  }

  void _scrollToPaymentSection() {
    final ctx = _paymentSectionKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        alignment: 0.1,
      );
      return;
    }
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _submitCompletion() async {
    final distance = _distance;
    final duration = _duration;
    if (distance == null || duration == null) {
      setState(
          () => _error = 'Please ensure distance and duration are available');
      return;
    }

    if (widget.otpRequired && !_otpVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verify the recipient OTP before completing delivery.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_requiresDropOffPayment && !_paymentConfirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Collect and settle payment after OTP before completing delivery.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await _locationService.ensureWhenInUseLocation(context);
      final position = await _locationService.getCurrentPositionDetails(
        highAccuracy: true,
      );
      var gpsWarning = false;
      if (widget.otpRequired && position == null) {
        gpsWarning = true;
      }

      final api = getIt<ApiService>();
      final res = await api.completeDeliveryRequest(
        deliveryId: widget.deliveryId,
        actualDistance: distance,
        actualDuration: duration,
        completionLatitude: position?['latitude'] as double?,
        completionLongitude: position?['longitude'] as double?,
        completionAccuracy: position?['accuracy'] as double?,
        completionCapturedAt: position?['recorded_at'] as String?,
      );
      if (!mounted) return;

      if (gpsWarning) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Delivery completed using your last known location. '
              'Enable GPS for more accurate proof of delivery.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }

      await _showSuccessDialog(res);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final otpError =
          e is AppException ? DeliveryOtpError.fromException(e) : null;
      if (otpError != null) {
        if (otpError.attemptsRemaining != null) {
          _attemptsRemaining = otpError.attemptsRemaining;
        }
        if (otpError.isLockedOut || otpError.supportRequired) {
          setState(() {
            _locked = true;
            _supportRequired = true;
            _submitting = false;
          });
          _clearOtpFields();
          return;
        }
      }
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is AppException
                ? e.message
                : e.toString().replaceFirst('Exception: ', ''),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _clearOtpFields() {
    for (final c in _otpControllers) {
      c.clear();
    }
  }

  Future<void> _showSuccessDialog(Map<String, dynamic> res) async {
    final serverFinalCost = _extractServerFinalCost(res);
    final serverPricing = _extractServerPricing(res);
    final earningBreakdown = _extractEarningBreakdown(res);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 56),
        title: const Text('Delivery Completed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              res['message']?.toString() ?? 'Delivery completed successfully.',
            ),
            const SizedBox(height: 12),
            if (_distance != null)
              Text('Distance: ${AppCurrency.formatDecimal(_distance)} km'),
            if (_duration != null) Text('Duration: $_duration min'),
            const SizedBox(height: 10),
            Text(
              serverFinalCost != null
                  ? 'Final amount: ${AppCurrency.format(serverFinalCost)}'
                  : 'Final amount: —',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            ..._earningBreakdownRows(earningBreakdown),
            if (serverPricing?.zone != null ||
                serverPricing?.routeBasis != null) ...[
              const SizedBox(height: 8),
              Text(
                [
                  if (serverPricing?.zone?.name != null)
                    '${serverPricing!.zone!.name}${serverPricing.zone!.version != null ? ' v${serverPricing.zone!.version}' : ''}',
                  if (serverPricing?.routeBasis != null)
                    serverPricing!.routeBasis,
                ].where((s) => s != null && s.toString().isNotEmpty).join(' · '),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _openSupport() {
    context.pushNamed(AppRouter.supportChat);
  }

  void _handleOtpPaste(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    _clearOtpFields();
    for (var i = 0; i < _digitLength && i < digits.length; i++) {
      _otpControllers[i].text = digits[i];
    }
    setState(() {});
    if (digits.length >= _digitLength) {
      FocusScope.of(context).unfocus();
    } else if (digits.length < _digitLength) {
      _otpFocusNodes[digits.length].requestFocus();
    }
  }

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString());
  }

  double? _extractServerFinalCost(Map<String, dynamic> res) {
    final delivery = res['delivery'];
    if (delivery is Map) {
      return _asDouble(delivery['final_cost']);
    }
    return _asDouble(res['final_cost']);
  }

  DeliveryPricing? _extractServerPricing(Map<String, dynamic> res) {
    final delivery = res['delivery'];
    if (delivery is Map) {
      return DeliveryPricing.fromDelivery(Map<String, dynamic>.from(delivery));
    }
    return null;
  }

  DeliveryEarningBreakdown? _extractEarningBreakdown(Map<String, dynamic> res) {
    final delivery = res['delivery'];
    if (delivery is Map) {
      return DeliveryEarningBreakdown.fromDelivery(
        Map<String, dynamic>.from(delivery),
      );
    }
    return null;
  }

  List<Widget> _earningBreakdownRows(DeliveryEarningBreakdown? breakdown) {
    if (breakdown == null) return const [];
    final rows = <Widget>[];
    if (breakdown.platformCommission != null) {
      rows.add(const SizedBox(height: 6));
      rows.add(Text(
        'Platform commission: ${AppCurrency.format(breakdown.platformCommission)}',
      ));
    }
    if (breakdown.driverNetEarning != null) {
      rows.add(Text(
        'Your earning: ${AppCurrency.format(breakdown.driverNetEarning)}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ));
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: _submitting ? null : () => Navigator.pop(context),
        ),
        title: const Text(
          'Complete Delivery',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.orange.shade700),
                    const SizedBox(height: 16),
                    Text(
                      'Loading trip details…',
                      style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_pickupLocation != null || _dropoffLocation != null)
                      _buildRouteCard(),
                    const SizedBox(height: 20),
                    _buildTripDetailsCard(),
                    if (widget.otpRequired) ...[
                      const SizedBox(height: 24),
                      _buildOtpSection(),
                    ],
                    if (_requiresDropOffPayment && _otpVerified) ...[
                      const SizedBox(height: 20),
                      KeyedSubtree(
                        key: _paymentSectionKey,
                        child: DeliveryPaymentCollectionCard(
                          deliveryId: widget.deliveryId,
                          amount: _paymentAmount ?? _fare ?? 0,
                          currency: _paymentCurrency,
                          receiverPhone: _receiverPhone,
                          initialPaymentStatus: _paymentStatus,
                          cashFallbackAllowed: _cashFallbackAllowed,
                          onSettlementSynced: _loadEstimatesFromDetail,
                          onPaymentConfirmed: (confirmed) {
                            setState(() {
                              _paymentConfirmed = confirmed;
                            });
                          },
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      _buildErrorBanner(_error!),
                    ],
                    const SizedBox(height: 24),
                    if (_locked && _supportRequired) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: _openSupport,
                          icon: const Icon(Icons.support_agent),
                          label: const Text('Contact Support'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.deepOrange.shade800,
                            side: BorderSide(color: Colors.deepOrange.shade300),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (widget.otpRequired && !_otpVerified && !_locked) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _verifyingOtp ? null : _verifyOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: _verifyingOtp
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Verify OTP',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SlideToConfirmButton(
                      enabled: _canComplete,
                      loading: _submitting,
                      label: _requiresDropOffPayment &&
                              _otpVerified &&
                              !_paymentConfirmed
                          ? 'Slide after payment'
                          : 'Slide to complete delivery',
                      onConfirmed: _canComplete ? _submitCompletion : null,
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildRouteCard() {
    return Container(
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
        children: [
          if (_pickupLocation != null)
            _buildRouteRow(
              Icons.radio_button_checked,
              Colors.green,
              'Pickup',
              _pickupLocation!,
            ),
          if (_pickupLocation != null && _dropoffLocation != null)
            Padding(
              padding: const EdgeInsets.only(left: 11),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 2,
                  height: 16,
                  color: Colors.grey.shade300,
                ),
              ),
            ),
          if (_dropoffLocation != null)
            _buildRouteRow(
              Icons.location_on,
              Colors.red,
              'Dropoff',
              _dropoffLocation!,
            ),
        ],
      ),
    );
  }

  Widget _buildTripDetailsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
          const Text(
            'Trip Details',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildReadOnlyRow(
            Icons.straighten,
            'Distance',
            _distance != null ? '${AppCurrency.formatDecimal(_distance)} km' : '—',
          ),
          const SizedBox(height: 12),
          _buildReadOnlyRow(
            Icons.schedule,
            'Duration',
            _duration != null ? '$_duration min' : '—',
          ),
          const SizedBox(height: 12),
          _buildReadOnlyRow(
            Icons.payments_outlined,
            'Customer delivery',
            _fare != null
                ? AppCurrency.format(_fare)
                : '—',
          ),
          ..._earningBreakdownRows(_earningBreakdown),
        ],
      ),
    );
  }

  Widget _buildOtpSection() {
    if (_otpVerified) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Text(
          'OTP verified. Proceed to payment collection if required.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.green.shade900,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    final lastIndex = _digitLength - 1;
    final otpEnabled = !_locked;
    return Column(
      children: [
        Icon(Icons.verified_user_outlined,
            size: 56, color: Colors.orange.shade700),
        const SizedBox(height: 16),
        const Text(
          'Customer verification code',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Ask the package recipient for the $_digitLength-digit code '
          'after you have physically arrived at the drop-off location.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            height: 1.5,
          ),
        ),
        if (_attemptsRemaining != null && !_locked) ...[
          const SizedBox(height: 8),
          Text(
            '${_attemptsRemaining!} attempt${_attemptsRemaining == 1 ? '' : 's'} remaining',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        if (_locked) ...[
          const SizedBox(height: 8),
          Text(
            'OTP attempts are locked. Contact support for assistance.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.red.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: 24),
        AutofillGroup(
          onDisposeAction: AutofillContextAction.cancel,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_digitLength, (i) {
              return Container(
                width: _digitLength > 4 ? 48 : 56,
                height: 56,
                margin: EdgeInsets.only(left: i == 0 ? 0 : 6),
                child: TextField(
                  controller: _otpControllers[i],
                  focusNode: _otpFocusNodes[i],
                  enabled: otpEnabled,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 1,
                  enableSuggestions: false,
                  autocorrect: false,
                  autofillHints: const <String>[],
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: _locked ? Colors.grey.shade100 : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.orange.shade700, width: 2),
                    ),
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) {
                    if (value.length > 1) {
                      _handleOtpPaste(value);
                      return;
                    }
                    if (value.isNotEmpty && i < lastIndex) {
                      _otpFocusNodes[i + 1].requestFocus();
                    }
                    if (value.isEmpty && i > 0) {
                      _otpFocusNodes[i - 1].requestFocus();
                    }
                    if (_otpValue.length == _digitLength) {
                      FocusScope.of(context).unfocus();
                    }
                  },
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: (_locked ||
                  _resending ||
                  _resendCooldownSeconds > 0 ||
                  _submitting)
              ? null
              : _resendOtp,
          child: _resending
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.orange.shade700,
                  ),
                )
              : Text(
                  _resendCooldownSeconds > 0
                      ? 'Resend code in ${_resendCooldownSeconds}s'
                      : 'Resend code to customer',
                ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Text(message, style: TextStyle(color: Colors.red.shade800)),
    );
  }

  Widget _buildReadOnlyRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildRouteRow(
    IconData icon,
    Color color,
    String label,
    String location,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                  letterSpacing: 1,
                ),
              ),
              Text(
                location,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
