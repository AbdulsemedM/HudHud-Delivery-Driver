import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:go_router/go_router.dart';
import 'package:hudhud_delivery_driver/core/auth/application_status_gate.dart';
import 'package:hudhud_delivery_driver/core/constants/application_status.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/models/available_driver_requests.dart';
import 'package:hudhud_delivery_driver/core/utils/app_currency.dart';
import 'package:hudhud_delivery_driver/core/utils/map_marker_icons.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';
import 'package:hudhud_delivery_driver/core/services/active_delivery_cache.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/services/driver_location_heartbeat.dart';
import 'package:hudhud_delivery_driver/core/services/location_service.dart';
import 'package:hudhud_delivery_driver/core/services/notification_service.dart';
import 'package:hudhud_delivery_driver/core/services/secure_storage_service.dart';
import 'package:hudhud_delivery_driver/features/notifications/presentation/widgets/notifications_bell_button.dart';
import 'package:hudhud_delivery_driver/features/ride_service/presentation/pages/available_rides_screen.dart';
import 'package:hudhud_delivery_driver/features/ride_service/presentation/pages/ride_earnings_screen.dart';
import 'package:hudhud_delivery_driver/features/ride_service/presentation/pages/ride_profile_page.dart';
import 'package:hudhud_delivery_driver/features/ride_service/presentation/pages/trip_summary_page.dart';

class RideHomePage extends StatefulWidget {
  const RideHomePage({Key? key}) : super(key: key);

  @override
  State<RideHomePage> createState() => _RideHomePageState();
}

class _RideHomePageState extends State<RideHomePage> {
  bool _isOnline = false;
  bool _canWork = true;
  bool _isUpdatingAvailability = false;
  int _availableRides = 0;
  GoogleMapController? _googleMapController;
  final SecureStorageService _secureStorage = SecureStorageService();
  final LocationService _locationService = LocationService();

  String _userName = 'Driver';
  String _vehicleDisplay = '—';
  String _walletBalance = '0';
  String _walletCurrency = AppCurrency.code;
  String? _profilePictureUrl;
  latlong.LatLng? _userPosition;

  bool _hasActiveRide = false;
  int? _activeOrderId;
  /// Ride flow: request -> accepted (Start Delivery) -> en_route -> arrived (End Ride)
  String _rideStatus = 'request';
  bool _isStartingDelivery = false;
  bool _isCancellingOrder = false;

  static const Duration _activeRideCheckInterval = Duration(seconds: 30);
  Timer? _activeRideCheckTimer;
  BitmapDescriptor? _deliveryGuyIcon;

  @override
  void initState() {
    super.initState();
    _loadDeliveryGuyMarker();
    _loadWorkPermission();
    _loadDriverProfile();
    _requestAndUseLocation();
    getIt<NotificationService>().homeRefreshTick.addListener(_onPushRefresh);
    getIt<DriverLocationHeartbeat>().addListener(_onHeartbeat);
  }

  Future<void> _loadDeliveryGuyMarker() async {
    final dpr = WidgetsBinding.instance.platformDispatcher.views.isNotEmpty
        ? WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio
        : 2.0;
    final icon = await MapMarkerIcons.deliveryGuy(devicePixelRatio: dpr);
    if (!mounted) return;
    setState(() => _deliveryGuyIcon = icon);
  }

  @override
  void dispose() {
    getIt<NotificationService>().homeRefreshTick.removeListener(_onPushRefresh);
    getIt<DriverLocationHeartbeat>().removeListener(_onHeartbeat);
    _activeRideCheckTimer?.cancel();
    super.dispose();
  }

  void _onPushRefresh() {
    _loadDriverProfile();
    _checkActiveRideAndSyncLocationUpdates();
    _refreshAvailableOrdersCount();
  }

  Future<void> _loadWorkPermission() async {
    final status = await getIt<SecureStorageService>().getApplicationStatus();
    if (!mounted) return;
    setState(() => _canWork = status == null || ApplicationStatus.canWork(status));
  }

