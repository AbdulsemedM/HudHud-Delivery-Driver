import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/core/auth/application_status_gate.dart';
import 'package:hudhud_delivery_driver/core/constants/application_status.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/models/active_job.dart';
import 'package:hudhud_delivery_driver/core/models/available_driver_requests.dart';
import 'package:hudhud_delivery_driver/core/services/active_delivery_cache.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/services/driver_location_heartbeat.dart';
import 'package:hudhud_delivery_driver/core/services/notification_service.dart';
import 'package:hudhud_delivery_driver/core/models/cod_preview.dart';
import 'package:hudhud_delivery_driver/core/models/delivery_pricing.dart';
import 'package:hudhud_delivery_driver/core/utils/app_currency.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';
import 'package:hudhud_delivery_driver/core/utils/stale_nearby_offer.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/active_job_conflict.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/delivery_otp_accept_feedback.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/pages/available_delivery_map_page.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/widgets/dispatch_message_banner.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/widgets/offer_expiry_chip.dart';
import 'package:hudhud_delivery_driver/features/finance/presentation/widgets/financial_transparency_card.dart';

class AvailableDeliveriesScreen extends StatefulWidget {
  const AvailableDeliveriesScreen({Key? key}) : super(key: key);

  @override
  State<AvailableDeliveriesScreen> createState() => _AvailableDeliveriesScreenState();
}

