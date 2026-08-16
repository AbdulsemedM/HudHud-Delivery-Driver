import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';

class DeliveryCompletionPage extends StatefulWidget {
  const DeliveryCompletionPage({
    super.key,
    required this.deliveryId,
    this.estimatedDistance,
    this.estimatedDuration,
    this.estimatedCost,
    this.pickupLocation,
    this.dropoffLocation,
    this.otpRequired = false,
  });

  final int deliveryId;
  final double? estimatedDistance;
  final int? estimatedDuration;
  final double? estimatedCost;
  final String? pickupLocation;
  final String? dropoffLocation;
  final bool otpRequired;

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
  bool _otpRequired = false;

  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    _distance = widget.estimatedDistance;
    _duration = widget.estimatedDuration;
    _fare = widget.estimatedCost;
    _pickupLocation = widget.pickupLocation;
    _dropoffLocation = widget.dropoffLocation;
    _otpRequired = widget.otpRequired;
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapAndComplete());
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

  Future<void> _bootstrapAndComplete() async {
    setState(() {
      _currentStep = _Step.loading;
      _error = null;
    });

    try {
      if (_distance == null || _duration == null || _fare == null) {
        await _loadEstimatesFromDetail();
      }

      if (_distance == null || _duration == null || _fare == null) {
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
    final payment = delivery['payment'];

    _distance ??= _asDouble(delivery['estimated_distance']);
    _duration ??= _asInt(delivery['estimated_duration']);
    _fare ??= _asDouble(delivery['estimated_cost']) ??
        _asDouble(delivery['final_cost']) ??
        (payment is Map ? _asDouble(payment['amount']) : null);

    if (pickup is Map && (_pickupLocation == null || _pickupLocation!.isEmpty)) {
      _pickupLocation = pickup['address']?.toString();
    }
    if (dropoff is Map && (_dropoffLocation == null || _dropoffLocation!.isEmpty)) {
      _dropoffLocation = dropoff['address']?.toString();
    }
    _otpRequired = delivery['otp_required'] == true;
  }

  Future<void> _submitCompletion() async {
    final distance = _distance;
    final duration = _duration;
    final fare = _fare;
    if (distance == null || duration == null || fare == null) {
      setState(() => _error = 'Please ensure distance, duration and fare are available');
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
        finalFare: fare,
      );
      if (!mounted) return;

      if (_otpRequired) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? 'Delivery completed'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _currentStep = _Step.otp;
          _submitting = false;
        });
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _otpFocusNodes[0].requestFocus();
        });
        return;
      }

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 56),
          title: const Text('Delivery Completed'),
          content: Text(
            res['message']?.toString() ?? 'Delivery completed successfully',
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
    if (otp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the full 6-digit OTP'),
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

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 56),
          title: const Text('Delivery Verified'),
          content: Text(res['message']?.toString() ?? 'OTP verified successfully'),
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
                  Icons.attach_money,
                  'Fare',
                  _fare != null ? _fare!.toStringAsFixed(2) : '—',
                ),
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
            'Ask the customer for the 6-digit OTP\nto verify the delivery',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (i) {
              return Container(
                width: 48,
                height: 56,
                margin: EdgeInsets.only(left: i == 0 ? 0 : 8),
                child: TextField(
                  controller: _otpControllers[i],
                  focusNode: _otpFocusNodes[i],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 1,
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
                    if (value.isNotEmpty && i < 5) {
                      _otpFocusNodes[i + 1].requestFocus();
                    }
                    if (value.isEmpty && i > 0) {
                      _otpFocusNodes[i - 1].requestFocus();
                    }
                    if (_otpValue.length == 6) {
                      FocusScope.of(context).unfocus();
                    }
                  },
                ),
              );
            }),
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
                  : const Text('Verify OTP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
