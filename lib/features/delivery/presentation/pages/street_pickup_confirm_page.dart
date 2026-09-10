import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/models/delivery_estimate.dart';
import 'package:hudhud_delivery_driver/core/services/active_delivery_cache.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/services/driver_location_heartbeat.dart';
import 'package:hudhud_delivery_driver/core/services/location_service.dart';
import 'package:hudhud_delivery_driver/core/utils/app_currency.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';
import 'package:hudhud_delivery_driver/core/utils/ethiopian_phone_number.dart';
import 'package:hudhud_delivery_driver/core/utils/payment_idempotency.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/pages/street_pickup_form_page.dart';

/// Confirms street-pickup details and creates the order with a sticky idempotency key.
class StreetPickupConfirmPage extends StatefulWidget {
  const StreetPickupConfirmPage({
    super.key,
    required this.draft,
  });

  final StreetPickupDraft draft;

  @override
  State<StreetPickupConfirmPage> createState() =>
      _StreetPickupConfirmPageState();
}

class _StreetPickupConfirmPageState extends State<StreetPickupConfirmPage> {
  late final String _idempotencyKey;
  bool _submitting = false;
  bool _estimating = true;
  DeliveryEstimate? _estimate;
  String? _estimateError;
  String? _pickupLocationLabel;

  @override
  void initState() {
    super.initState();
    // Mint once — retries after timeout reuse this key.
    _idempotencyKey = PaymentIdempotency.streetPickupKey();
    unawaited(_prepareConfirm());
  }

  String get _phoneSuffix {
    final phone = widget.draft.customerPhone;
    final display = EthiopianPhoneNumber.formatForDisplay(phone);
    if (display.length <= 4) return display;
    return '••••${display.substring(display.length - 4)}';
  }

  String get _paymentLabel {
    final code = widget.draft.paymentMethod;
    if (code == 'cash_on_delivery') return 'Cash on delivery';
    return code.replaceAll('_', ' ');
  }

  Future<void> _prepareConfirm() async {
    await _ensureDriverLocationPosted();
    final pickupLabel = await _resolvePickupLocation();
    if (!mounted) return;
    setState(() => _pickupLocationLabel = pickupLabel);
    await _loadEstimate();
  }

  Future<({double lat, double lng})?> _pickupCoords() async {
    final heartbeat = getIt<DriverLocationHeartbeat>().lastLatLng;
    if (heartbeat != null) {
      return (lat: heartbeat.latitude, lng: heartbeat.longitude);
    }
    final pos = await LocationService().getCurrentLocation();
    if (pos == null) return null;
    return (lat: pos.latitude, lng: pos.longitude);
  }