class _AvailableDeliveriesScreenState extends State<AvailableDeliveriesScreen>
    with WidgetsBindingObserver {
  bool _loading = true;
  List<Map<String, dynamic>> _deliveries = [];
  String? _dispatchMessage;
  int? _acceptingId;
  int? _decliningId;
  ActiveJob? _activeJob;
  Timer? _pollTimer;
  Timer? _locationRefreshDebounce;

  static const Duration _pollInterval = Duration(seconds: 10);
  static const Duration _locationRefreshDebounceDelay = Duration(seconds: 2);

  static int? _parseId(Map<String, dynamic> d) {
    final id = d['id'];
    if (id == null) return null;
    if (id is int) return id;
    return int.tryParse(id.toString());
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDeliveries();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _loadDeliveries(silent: true));
    getIt<NotificationService>().homeRefreshTick.addListener(_onPushRefresh);
    getIt<DriverLocationHeartbeat>().addListener(_onLocationHeartbeat);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _locationRefreshDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    getIt<NotificationService>().homeRefreshTick.removeListener(_onPushRefresh);
    getIt<DriverLocationHeartbeat>().removeListener(_onLocationHeartbeat);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadDeliveries(silent: true);
    }
  }

  void _onPushRefresh() {
    _loadDeliveries(silent: true);
  }

  void _onLocationHeartbeat() {
    _locationRefreshDebounce?.cancel();
    _locationRefreshDebounce = Timer(_locationRefreshDebounceDelay, () {
      _loadDeliveries(silent: true);
    });
  }

  void _stopPoll() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _skipAvailableFetch({ActiveJob? activeJob}) async {
    _stopPoll();
    if (!mounted) return;
    setState(() {
      _deliveries = [];
      _dispatchMessage = null;
      if (activeJob != null) _activeJob = activeJob;
      _loading = false;
    });
  }

  Future<void> _loadDeliveries({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final api = getIt<ApiService>();
      final cachedId = await getIt<ActiveDeliveryCache>().getDeliveryId();
      if (cachedId != null) {
        final profile = await api.getDriverProfile();
        if (!mounted) return;
        await _skipAvailableFetch(
          activeJob: ActiveJob.fromDriverProfile(profile),
        );
        return;
      }

      final profile = await api.getDriverProfile();
      if (!mounted) return;
      final activeJob = ActiveJob.fromDriverProfile(profile);
      if (activeJob?.type == ActiveJobType.delivery) {
        await _skipAvailableFetch(activeJob: activeJob);
        return;
      }

      final requests = await api.getAvailableDeliveryRequests();
      if (!mounted) return;
      final next = requests.deliveries
          .where(DriverDeliveryOffer.shouldShowCard)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final prevIds = _deliveries.map(_parseId).whereType<int>().toSet();
      final nextIds = next.map(_parseId).whereType<int>().toSet();
      final droppedWhileVisible =
          silent && prevIds.isNotEmpty && prevIds.difference(nextIds).isNotEmpty;
      setState(() {
        _deliveries = next;
        _dispatchMessage = requests.dispatch?.message;
        _activeJob = activeJob;
        _loading = false;
      });
      if (droppedWhileVisible && mounted) {
        StaleNearbyOffer.showMessageSnackBar(
          context,
          StaleNearbyOffer.fallbackMessage,
        );
      }
    } catch (e) {
      if (await ApplicationStatusGate.handleForbidden(context, e)) return;
      if (mounted) setState(() {
        if (!silent) _deliveries = [];
        _loading = false;
      });
    }
  }

  void _removeExpiredOffer(int deliveryId) {
    if (!mounted) return;
    setState(() {
      _deliveries.removeWhere((d) => _parseId(d) == deliveryId);
    });
    _loadDeliveries(silent: true);
  }

  Future<void> _openDeliveryMap(Map<String, dynamic> delivery) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AvailableDeliveryMapPage(
          delivery: delivery,
          blockedBy: _activeJob,
        ),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      Navigator.pop(context, true);
      return;
    }
    await _loadDeliveries();
  }

  Future<void> _acceptDelivery(int deliveryId) async {
    if (_activeJob != null) {
      await ActiveJobConflict.show(context, _activeJob);
      return;
    }
    setState(() => _acceptingId = deliveryId);
    try {
      final api = getIt<ApiService>();
      final res = await api.acceptDeliveryRequest(deliveryId);
      if (!mounted) return;
      await getIt<ActiveDeliveryCache>().saveDeliveryId(deliveryId);
      DeliveryOtpAcceptFeedback.showIfNeeded(context, res);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'Delivery accepted'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } on ConflictException catch (e) {
      if (!mounted) return;
      if (e.isActiveJobConflict) {
        setState(() => _activeJob = e.activeJob ?? _activeJob);
        await ActiveJobConflict.show(context, e.activeJob ?? _activeJob);
        if (mounted) await _loadDeliveries();
        return;
      }
      setState(() {
        _deliveries.removeWhere((d) => _parseId(d) == deliveryId);
      });
      StaleNearbyOffer.showInfoSnackBar(context, e);
      await _loadDeliveries();
    } on GoneException catch (e) {
      if (!mounted) return;
      setState(() {
        _deliveries.removeWhere((d) => _parseId(d) == deliveryId);
      });
      StaleNearbyOffer.showInfoSnackBar(context, e);
      await _loadDeliveries();
    } catch (e) {
      if (await ApplicationStatusGate.handleForbidden(context, e)) return;
      if (!mounted) return;
      final message = e is AppException
          ? e.message
          : e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _acceptingId = null);
    }
  }

  Future<void> _declineDelivery(int deliveryId) async {
    setState(() => _decliningId = deliveryId);
    try {
      final api = getIt<ApiService>();
      final res = await api.declineDeliveryRequest(deliveryId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'Delivery declined'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() => _deliveries.removeWhere((d) => _parseId(d) == deliveryId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _decliningId = null);
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
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Available Deliveries',
          style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadDeliveries,
        child: _loading
            ? const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_dispatchMessage != null)
                        DispatchMessageBanner(message: _dispatchMessage!),
                      if (_activeJob != null)
                        ActiveJobConflict.banner(
                          job: _activeJob,
                          onView: () => ActiveJobConflict.openCurrentJob(
                            context,
                            _activeJob!,
                          ),
                        ),
                      if (_deliveries.isEmpty) ...[
                        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                        Icon(Icons.local_shipping_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No available deliveries',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                      ] else
                        ..._deliveries.map((delivery) {
                          return _DeliveryCard(
                            delivery: delivery,
                            onOpen: () => _openDeliveryMap(delivery),
                            onAccept: _acceptDelivery,
                            isAccepting: _acceptingId == _parseId(delivery),
                            onDecline: _declineDelivery,
                            isDeclining: _decliningId == _parseId(delivery),
                            acceptBlocked: _activeJob != null,
                            onOfferExpired: () {
                              final id = _parseId(delivery);
                              if (id != null) _removeExpiredOffer(id);
                            },
                          );
                        }),
                    ],
                  ),
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({
    required this.delivery,
    required this.onOpen,
    required this.onAccept,
    this.isAccepting = false,
    required this.onDecline,
    this.isDeclining = false,
    this.acceptBlocked = false,
    this.onOfferExpired,
  });

  final Map<String, dynamic> delivery;
  final VoidCallback onOpen;
  final void Function(int id) onAccept;
  final bool isAccepting;
  final void Function(int id) onDecline;
  final bool isDeclining;
  final bool acceptBlocked;
  final VoidCallback? onOfferExpired;

  @override
  Widget build(BuildContext context) {
    final packageType = _capitalize(delivery['package_type']?.toString() ?? 'Package');
    final packageDesc = delivery['package_description']?.toString();
    final pickupLocation = delivery['pickup_location']?.toString() ?? '—';
    final dropoffLocation = delivery['dropoff_location']?.toString() ?? '—';
    final senderName = delivery['sender_name']?.toString() ?? '—';
    final receiverName = delivery['receiver_name']?.toString() ?? '—';
    final estimatedCost = DeliveryPricing.serverQuoteAmount(delivery);
    final estimatedDistance = AppCurrency.formatDecimal(
      double.tryParse(delivery['estimated_distance']?.toString() ?? ''),
    );
    final hasEstimatedDistance =
        delivery['estimated_distance'] != null &&
            estimatedDistance != '—';
    final estimatedDuration = delivery['estimated_duration'];
    final serviceType = _capitalize(delivery['service_type']?.toString() ?? '');
    final vehicleType = _capitalize(delivery['vehicle_type']?.toString() ?? '');
    final status = delivery['status']?.toString() ?? 'pending';
    final packageWeight = delivery['package_weight']?.toString();
    final fragile = delivery['fragile'] == true;
    final perishable = delivery['perishable'] == true;
    final requiresSignature = delivery['requires_signature'] == true;
    final specialInstructions = delivery['special_instructions']?.toString();
    final cod = CodPreview.fromDelivery(delivery) ??
        CodAcceptance.fromDelivery(delivery)?.preview;
    final canAccept = DriverDeliveryOffer.canAccept(delivery);
    final expiresAt =
        OfferExpiryChip.tryParse(DriverDeliveryOffer.expiresAtRaw(delivery));

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: package type + status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(_packageIcon(delivery['package_type']?.toString()), size: 20, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Text(
                      packageType,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _capitalize(status.replaceAll('_', ' ')),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _statusColor(status)),
                  ),
                ),
              ],
            ),

            if (packageDesc != null && packageDesc.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                packageDesc,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 12),

            // Badges row: service type, vehicle, weight, flags
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (serviceType.isNotEmpty) _buildBadge(serviceType, Colors.blue),
                if (vehicleType.isNotEmpty) _buildBadge(vehicleType, Colors.indigo),
                if (packageWeight != null) _buildBadge('${packageWeight}kg', Colors.brown),
                if (fragile) _buildBadge('Fragile', Colors.red),
                if (perishable) _buildBadge('Perishable', Colors.teal),
                if (requiresSignature) _buildBadge('Signature', Colors.purple),
                if (expiresAt != null && onOfferExpired != null)
                  OfferExpiryChip(
                    expiresAt: expiresAt,
                    onExpired: onOfferExpired!,
                  ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Pickup
            _buildLocationRow(
              icon: Icons.radio_button_checked,
              iconColor: Colors.green.shade600,
              label: 'PICKUP',
              location: pickupLocation,
              personName: senderName,
            ),

            Padding(
              padding: const EdgeInsets.only(left: 11),
              child: Container(
                width: 2,
                height: 20,
                color: Colors.grey.shade300,
              ),
            ),

            // Dropoff
            _buildLocationRow(
              icon: Icons.location_on,
              iconColor: Colors.red.shade600,
              label: 'DROPOFF',
              location: dropoffLocation,
              personName: receiverName,
            ),

            if (specialInstructions != null && specialInstructions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.amber.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      specialInstructions,
                      style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Estimate row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (hasEstimatedDistance)
                  _buildEstimateTile(Icons.straighten, '$estimatedDistance km'),
                if (estimatedDuration != null)
                  _buildEstimateTile(Icons.schedule, '$estimatedDuration min'),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Customer delivery', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    Text(
                      AppCurrency.format(estimatedCost),
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                    ),
                  ],
                ),
              ],
            ),

            if (cod != null) CodPreviewCompact(cod: cod),

            const SizedBox(height: 14),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isDeclining
                        ? null
                        : () {
                            final id = delivery['id'];
                            if (id == null) return;
                            final parsedId = id is int ? id : int.tryParse(id.toString());
                            if (parsedId != null) onDecline(parsedId);
                          },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: isDeclining
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: isAccepting || !canAccept || acceptBlocked
                        ? null
                        : () {
                            final id = delivery['id'];
                            if (id == null) return;
                            final parsedId = id is int ? id : int.tryParse(id.toString());
                            if (parsedId != null) onAccept(parsedId);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: isAccepting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Accept Delivery'),
                  ),
                ),
              ],
            ),
            if (!canAccept && DriverDeliveryOffer.map(delivery) == null) ...[
              const SizedBox(height: 8),
              Text(
                cod?.blockedMessage ?? StaleNearbyOffer.fallbackMessage,
                style: TextStyle(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Tap card to view on map',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String location,
    required String personName,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade500, letterSpacing: 1)),
              const SizedBox(height: 2),
              Text(location, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(
                personName,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEstimateTile(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(value, style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  static IconData _packageIcon(String? packageType) {
    switch (packageType) {
      case 'document':
        return Icons.description_outlined;
      case 'food':
        return Icons.restaurant_outlined;
      case 'fragile':
        return Icons.warning_amber_outlined;
      case 'electronics':
        return Icons.devices_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'assigned':
      case 'accepted':
        return Colors.blue;
      case 'picked_up':
      case 'in_transit':
        return Colors.indigo;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
