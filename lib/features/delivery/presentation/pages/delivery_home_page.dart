import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/services/location_service.dart';
import 'package:hudhud_delivery_driver/core/services/secure_storage_service.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/pages/available_deliveries_screen.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/pages/delivery_earnings_screen.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/pages/delivery_profile_page.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/pages/delivery_summary_page.dart';

class DeliveryHomePage extends StatefulWidget {
  const DeliveryHomePage({Key? key}) : super(key: key);

  @override
  State<DeliveryHomePage> createState() => _DeliveryHomePageState();
}

class _DeliveryHomePageState extends State<DeliveryHomePage> {
  bool _isOnline = false;
  bool _isUpdatingAvailability = false;
  int _availableDeliveries = 0;
  final MapController _mapController = MapController();
  final SecureStorageService _secureStorage = SecureStorageService();
  final LocationService _locationService = LocationService();

  String _userName = 'Courier';
  String _vehicleDisplay = '—';
  String _walletBalance = '0';
  String _walletCurrency = 'USD';
  String? _profilePictureUrl;
  LatLng? _userPosition;

  bool _hasActiveDelivery = false;
  int? _activeOrderId;
  String _deliveryStatus = 'request';
  bool _isStartingDelivery = false;
  bool _isCancellingOrder = false;

  static const Duration _locationUpdateInterval = Duration(seconds: 15);
  static const Duration _activeRideCheckInterval = Duration(seconds: 30);
  Timer? _locationUpdateTimer;
  Timer? _activeRideCheckTimer;