  Future<void> _loadEstimate() async {
    setState(() {
      _estimating = true;
      _estimateError = null;
    });
    try {
      final pickup = await _pickupCoords();
      if (pickup == null) {
        if (!mounted) return;
        setState(() {
          _estimating = false;
          _estimate = null;
          _estimateError =
              'Could not read your GPS. Enable location and retry.';
        });
        return;
      }

      final estimate = await getIt<ApiService>().estimateDelivery(
        pickupLatitude: pickup.lat,
        pickupLongitude: pickup.lng,
        dropoffLatitude: widget.draft.deliveryLatitude,
        dropoffLongitude: widget.draft.deliveryLongitude,
        vehicleType: 'motorbike',
        pickupLocation: _pickupLocationLabel,
      );
      if (!mounted) return;
      setState(() {
        _estimate = estimate;
        _estimating = false;
        _estimateError = null;
      });
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _estimate = null;
        _estimating = false;
        _estimateError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _estimate = null;
        _estimating = false;
        _estimateError = 'Could not calculate fare. Tap retry.';
      });
    }
  }

  Future<String> _resolvePickupLocation() async {
    final draftPickup = widget.draft.pickupLocation?.trim();
    if (draftPickup != null && draftPickup.isNotEmpty) return draftPickup;

    final heartbeat = getIt<DriverLocationHeartbeat>().lastLatLng;
    double? lat = heartbeat?.latitude;
    double? lng = heartbeat?.longitude;
    if (lat == null || lng == null) {
      final pos = await LocationService().getCurrentLocation();
      lat = pos?.latitude;
      lng = pos?.longitude;
    }
    if (lat == null || lng == null) return 'Driver current location';

    try {
      final marks = await placemarkFromCoordinates(lat, lng);
      if (marks.isNotEmpty) {
        final p = marks.first;
        final parts = [
          p.street,
          p.subLocality,
          p.locality,
        ].whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty);
        final address = parts.join(', ');
        if (address.isNotEmpty) return address;
      }
    } catch (_) {}
    return 'Driver current location';
  }

  /// Ensures the backend has a recent driver GPS fix before create.
  Future<bool> _ensureDriverLocationPosted() async {
    final heartbeat = getIt<DriverLocationHeartbeat>();
    final lastPost = heartbeat.lastSuccessfulPostAt;
    if (lastPost != null &&
        DateTime.now().difference(lastPost) < const Duration(minutes: 2)) {
      return true;
    }

    final details = await LocationService().getCurrentPositionDetails(
      highAccuracy: true,
    );
    if (details == null) return false;

    final lat = details['latitude'];
    final lng = details['longitude'];
    if (lat is! num || lng is! num) return false;

    await getIt<ApiService>().updateDriverLocation(
      latitude: lat.toDouble(),
      longitude: lng.toDouble(),
      accuracy: details['accuracy'] is num
          ? (details['accuracy'] as num).toDouble()
          : null,
      speed:
          details['speed'] is num ? (details['speed'] as num).toDouble() : null,
      heading: details['heading'] is num
          ? (details['heading'] as num).round()
          : null,
      altitude: details['altitude'] is num
          ? (details['altitude'] as num).toDouble()
          : null,
      recordedAt: details['recorded_at']?.toString(),
      source: 'street_pickup',
    );
    return true;
  }

  int? _parseOrderId(Map<String, dynamic> data) {
    final order = data['order'];
    if (order is Map) {
      final id = order['id'];
      if (id is int) return id;
      return int.tryParse(id?.toString() ?? '');
    }
    final id = data['id'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '');
  }

  Future<void> _submit() async {
    if (_submitting || _estimate == null) return;
    setState(() => _submitting = true);

    try {
      final locationOk = await _ensureDriverLocationPosted();
      if (!locationOk) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not read your GPS. Enable location and try again.',
            ),
          ),
        );
        return;
      }

      final pickupLocation =
          _pickupLocationLabel ?? await _resolvePickupLocation();
      final api = getIt<ApiService>();
      final data = await api.createStreetPickupOrder(
        customerPhone: widget.draft.customerPhone,
        deliveryLocation: widget.draft.deliveryLocation,
        deliveryLatitude: widget.draft.deliveryLatitude,
        deliveryLongitude: widget.draft.deliveryLongitude,
        idempotencyKey: _idempotencyKey,
        clientReference: _idempotencyKey,
        pickupLocation: pickupLocation,
        paymentMethod: widget.draft.paymentMethod,
        totalAmount: _estimate!.estimatedCost,
      );

      final orderId = _parseOrderId(data);
      if (orderId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order created but id was missing. Refresh home.'),
          ),
        );
        return;
      }

      await getIt<ActiveDeliveryCache>().saveDeliveryId(orderId);
      if (!mounted) return;
      final order = data['order'];
      if (order is Map) {
        Navigator.of(context).pop(Map<String, dynamic>.from(order));
      } else {
        Navigator.of(context).pop(<String, dynamic>{'id': orderId});
      }
    } on AppException catch (e) {
      if (!mounted) return;
      final message = _friendlyMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      // Timeout / network uncertainty: keep the same idempotency key for retry.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is TimeoutException
                ? 'Request timed out. Tap Create again to retry safely.'
                : 'Something went wrong. You can retry safely.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _friendlyMessage(AppException e) {
    final details = e.details;
    if (details is Map) {
      final errors = details['errors'];
      if (errors is Map) {
        if (errors.containsKey('customer_phone') ||
            errors.containsKey('driver_location')) {
          final field = errors.containsKey('driver_location')
              ? 'driver_location'
              : 'customer_phone';
          final value = errors[field];
          if (value is List && value.isNotEmpty) return value.first.toString();
          if (value != null) return value.toString();
        }
      }
    }
    final lower = e.message.toLowerCase();
    if (lower.contains('driver_location') ||
        lower.contains('location update')) {
      return 'Send your location first — go online and wait a moment, then retry.';
    }
    if (lower.contains('phone') || lower.contains('customer')) {
      return e.message;
    }
    if (e is TooManyRequestsException) {
      return 'Too many street pickup requests. Please wait and try again.';
    }
    return e.message;
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _estimateSection() {
    if (_estimating) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(child: Text('Calculating fare…')),
          ],
        ),
      );
    }

    if (_estimateError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _estimateError!,
              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _loadEstimate,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry estimate'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange.shade700,
              ),
            ),
          ],
        ),
      );
    }

    final estimate = _estimate;
    if (estimate == null) return const SizedBox.shrink();

    final distance = estimate.estimatedDistance;
    final duration = estimate.estimatedDuration;
    return Column(
      children: [
        if (distance != null) ...[
          _row('Distance', '${distance.toStringAsFixed(1)} km'),
          const Divider(height: 1),
        ],
        if (duration != null) ...[
          _row('Duration', '$duration min'),
          const Divider(height: 1),
        ],
        _row(
          'Amount',
          AppCurrency.format(estimate.estimatedCost,
              currency: estimate.currency),
        ),
        const Divider(height: 1),
        _row('Payment', _paymentLabel),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = !_submitting && !_estimating && _estimate != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm street pickup'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          Text(
            'Review details before creating the order. The customer will be notified.',
            style: TextStyle(color: Colors.grey.shade700, height: 1.35),
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _row('Customer', _phoneSuffix),
                  const Divider(height: 1),
                  _row('Destination', widget.draft.deliveryLocation),
                  const Divider(height: 1),
                  _estimateSection(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canSubmit ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.orange.shade200,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Create street pickup'),
            ),
          ),
        ],
      ),
    );
  }
}
