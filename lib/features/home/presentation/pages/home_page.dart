import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/services/location_service.dart';
import 'package:hudhud_delivery_driver/core/services/secure_storage_service.dart';
import 'package:hudhud_delivery_driver/features/ride/trip_summary_page.dart';
import 'package:hudhud_delivery_driver/features/wallet/earnings_main_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isOnline = false;
  bool _isUpdatingAvailability = false;
  int _availableRides = 14;
  final MapController _mapController = MapController();
  final SecureStorageService _secureStorage = SecureStorageService();
  final LocationService _locationService = LocationService();

  String _userName = 'Driver';
  String _vehicleDisplay = '—';
  String _walletBalance = '0';
  String _walletCurrency = 'USD';
  String? _profilePictureUrl;
  LatLng? _userPosition;

  bool _hasActiveRide = false;
  int? _activeOrderId;
  /// Ride flow: request (new, show Accept/Decline) -> en_route -> arrived (show End Ride)
  String _rideStatus = 'request';

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
        reason: goOnline ? 'Going online for work' : 'Going offline',
      );
      if (!mounted) return;
      setState(() {
        _isOnline = goOnline;
        _isUpdatingAvailability = false;
      });
      if (goOnline) {
        _startActiveRideCheck();
        _startLocationUpdates();
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

  /// When online: check profile for active ride and set _hasActiveRide / _activeOrderId.
  /// Location timer uses this to send full (/api/driver/location) vs simple (/api/driver/driver/location).
  void _startActiveRideCheck() {
    _activeRideCheckTimer?.cancel();
    _checkActiveRideAndSyncLocationUpdates();
    _activeRideCheckTimer = Timer.periodic(_activeRideCheckInterval, (_) => _checkActiveRideAndSyncLocationUpdates());
  }

  void _stopActiveRideCheck() {
    _activeRideCheckTimer?.cancel();
    _activeRideCheckTimer = null;
  }

  Future<void> _checkActiveRideAndSyncLocationUpdates() async {
    if (!_isOnline) return;
    try {
      final profile = await getIt<ApiService>().getDriverProfile();
      if (!mounted || profile == null) return;
      final driverProfile = profile['driver_profile'];
      final hasActiveRide = driverProfile is Map<String, dynamic> &&
          (driverProfile['current_ride_id'] != null || driverProfile['current_delivery_id'] != null);
      int? orderId;
      if (driverProfile is Map<String, dynamic>) {
        final rideId = driverProfile['current_ride_id'];
        final deliveryId = driverProfile['current_delivery_id'];
        if (rideId != null) orderId = rideId is int ? rideId : int.tryParse(rideId.toString());
        if (orderId == null && deliveryId != null) orderId = deliveryId is int ? deliveryId : int.tryParse(deliveryId.toString());
      }
      if (mounted) setState(() {
        _hasActiveRide = hasActiveRide;
        _activeOrderId = orderId;
        if (hasActiveRide && _rideStatus == 'request') _rideStatus = 'request';
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

  Future<void> _sendLocationUpdate() async {
    if (!_isOnline) return;
    final api = getIt<ApiService>();
    if (_hasActiveRide) {
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
            _userName = user['name']?.toString() ?? 'Driver';
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
          // Handle driver_profile null (API may return null until profile is set)
          if (driverProfile == null) {
            _vehicleDisplay = '—';
          }
        });
      } else {
        final name = await _secureStorage.getUserName();
        if (mounted) setState(() => _userName = name ?? 'Driver');
      }
    } catch (_) {
      if (mounted) {
        final name = await _secureStorage.getUserName();
        setState(() => _userName = name ?? 'Driver');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map background
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userPosition ?? const LatLng(0, 0),
              initialZoom: 14,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              // OpenStreetMap tiles (Nominatim / OSM ecosystem)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.hudhud.delivery_driver',
              ),
              // User location marker
              if (_userPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _userPosition!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.blue,
                        size: 40,
                      ),
                      alignment: Alignment.topCenter,
                    ),
                  ],
                ),
              // Attribution required when using OSM / Nominatim
              SimpleAttributionWidget(
                source: Text('OpenStreetMap contributors'),
              ),
            ],
          ),

          // Floating app bar
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
                      // Logo from assets
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/images/sign.png',
                          height: 36,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(Icons.local_shipping, size: 32, color: Colors.deepPurple),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Earnings / wallet chip
                      Expanded(
                        child: Material(
                          color: Colors.deepPurple.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const EarningsMainScreen(),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.account_balance_wallet_outlined, size: 20, color: Colors.deepPurple[700]),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$_walletCurrency $_walletBalance',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.deepPurple[800],
                                    ),
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

          // Directions bar when en route or arrived
          if (_hasActiveRide && (_rideStatus == 'en_route' || _rideStatus == 'arrived'))
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
                    color: Colors.blue.shade700,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _rideStatus == 'arrived' ? Icons.flag : Icons.navigation,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _rideStatus == 'arrived'
                              ? 'You have arrived at your destination'
                              : 'Head northeast',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Bottom control panel card
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _hasActiveRide ? _buildActiveRideCard() : _buildDefaultBottomCard(),
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
            colors: [
              Colors.indigo.shade700,
              Colors.deepPurple.shade700,
            ],
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
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    _isOnline ? 'Go Offline' : 'Go Online',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
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
              Text(
                '$_availableRides Rides available',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.85),
                ),
              ),
              const SizedBox(height: 16),
              Divider(color: Colors.white.withOpacity(0.3), height: 1),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => context.pushNamed(AppRouter.profile),
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white.withOpacity(0.3),
                          backgroundImage: _profilePictureUrl != null && _profilePictureUrl!.isNotEmpty
                              ? NetworkImage(_profilePictureUrl!)
                              : null,
                          child: _profilePictureUrl == null || _profilePictureUrl!.isEmpty
                              ? Text(
                                  _userName.isNotEmpty ? _userName[0].toUpperCase() : 'D',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _vehicleDisplay,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.9),
                            ),
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

  Widget _buildActiveRideCard() {
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
            colors: [
              Colors.indigo.shade700,
              Colors.deepPurple.shade700,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '7 min (4.5KM)',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.95),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Estimated earnings: $currency 550',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Customer', style: TextStyle(fontSize: 12, color: Colors.white70)),
              const SizedBox(height: 6),
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    child: const Text('T', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Tafari Mwangi',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.verified, size: 16, color: Colors.blue.shade200),
                            const SizedBox(width: 4),
                            const Icon(Icons.star, size: 16, color: Colors.amber),
                            const Text(' 5', style: TextStyle(fontSize: 13, color: Colors.white)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Text('Cash', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.95))),
                    ),
                  ),
                ],
              ),
              if (_rideStatus == 'request') ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _hasActiveRide = false;
                            _activeOrderId = null;
                            _rideStatus = 'request';
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white70),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => setState(() => _rideStatus = 'en_route'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.deepPurple.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Accept Request'),
                      ),
                    ),
                  ],
                ),
              ],
              if (_rideStatus == 'en_route') ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => setState(() => _rideStatus = 'arrived'),
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
              if (_rideStatus == 'arrived') ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final completed = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (context) => TripSummaryPage(
                            orderId: _activeOrderId,
                            totalAmount: '220.00',
                            currency: currency,
                            customerName: 'Robert Mwangi',
                            rideDuration: '7 mins 34 Secs',
                          ),
                        ),
                      );
                      if (mounted && completed == true) {
                        setState(() {
                          _hasActiveRide = false;
                          _activeOrderId = null;
                          _rideStatus = 'request';
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.deepPurple.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('End Ride'),
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