  @override
  void initState() {
    super.initState();
    _loadDriverProfile();
    _requestAndUseLocation();
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    _activeRideCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _requestAndUseLocation() async {
    final granted = await _locationService.requestLocationPermission();
    if (!mounted) return;
    if (!granted) {
      final status = await Permission.locationWhenInUse.status;
      if (status.isPermanentlyDenied) {
        _locationService.showPermissionSettingsDialog(context);
      }
      return;
    }
    final position = await _locationService.getCurrentLocation();
    if (!mounted) return;
    if (position != null) {
      setState(() => _userPosition = position);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(position, 14);
      });
    }
  }

  Future<void> _setAvailability(bool goOnline) async {
    if (_isUpdatingAvailability) return;
    setState(() => _isUpdatingAvailability = true);
    try {
      final api = getIt<ApiService>();
      final res = await api.updateDriverAvailability(
        isAvailable: goOnline,
        reason: goOnline ? 'Going online for deliveries' : 'Going offline',
      );
      if (!mounted) return;
      setState(() {
        _isOnline = goOnline;
        _isUpdatingAvailability = false;
      });
      if (goOnline) {
        _startActiveRideCheck();
        _startLocationUpdates();
        _refreshAvailableOrdersCount();
      } else {
        _stopActiveRideCheck();
        _stopLocationUpdates();
      }
      final message = res['message']?.toString() ?? (goOnline ? 'You are now online.' : 'You are now offline.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUpdatingAvailability = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _startActiveRideCheck() {
    _activeRideCheckTimer?.cancel();
    _checkActiveDeliveryAndSync();
    _activeRideCheckTimer = Timer.periodic(_activeRideCheckInterval, (_) => _checkActiveDeliveryAndSync());
  }

  void _stopActiveRideCheck() {
    _activeRideCheckTimer?.cancel();
    _activeRideCheckTimer = null;
  }

  Future<void> _checkActiveDeliveryAndSync() async {
    if (!_isOnline) return;
    try {
      final profile = await getIt<ApiService>().getDriverProfile();
      if (!mounted || profile == null) return;
      final driverProfile = profile['driver_profile'];
      final hasActive = driverProfile is Map<String, dynamic> &&
          (driverProfile['current_ride_id'] != null || driverProfile['current_delivery_id'] != null);
      int? orderId;
      if (driverProfile is Map<String, dynamic>) {
        final rideId = driverProfile['current_ride_id'];
        final deliveryId = driverProfile['current_delivery_id'];
        if (rideId != null) orderId = rideId is int ? rideId : int.tryParse(rideId.toString());
        if (orderId == null && deliveryId != null) orderId = deliveryId is int ? deliveryId : int.tryParse(deliveryId.toString());
      }
      if (mounted) setState(() {
        _hasActiveDelivery = hasActive;
        _activeOrderId = orderId;
      });
    } catch (_) {}
  }

  void _startLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _sendLocationUpdate();
    _locationUpdateTimer = Timer.periodic(_locationUpdateInterval, (_) => _sendLocationUpdate());
  }

  void _stopLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
  }

  Future<void> _refreshAvailableOrdersCount() async {
    if (!_isOnline) return;
    try {
      final list = await getIt<ApiService>().getDriverAvailableOrders();
      if (mounted) setState(() => _availableDeliveries = list.length);
    } catch (_) {}
  }

  Future<void> _sendLocationUpdate() async {
    if (!_isOnline) return;
    final api = getIt<ApiService>();
    if (_hasActiveDelivery) {
      final details = await _locationService.getCurrentPositionDetails();
      if (details == null || !mounted) return;
      try {
        await api.updateDriverLocation(
          latitude: details['latitude'] as double,
          longitude: details['longitude'] as double,
          accuracy: details['accuracy'] as double,
          speed: details['speed'] as double,
          heading: details['heading'] as int,
          altitude: details['altitude'] as double,
        );
      } catch (_) {}
    } else {
      final position = await _locationService.getCurrentLocation();
      if (position == null || !mounted) return;
      try {
        await api.updateDriverDriverLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          orderId: _activeOrderId,
        );
      } catch (_) {}
    }
  }

  Future<void> _startDelivery() async {
    if (_activeOrderId == null) return;
    setState(() => _isStartingDelivery = true);
    try {
      final api = getIt<ApiService>();
      final res = await api.startDriverOrder(_activeOrderId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Delivery started'), backgroundColor: Colors.green),
      );
      setState(() => _deliveryStatus = 'en_route');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isStartingDelivery = false);
    }
  }

  Future<void> _cancelOrder() async {
    if (_activeOrderId == null) return;
    setState(() => _isCancellingOrder = true);
    try {
      final api = getIt<ApiService>();
      await api.cancelDriverOrder(_activeOrderId!);
      if (!mounted) return;
      setState(() {
        _hasActiveDelivery = false;
        _activeOrderId = null;
        _deliveryStatus = 'request';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery cancelled'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isCancellingOrder = false);
    }
  }

  Future<void> _loadDriverProfile() async {
    try {
      final api = getIt<ApiService>();
      final profile = await api.getDriverProfile();
      if (!mounted) return;
      if (profile != null) {
        final user = profile['user'];
        final driverProfile = profile['driver_profile'];
        final wallet = profile['wallet'];
        setState(() {
          if (user is Map<String, dynamic>) {
            _userName = user['name']?.toString() ?? 'Courier';
          }
          if (driverProfile is Map<String, dynamic>) {
            final make = driverProfile['vehicle_make']?.toString();
            final model = driverProfile['vehicle_model']?.toString();
            final plate = driverProfile['vehicle_plate_number']?.toString();
            if (make != null && model != null && plate != null) {
              _vehicleDisplay = '$make $model - $plate';
            } else if (plate != null) {
              _vehicleDisplay = plate;
            }
            _profilePictureUrl = driverProfile['profile_picture']?.toString();
          }
          if (wallet is Map<String, dynamic>) {
            final balance = wallet['balance'];
            _walletBalance = balance != null ? balance.toString() : '0';
            if (_walletBalance.contains('.')) {
              final parts = _walletBalance.split('.');
              final frac = parts.length > 1 ? parts[1].padRight(2, '0').substring(0, 2) : '00';
              _walletBalance = '${parts[0]}.$frac';
            }
            _walletCurrency = wallet['currency']?.toString() ?? 'USD';
          }
          if (driverProfile == null) _vehicleDisplay = '—';
        });
      } else {
        final name = await _secureStorage.getUserName();
        if (mounted) setState(() => _userName = name ?? 'Courier');
      }
    } catch (_) {
      if (mounted) {
        final name = await _secureStorage.getUserName();
        setState(() => _userName = name ?? 'Courier');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userPosition ?? const LatLng(0, 0),
              initialZoom: 14,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.hudhud.delivery_driver',
              ),
              if (_userPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _userPosition!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.local_shipping, color: Colors.orange, size: 40),
                      alignment: Alignment.topCenter,
                    ),
                  ],
                ),
              const SimpleAttributionWidget(source: Text('OpenStreetMap contributors')),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/images/sign.png',
                          height: 36,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2, size: 32, color: Colors.orange),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Material(
                          color: Colors.orange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const DeliveryEarningsScreen(),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.account_balance_wallet_outlined, size: 20, color: Colors.orange[700]),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$_walletCurrency $_walletBalance',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.orange[800]),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined),
                        onPressed: () {},
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_hasActiveDelivery && (_deliveryStatus == 'accepted' || _deliveryStatus == 'en_route' || _deliveryStatus == 'arrived'))
            Positioned(
              top: MediaQuery.of(context).padding.top + 56,
              left: 16,
              right: 16,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade700,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _deliveryStatus == 'arrived' ? Icons.flag : _deliveryStatus == 'accepted' ? Icons.check_circle : Icons.navigation,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _deliveryStatus == 'arrived'
                              ? 'You have arrived'
                              : _deliveryStatus == 'accepted'
                                  ? 'Order accepted - start delivery'
                                  : 'En route to destination',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _hasActiveDelivery ? _buildActiveDeliveryCard() : _buildDefaultBottomCard(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultBottomCard() {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.orange.shade700, Colors.deepOrange.shade700],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.white.withOpacity(0.9)),
                  const SizedBox(width: 6),
                  Text(
                    'You are currently offline',
                    style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.9)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    _isOnline ? 'Go Offline' : 'Go Online',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const Spacer(),
                  Switch(
                    value: _isOnline,
                    onChanged: _isUpdatingAvailability ? null : _setAvailability,
                    activeColor: Colors.white,
                    activeTrackColor: Colors.green.shade300,
                  ),
                ],
              ),
              InkWell(
                onTap: _isOnline
                    ? () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const AvailableDeliveriesScreen(),
                          ),
                        );
                        _refreshAvailableOrdersCount();
                      }
                    : null,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        '$_availableDeliveries Deliveries available',
                        style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.85)),
                      ),
                      if (_isOnline) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.chevron_right, size: 18, color: Colors.white.withOpacity(0.85)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Divider(color: Colors.white.withOpacity(0.3), height: 1),
              const SizedBox(height: 16),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const DeliveryProfilePage()),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      backgroundImage: _profilePictureUrl != null && _profilePictureUrl!.isNotEmpty
                          ? NetworkImage(_profilePictureUrl!)
                          : null,
                      child: _profilePictureUrl == null || _profilePictureUrl!.isEmpty
                          ? Text(
                              _userName.isNotEmpty ? _userName[0].toUpperCase() : 'C',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userName,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _vehicleDisplay,
                            style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.9)),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.8)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveDeliveryCard() {
    final currency = _walletCurrency;
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.orange.shade700, Colors.deepOrange.shade700],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Active delivery',
                style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.95)),
              ),
              const SizedBox(height: 8),
              Text(
                'Estimated earnings: $currency 550',
                style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.9)),
              ),
              const SizedBox(height: 12),
              if (_deliveryStatus == 'request') ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isCancellingOrder ? null : _cancelOrder,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white70),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isCancellingOrder
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => setState(() => _deliveryStatus = 'accepted'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.deepOrange.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Accept'),
                      ),
                    ),
                  ],
                ),
              ],
              if (_deliveryStatus == 'accepted') ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isStartingDelivery ? null : _startDelivery,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.deepOrange.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isStartingDelivery
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepOrange.shade700),
                          )
                        : const Text('Start Delivery'),
                  ),
                ),
              ],
              if (_deliveryStatus == 'en_route') ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => setState(() => _deliveryStatus = 'arrived'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Mark Arrived'),
                  ),
                ),
              ],
              if (_deliveryStatus == 'arrived') ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final completed = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (context) => DeliverySummaryPage(
                            orderId: _activeOrderId,
                            totalAmount: '220.00',
                            currency: currency,
                            customerName: 'Customer',
                            rideDuration: '7 mins 34 Secs',
                          ),
                        ),
                      );
                      if (mounted && completed == true) {
                        setState(() {
                          _hasActiveDelivery = false;
                          _activeOrderId = null;
                          _deliveryStatus = 'request';
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.deepOrange.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Complete Delivery'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
