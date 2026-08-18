import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/utils/app_currency.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';
import 'package:hudhud_delivery_driver/core/models/delivery_pricing.dart';
import 'package:hudhud_delivery_driver/core/models/driver_earnings_summary.dart';

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
    this.otpExpiresInMinutes = 10,
  });

  final int deliveryId;
  final double? estimatedDistance;
  final int? estimatedDuration;
  final double? estimatedCost;
  final String? pickupLocation;
  final String? dropoffLocation;

  /// When false, completion finishes without collecting an OTP.
  final bool otpRequired;

  /// Skip the complete API call and open the OTP step (resume after app kill).
  final bool resumeOtp;

  final int otpExpiresInMinutes;

  static const int otpLength = 4;

  @override
  State<DeliveryCompletionPage> createState() => _DeliveryCompletionPageState();
}

enum _Step { loading, summary, otp }

class _DeliveryCompletionPageState extends State<DeliveryCompletionPage> {
  _Step _currentStep = _Step.loading;
  bool _submitting = false;
  String? _error;

  double? _distance;
  int? _duration;
  double? _fare;
  String? _pickupLocation;
  String? _dropoffLocation;
  DeliveryPricing? _pricing;
  DeliveryEarningBreakdown? _earningBreakdown;

  final List<TextEditingController> _otpControllers =
      List.generate(DeliveryCompletionPage.otpLength, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
      List.generate(DeliveryCompletionPage.otpLength, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    _distance = widget.estimatedDistance;
    _duration = widget.estimatedDuration;
    _fare = widget.estimatedCost;
    _pickupLocation = widget.pickupLocation;
    _dropoffLocation = widget.dropoffLocation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.resumeOtp && widget.otpRequired) {
        _showOtpStep();
      } else {
        _bootstrapAndComplete();
      }
    });
  }

  @override
  void dispose() {
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final n in _otpFocusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _otpValue => _otpControllers.map((c) => c.text).join();

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

  void _showOtpStep() {
    if (!mounted) return;
    setState(() {
      _currentStep = _Step.otp;
      _submitting = false;
      _error = null;
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _otpFocusNodes[0].requestFocus();
    });
  }

  Future<void> _finishWithoutOtp(Map<String, dynamic> completionRes) async {
    if (!mounted) return;

    final serverFinalCost = _extractServerFinalCost(completionRes);
    final serverPricing = _extractServerPricing(completionRes);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 56),
        title: const Text('Delivery Completed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(completionRes['message']?.toString() ?? 'Delivery completed successfully.'),
            const SizedBox(height: 12),
            if (_distance != null)
              Text('Distance: ${_distance!.toStringAsFixed(2)} km'),
            if (_duration != null) Text('Duration: $_duration min'),
            const SizedBox(height: 10),
            Text(
              serverFinalCost != null
                  ? 'Final amount: ${AppCurrency.format(serverFinalCost.toStringAsFixed(2))}'
                  : 'Final amount: —',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (serverPricing?.zone != null || serverPricing?.routeBasis != null) ...[
              const SizedBox(height: 8),
              Text(
                [
                  if (serverPricing?.zone?.name != null)
                    '${serverPricing!.zone!.name}${serverPricing.zone!.version != null ? ' v${serverPricing.zone!.version}' : ''}',
                  if (serverPricing?.routeBasis != null) serverPricing!.routeBasis,
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

    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _bootstrapAndComplete() async {
    setState(() {
      _currentStep = _Step.loading;
      _error = null;
    });

    try {
      if (_distance == null || _duration == null) {
        await _loadEstimatesFromDetail();
      }

      if (_distance == null || _duration == null) {
        if (!mounted) return;
        setState(() {
          _error = 'Trip details are unavailable for this delivery.';
          _currentStep = _Step.summary;
        });
        return;
      }

      if (!mounted) return;
      setState(() => _currentStep = _Step.summary);
      await _submitCompletion();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is AppException
            ? e.message
            : e.toString().replaceFirst('Exception: ', '');
        _currentStep = _Step.summary;
      });
    }
  }

  Future<void> _loadEstimatesFromDetail() async {
    final delivery = await getIt<ApiService>().getDeliveryDetail(widget.deliveryId);
    if (!mounted) return;

    final pickup = delivery['pickup'];
    final dropoff = delivery['dropoff'];

    _distance ??= _asDouble(delivery['estimated_distance']);
    _duration ??= _asInt(delivery['estimated_duration']);
    _fare ??= DeliveryPricing.serverQuoteAmount(delivery);
    _pricing = DeliveryPricing.fromDelivery(delivery);
    _earningBreakdown ??= DeliveryEarningBreakdown.fromDelivery(delivery);

    if (pickup is Map && (_pickupLocation == null || _pickupLocation!.isEmpty)) {
      _pickupLocation = pickup['address']?.toString();
    }
    if (dropoff is Map && (_dropoffLocation == null || _dropoffLocation!.isEmpty)) {
      _dropoffLocation = dropoff['address']?.toString();
    }
  }

  Future<void> _submitCompletion() async {
    final distance = _distance;
    final duration = _duration;
    if (distance == null || duration == null) {
      setState(() => _error = 'Please ensure distance and duration are available');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final api = getIt<ApiService>();
      final res = await api.completeDeliveryRequest(
        deliveryId: widget.deliveryId,
        actualDistance: distance,
        actualDuration: duration,
      );
      if (!mounted) return;

      if (!widget.otpRequired) {
        await _finishWithoutOtp(res);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'Delivery completed — enter OTP'),
          backgroundColor: Colors.green,
        ),
      );
      _showOtpStep();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e is AppException
            ? e.message
            : e.toString().replaceFirst('Exception: ', '');
        _currentStep = _Step.summary;
      });
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpValue;
    if (otp.length < DeliveryCompletionPage.otpLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the full 4-digit OTP'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final api = getIt<ApiService>();
      final res = await api.verifyDeliveryOtp(widget.deliveryId, otp);
      if (!mounted) return;

      final serverFinalCost = _extractServerFinalCost(res);
      final serverPricing = _extractServerPricing(res);
      final earningBreakdown = _extractEarningBreakdown(res);

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 56),
          title: const Text('Delivery Verified'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(res['message']?.toString() ?? 'Delivery OTP verified successfully.'),
              const SizedBox(height: 12),
              if (_distance != null)
                Text('Distance: ${_distance!.toStringAsFixed(2)} km'),
              if (_duration != null)
                Text('Duration: $_duration min'),
              const SizedBox(height: 10),
              Text(
                serverFinalCost != null
                    ? 'Final amount: ${AppCurrency.format(serverFinalCost.toStringAsFixed(2))}'
                    : 'Final amount: —',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              ..._earningBreakdownRows(earningBreakdown),
              if (serverPricing?.zone != null || serverPricing?.routeBasis != null) ...[
                const SizedBox(height: 8),
                Text(
                  [
                    if (serverPricing?.zone?.name != null)
                      '${serverPricing!.zone!.name}${serverPricing!.zone!.version != null ? ' v${serverPricing.zone!.version}' : ''}',
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
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
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

  double? _extractServerFinalCost(Map<String, dynamic> res) {
    final delivery = res['delivery'];
    if (delivery is Map) {
      final v = delivery['final_cost'];
      return _asDouble(v);
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
          onPressed: _submitting && _currentStep != _Step.otp
              ? null
              : () => Navigator.pop(context),
        ),
        title: Text(
          _currentStep == _Step.otp ? 'Verify OTP' : 'Complete Delivery',
          style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: _currentStep == _Step.otp
            ? _buildOtpStep()
            : _buildSummaryStep(),
      ),
    );
  }

  Widget _buildSummaryStep() {
    if (_currentStep == _Step.loading || (_submitting && _error == null)) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.orange.shade700),
            const SizedBox(height: 16),
            Text(
              _submitting ? 'Completing delivery…' : 'Loading trip details…',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_pickupLocation != null || _dropoffLocation != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                children: [
                  if (_pickupLocation != null)
                    _buildRouteRow(Icons.radio_button_checked, Colors.green, 'Pickup', _pickupLocation!),
                  if (_pickupLocation != null && _dropoffLocation != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 11),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(width: 2, height: 16, color: Colors.grey.shade300),
                      ),
                    ),
                  if (_dropoffLocation != null)
                    _buildRouteRow(Icons.location_on, Colors.red, 'Dropoff', _dropoffLocation!),
                ],
              ),
            ),

          const SizedBox(height: 20),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Trip Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildReadOnlyRow(
                  Icons.straighten,
                  'Distance',
                  _distance != null ? '${_distance!.toStringAsFixed(2)} km' : '—',
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
                  _fare != null ? AppCurrency.format(_fare!.toStringAsFixed(2)) : '—',
                ),
                ..._earningBreakdownRows(_earningBreakdown),
                if (_pricing?.zone != null || _pricing?.routeBasis != null) ...[
                  const SizedBox(height: 12),
                  _buildReadOnlyRow(
                    Icons.lock_outline,
                    'Rate',
                    [
                      if (_pricing?.zone?.name != null)
                        '${_pricing!.zone!.name}${_pricing!.zone!.version != null ? ' v${_pricing!.zone!.version}' : ''}',
                      if (_pricing?.routeBasis != null) _pricing!.routeBasis,
                    ].where((s) => s != null && s.toString().isNotEmpty).join(' · '),
                  ),
                ],
              ],
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(_error!, style: TextStyle(color: Colors.red.shade800)),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submitting ? null : _bootstrapAndComplete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Retry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOtpStep() {
    final lastIndex = DeliveryCompletionPage.otpLength - 1;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Icon(Icons.verified_user_outlined, size: 64, color: Colors.orange.shade700),
          const SizedBox(height: 20),
          const Text(
            'Enter Verification Code',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask the package recipient for the 4-digit code\n'
            'and enter it below to finish the delivery.\n'
            'Valid while this delivery is active, until verified.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
          ),
          const SizedBox(height: 32),
          AutofillGroup(
            onDisposeAction: AutofillContextAction.cancel,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(DeliveryCompletionPage.otpLength, (i) {
                return Container(
                  width: 56,
                  height: 56,
                  margin: EdgeInsets.only(left: i == 0 ? 0 : 8),
                  child: TextField(
                    controller: _otpControllers[i],
                    focusNode: _otpFocusNodes[i],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    enableSuggestions: false,
                    autocorrect: false,
                    autofillHints: const <String>[],
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.orange.shade700, width: 2),
                      ),
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) {
                      if (value.isNotEmpty && i < lastIndex) {
                        _otpFocusNodes[i + 1].requestFocus();
                      }
                      if (value.isEmpty && i > 0) {
                        _otpFocusNodes[i - 1].requestFocus();
                      }
                      if (_otpValue.length == DeliveryCompletionPage.otpLength) {
                        FocusScope.of(context).unfocus();
                      }
                    },
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _submitting ? null : _verifyOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Verify & Finish Delivery',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
        ),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildRouteRow(IconData icon, Color color, String label, String location) {
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
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
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