  void _stopWorkPolling() {
    _stopActiveRideCheck();
    unawaited(getIt<DriverLocationHeartbeat>().stop());
  }

  void _onHeartbeat() {
    if (!mounted) return;
    final pos = getIt<DriverLocationHeartbeat>().lastLatLng;
    if (pos != null) {
      setState(() => _userPosition = pos);
    }
  }

  Future<bool> _handleWorkForbidden(Object error) async {
    final blocked = await ApplicationStatusGate.handleForbidden(context, error);
    if (!blocked) return false;
    if (!mounted) return true;
    setState(() {
      _canWork = false;
      _isOnline = false;
      _isUpdatingAvailability = false;
    });
    _stopWorkPolling();
    return true;
  }

  Future<void> _requestAndUseLocation() async {
    final permission = await _locationService.ensureWhenInUseLocation(context);
    if (!mounted) return;
    if (!permission.whenInUse) {
      if (await _locationService.isLocationPermissionPermanentlyDenied()) {
        if (!mounted) return;
        _locationService.showPermissionSettingsDialog(context);
      }
      return;
    }
    final position = await _locationService.getCurrentLocation();
    if (!mounted) return;
    if (position != null) {
      setState(() => _userPosition = position);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _googleMapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(position.latitude, position.longitude),
            14,
          ),
        );
      });
    }
  }

  Future<void> _setAvailability(bool goOnline) async {
    if (_isUpdatingAvailability) return;
    if (goOnline && !_canWork) return;
    if (goOnline) {
      final enabled = await _locationService.isLocationServiceEnabled();
      if (!mounted) return;
      if (!enabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Turn on location services to go online.'),
          ),
        );
        return;
      }
      final whenInUse =
          await _locationService.ensureWhenInUseLocation(context);
      if (!mounted) return;
      if (!whenInUse.whenInUse) {
        _locationService.showPermissionSettingsDialog(context);
        return;
      }
      final permission =
          await _locationService.requestBackgroundLocationIfNeeded(
        context,
        userInitiated: true,
      );
      if (!mounted) return;
      if (!permission.always) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Allow location Always so nearby offers continue when the app is in the background.',
            ),
          ),
        );
      }
    }
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
        unawaited(getIt<DriverLocationHeartbeat>().start(
          highAccuracy: _hasActiveRide,
        ));
        _refreshAvailableOrdersCount();
      } else {
        _stopWorkPolling();
      }
      final message = res['message']?.toString() ?? (goOnline ? 'You are now online.' : 'You are now offline.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (await _handleWorkForbidden(e)) return;
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
      final api = getIt<ApiService>();
      try {
        final status = await api.getDriverCurrentStatus();
        if (!mounted) return;
        final rideId = status.rideId;
        final hasActive = rideId != null || status.deliveryId != null;
        setState(() {
          _hasActiveRide = hasActive;
          _activeOrderId = rideId ?? status.deliveryId;
        });
        unawaited(getIt<DriverLocationHeartbeat>().setHighAccuracy(hasActive));
        return;
      } catch (_) {
        // Fall through to profile recovery.
      }

      final profile = await api.getDriverProfile();
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
      unawaited(getIt<DriverLocationHeartbeat>().setHighAccuracy(hasActiveRide));
    } catch (_) {}
  }

  Future<void> _refreshAvailableOrdersCount() async {
    if (!_isOnline || !_canWork) return;
    if (await getIt<ActiveDeliveryCache>().getDeliveryId() != null) return;
    try {
      final result = await getIt<ApiService>().getAvailableDeliveryRequests();
      if (mounted) setState(() => _availableRides = result.rides.length);
    } catch (e) {
      await _handleWorkForbidden(e);
    }
  }

  Future<void> _startDelivery() async {
    if (_activeOrderId == null) return;
    setState(() => _isStartingDelivery = true);
    try {
      final api = getIt<ApiService>();
      final res = await api.startRideRequest(_activeOrderId!);
      if (!mounted) return;
      final message = res['message']?.toString() ?? 'Ride started successfully';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
      setState(() => _rideStatus = 'en_route');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
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
      final res = await api.cancelRideRequest(_activeOrderId!);
      if (!mounted) return;
      final message = res['message']?.toString() ?? 'Ride cancelled successfully';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
      setState(() {
        _hasActiveRide = false;
        _activeOrderId = null;
        _rideStatus = 'request';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
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
            _walletCurrency = AppCurrency.resolve(wallet['currency']?.toString());
          }
          if (driverProfile == null) {
            _vehicleDisplay = '—';
          }
        });
        final available = DriverAvailability.fromProfile(profile);
        if (available == true && _canWork && !_isOnline) {
          setState(() => _isOnline = true);
          _startActiveRideCheck();
          unawaited(getIt<DriverLocationHeartbeat>().start(
            highAccuracy: _hasActiveRide,
          ));
          _refreshAvailableOrdersCount();
        }
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
      body: Column(
        children: [
          SafeArea(
            bottom: false,
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
                          'assets/images/logo.jpg',
                          height: 36,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(Icons.local_shipping, size: 32, color: Colors.deepPurple),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Material(
                          color: Colors.deepPurple.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const RideEarningsScreen(),
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
                      Material(
                        color: Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () async {
                            await getIt<SecureStorageService>().saveDriverMode('delivery');
                            if (context.mounted) {
                              context.goNamed(AppRouter.deliveryHome);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.swap_horiz, size: 20, color: Colors.orange[800]),
                                const SizedBox(width: 4),
                                Text(
                                  'Delivery',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange[800]),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const NotificationsBellButton(),
                  ],
                ),
              ),
            ),
          ),
          ),
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _userPosition != null
                        ? LatLng(_userPosition!.latitude, _userPosition!.longitude)
                        : const LatLng(0, 0),
                    zoom: 14,
                  ),
                  onMapCreated: (controller) => _googleMapController = controller,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  markers: _userPosition != null
                      ? {
                          Marker(
                            markerId: const MarkerId('user'),
                            position: LatLng(_userPosition!.latitude, _userPosition!.longitude),
                            icon: _deliveryGuyIcon ??
                                BitmapDescriptor.defaultMarkerWithHue(
                                  BitmapDescriptor.hueAzure,
                                ),
                            anchor: const Offset(0.5, 0.5),
                          ),
                        }
                      : {},
                ),
                if (_hasActiveRide && (_rideStatus == 'accepted' || _rideStatus == 'en_route' || _rideStatus == 'arrived'))
                  Positioned(
                    top: 8,
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
                              _rideStatus == 'arrived'
                                  ? Icons.flag
                                  : _rideStatus == 'accepted'
                                      ? Icons.check_circle
                                      : Icons.navigation,
                              color: Colors.white,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _rideStatus == 'arrived'
                                    ? 'You have arrived at your destination'
                                    : _rideStatus == 'accepted'
                                        ? 'Order accepted - ready to start delivery'
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
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(8),
                    child: IconButton(
                      icon: const Icon(Icons.my_location),
                      onPressed: _requestAndUseLocation,
                      tooltip: 'Refresh my location',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.deepPurple,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.zero,
              child: _hasActiveRide ? _buildActiveRideCard() : _buildDefaultBottomCard(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultBottomCard() {
    return Material(
      elevation: 8,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Container(
        width: double.infinity,
                decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                    onChanged: (!_canWork || _isUpdatingAvailability)
                        ? null
                        : _setAvailability,
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
                            builder: (context) => const AvailableRidesScreen(),
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
                        '$_availableRides Rides available',
              style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.85),
                        ),
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
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RideProfilePage()),
                ),
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
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Container(
        width: double.infinity,
      decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                        onPressed: _isCancellingOrder ? null : _cancelOrder,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white70),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isCancellingOrder
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => setState(() => _rideStatus = 'accepted'),
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
              if (_rideStatus == 'accepted') ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isStartingDelivery ? null : _startDelivery,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.deepPurple.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isStartingDelivery
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.deepPurple.shade700,
                            ),
                          )
                        : const Text('Start Delivery'),
                  ),
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
