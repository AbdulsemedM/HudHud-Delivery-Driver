import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/core/auth/application_status_gate.dart';
import 'package:hudhud_delivery_driver/core/constants/application_status.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/models/active_job.dart';
import 'package:hudhud_delivery_driver/core/models/available_driver_requests.dart';
import 'package:hudhud_delivery_driver/core/notifications/job_offer_alert_sound_service.dart';
import 'package:hudhud_delivery_driver/core/services/active_delivery_cache.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/services/driver_location_heartbeat.dart';
import 'package:hudhud_delivery_driver/core/services/notification_service.dart';
import 'package:hudhud_delivery_driver/core/models/cod_preview.dart';
import 'package:hudhud_delivery_driver/core/models/delivery_reference.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';
import 'package:hudhud_delivery_driver/core/utils/stale_nearby_offer.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/active_job_conflict.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/delivery_otp_accept_feedback.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/pages/available_delivery_map_page.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/widgets/dispatch_message_banner.dart';

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
    getIt<JobOfferAlertSoundService>().acknowledge();
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
      if (activeJob?.type == ActiveJobType.delivery ||
          activeJob?.type == ActiveJobType.order) {
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
  });

  final Map<String, dynamic> delivery;
  final VoidCallback onOpen;
  final void Function(int id) onAccept;
  final bool isAccepting;
  final void Function(int id) onDecline;
  final bool isDeclining;
  final bool acceptBlocked;

  @override
  Widget build(BuildContext context) {
    final packageType = _capitalize(delivery['package_type']?.toString() ?? 'Package');
    final packageDesc = DeliveryReference.description(delivery);
    final awb = DeliveryReference.awb(delivery);
    final pickupLocation = delivery['pickup_location']?.toString() ?? '—';
    final dropoffLocation = delivery['dropoff_location']?.toString() ?? '—';
    final senderName = delivery['sender_name']?.toString() ?? '—';
    final receiverName = delivery['receiver_name']?.toString() ?? '—';
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

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: package type + status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(_packageIcon(delivery['package_type']?.toString()), size: 16, color: Colors.orange.shade700),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          packageType,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _capitalize(status.replaceAll('_', ' ')),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _statusColor(status)),
                  ),
                ),
              ],
            ),

            if (awb != null) ...[
              const SizedBox(height: 6),
              Text(
                'AWB $awb',
                style: TextStyle(
                  color: Colors.orange.shade900,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],

            if (packageDesc != null && packageDesc.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                packageDesc,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 8),

            // Badges row: service type, vehicle, weight, flags
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                if (serviceType.isNotEmpty) _buildBadge(serviceType, Colors.blue),
                if (vehicleType.isNotEmpty) _buildBadge(vehicleType, Colors.indigo),
                if (packageWeight != null) _buildBadge('${packageWeight}kg', Colors.brown),
                if (fragile) _buildBadge('Fragile', Colors.red),
                if (perishable) _buildBadge('Perishable', Colors.teal),
                if (requiresSignature) _buildBadge('Signature', Colors.purple),
              ],
            ),

            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Pickup
            _buildLocationRow(
              icon: Icons.radio_button_checked,
              iconColor: Colors.green.shade600,
              label: 'PICKUP',
              location: pickupLocation,
              personName: senderName,
            ),

            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Container(
                width: 1.5,
                height: 12,
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
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.amber.shade700),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      specialInstructions,
                      style: TextStyle(fontSize: 11, color: Colors.amber.shade900, fontStyle: FontStyle.italic),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 10),

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
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: isDeclining
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Decline', style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),
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
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: isAccepting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Accept', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
            if (!canAccept && DriverDeliveryOffer.map(delivery) == null) ...[
              const SizedBox(height: 6),
              Text(
                cod?.blockedMessage ?? StaleNearbyOffer.fallbackMessage,
                style: TextStyle(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ],
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
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.grey.shade500, letterSpacing: 0.8)),
              Text(location, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                personName,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
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
