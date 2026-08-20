import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';
import 'package:hudhud_delivery_driver/core/auth/application_status_gate.dart';
import 'package:hudhud_delivery_driver/core/constants/application_status.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/models/available_driver_requests.dart';
import 'package:hudhud_delivery_driver/core/notifications/delivery_notification_deduper.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/services/directions_service.dart';
import 'package:hudhud_delivery_driver/core/services/driver_location_heartbeat.dart';
import 'package:hudhud_delivery_driver/core/services/location_service.dart';
import 'package:hudhud_delivery_driver/core/services/notification_service.dart';
import 'package:hudhud_delivery_driver/core/services/secure_storage_service.dart';
import 'package:hudhud_delivery_driver/core/utils/app_currency.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';
import 'package:hudhud_delivery_driver/core/utils/phone_launcher.dart';
import 'package:hudhud_delivery_driver/core/models/active_job.dart';
import 'package:hudhud_delivery_driver/core/models/delivery_otp.dart';
import 'package:hudhud_delivery_driver/core/models/delivery_pricing.dart';
import 'package:hudhud_delivery_driver/core/models/driver_navigation.dart';
import 'package:hudhud_delivery_driver/core/services/active_delivery_cache.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/pages/available_deliveries_screen.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/widgets/dispatch_message_banner.dart';
import 'package:hudhud_delivery_driver/features/finance/presentation/pages/driver_finance_hub_page.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/pages/delivery_profile_page.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/pages/delivery_completion_page.dart';
import 'package:hudhud_delivery_driver/features/notifications/presentation/widgets/notifications_bell_button.dart';
import 'package:easy_localization/easy_localization.dart';

class DeliveryHomePage extends StatefulWidget {
  const DeliveryHomePage({
    Key? key,
    this.initialDeliveryId,
    this.showCancelledMessage = false,
  }) : super(key: key);

  final int? initialDeliveryId;
  final bool showCancelledMessage;

  @override
  State<DeliveryHomePage> createState() => _DeliveryHomePageState();
}

class _DeliveryHomePageState extends State<DeliveryHomePage>
    with WidgetsBindingObserver {
  bool _isOnline = false;
  bool _canWork = true;
  bool _isUpdatingAvailability = false;
  int _availableDeliveries = 0;
  String? _dispatchMessage;
  bool _locationAlwaysGranted = true;
  GoogleMapController? _googleMapController;
  final SecureStorageService _secureStorage = SecureStorageService();
  final LocationService _locationService = LocationService();

  String _userName = 'Courier';
  String _vehicleDisplay = '—';
  String _walletBalance = '0';
  String _walletCurrency = AppCurrency.code;
  String? _profilePictureUrl;
  latlong.LatLng? _userPosition;

  bool _hasActiveDelivery = false;
  int? _activeDeliveryId;
  String _deliveryStatus = 'accepted';
  String? _pickupAddress;
  String? _dropoffAddress;
  LatLng? _pickupLatLng;
  LatLng? _dropoffLatLng;
  List<LatLng> _routePoints = const [];
  int _routeRequestId = 0;
  String? _customerName;
  String? _senderPhone;
  String? _receiverPhone;
  String? _paymentLabel;
  double? _estimatedDistance;
  int? _estimatedDuration;
  double? _estimatedFare;
  DeliveryPricing? _pricing;
  bool _otpRequired = false;
  int _otpDigitLength = DeliveryOtp.defaultDigitLength;
  int? _otpAttemptsRemaining;
  bool _otpLocked = false;
  bool _otpSheetOpen = false;
  int? _autoOpenedOtpForId;
  final DeliveryNotificationDeduper _notificationDeduper =
      DeliveryNotificationDeduper();
  bool _isArrivingPickup = false;
  bool _isStartingDelivery = false;
  bool _isCancellingOrder = false;
  DriverNavigation? _serverNavigation;

  static const Duration _activeRideCheckInterval = Duration(seconds: 30);
  static const Duration _unreadPollInterval = Duration(seconds: 45);
  static const Duration _availableRequestsInterval = Duration(seconds: 10);
  Timer? _activeRideCheckTimer;
  Timer? _unreadPollTimer;
  Timer? _availableRequestsTimer;
  int _chatUnreadCount = 0;
  bool _isForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadWorkPermission();
    _loadDriverProfile();
    _requestAndUseLocation();
    _refreshChatUnreadCount();
    _startUnreadPolling();
    getIt<NotificationService>().homeRefreshTick.addListener(_onPushRefresh);
    getIt<DriverLocationHeartbeat>().addListener(_onHeartbeat);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.initialDeliveryId != null) {
        await _loadDeliveryDetail(widget.initialDeliveryId!);
      }
      await _checkActiveDeliveryAndSync();
    });
    if (widget.showCancelledMessage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This delivery was cancelled.'),
            backgroundColor: Colors.orange,
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    getIt<NotificationService>().homeRefreshTick.removeListener(_onPushRefresh);
    getIt<DriverLocationHeartbeat>().removeListener(_onHeartbeat);
    _activeRideCheckTimer?.cancel();
    _unreadPollTimer?.cancel();
    _availableRequestsTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isForeground = true;
      _startUnreadPolling();
      _refreshChatUnreadCount();
      unawaited(_locationService.hasAlwaysPermission().then((granted) {
        if (mounted) setState(() => _locationAlwaysGranted = granted);
      }));
      if (_activeDeliveryId != null) {
        _loadDeliveryDetail(_activeDeliveryId!, silent: true);
      } else {
        _checkActiveDeliveryAndSync();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _isForeground = false;
      _unreadPollTimer?.cancel();
      _unreadPollTimer = null;
    }
  }

  void _startUnreadPolling() {
    _unreadPollTimer?.cancel();
    if (!_isForeground) return;
    _unreadPollTimer = Timer.periodic(_unreadPollInterval, (_) {
      _refreshChatUnreadCount();
    });
  }

  Future<void> _refreshChatUnreadCount() async {
    try {
      final api = getIt<ApiService>();
      final count = await api.getDeliveryUnreadCount();
      if (mounted) setState(() => _chatUnreadCount = count);
    } catch (_) {}
  }

  void _openChatInbox() {
    context.pushNamed(AppRouter.deliveryConversations).then((_) {
      _refreshChatUnreadCount();
    });
  }

  Future<void> _loadWorkPermission() async {
    final status = await getIt<SecureStorageService>().getApplicationStatus();
    if (!mounted) return;
    setState(() => _canWork = status == null || ApplicationStatus.canWork(status));
  }

  void _openActiveDeliveryChat() {
    if (_activeDeliveryId == null) return;
    context.pushNamed(
      AppRouter.deliveryChat,
      pathParameters: {'deliveryId': _activeDeliveryId.toString()},
    ).then((_) {
      _refreshChatUnreadCount();
    });
  }

  void _stopWorkPolling() {
    _stopActiveRideCheck();
    _stopAvailableRequestsPoll();
    unawaited(getIt<DriverLocationHeartbeat>().stop());
  }

  void _onHeartbeat() {
    if (!mounted) return;
    final hb = getIt<DriverLocationHeartbeat>();
    final pos = hb.lastLatLng;
    setState(() {
      if (pos != null) _userPosition = pos;
    });
    if (_hasActiveDelivery && pos != null) {
      unawaited(_loadActiveDrivingRoute());
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

  bool get _callReceiver {
    return _deliveryStatus == 'in_transit' || _deliveryStatus == 'pending_otp';
  }

  String? get _activeCallPhone =>
      _callReceiver ? _receiverPhone : _senderPhone;

  Future<void> _callActiveContact() async {
    final ok = await PhoneLauncher.call(_activeCallPhone);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _callReceiver
                ? 'Receiver phone number is not available'
                : 'Sender phone number is not available',
          ),
        ),
      );
    }
  }

  void _onPushRefresh() {
    final push = getIt<NotificationService>().lastDeliveryPush.value;
    final pushDeliveryId = push?.deliveryId;
    final pushStatus = push?.status;
    if (pushDeliveryId != null && pushStatus != null) {
      _notificationDeduper.shouldApply(
        deliveryId: pushDeliveryId,
        status: pushStatus,
      );
    }

    _loadDriverProfile();
    _checkActiveDeliveryAndSync();
    _refreshAvailableOrdersCount();
    _refreshChatUnreadCount();
    final idToLoad = pushDeliveryId ?? _activeDeliveryId;
    if (idToLoad != null) {
      _loadDeliveryDetail(idToLoad);
    }
  }

  void _clearActiveDelivery({String? snackMessage}) {
    if (!mounted) return;
    getIt<ActiveDeliveryCache>().clear();
    unawaited(getIt<DriverLocationHeartbeat>().setHighAccuracy(false));
    setState(() {
      _hasActiveDelivery = false;
      _activeDeliveryId = null;
      _deliveryStatus = 'accepted';
      _pickupAddress = null;
      _dropoffAddress = null;
      _pickupLatLng = null;
      _dropoffLatLng = null;
      _routePoints = const [];
      _serverNavigation = null;
      _customerName = null;
      _senderPhone = null;
      _receiverPhone = null;
      _paymentLabel = null;
      _estimatedDistance = null;
      _estimatedDuration = null;
      _estimatedFare = null;
      _pricing = null;
      _otpRequired = false;
      _otpDigitLength = DeliveryOtp.defaultDigitLength;
      _otpAttemptsRemaining = null;
      _otpLocked = false;
      _autoOpenedOtpForId = null;
    });
    if (snackMessage != null && snackMessage.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(snackMessage), backgroundColor: Colors.orange.shade800),
      );
    }
  }

  /// Maps API delivery status to UI phases.
  /// Prefers machine `status` over display `current_status` labels.
  /// Returns `completed` when the trip is finished so callers can clear state.
  /// Returns `pending_otp` when identity verification is still required.
  String _mapDeliveryStatus(Map<String, dynamic> delivery) {
    if (_isOtpPending(delivery)) {
      return 'pending_otp';
    }

    if (delivery['completed_at'] != null) {
      return 'completed';
    }

    final status = delivery['status']?.toString().toLowerCase().trim() ?? '';
    final current = delivery['current_status']?.toString().toLowerCase().trim() ?? '';
    // Prefer machine status; only fall back to current_status if status is empty.
    final raw = status.isNotEmpty ? status : current;

    if (raw == 'delivered' || raw == 'completed' || raw == 'complete') {
      return 'completed';
    }

    // started_at is authoritative once the trip has begun (API may leave
    // status as at_pickup after start while still setting started_at).
    if (delivery['started_at'] != null) {
      return 'in_transit';
    }

    if (raw == 'in_transit' ||
        raw == 'picked_up' ||
        raw == 'out_for_delivery' ||
        raw == 'started' ||
        raw == 'en_route_dropoff' ||
        raw == 'at_dropoff' ||
        raw.contains('transit')) {
      return 'in_transit';
    }
    if (raw == 'arrived_pickup' ||
        raw == 'at_pickup' ||
        raw == 'pickup_arrived') {
      return 'arrived_pickup';
    }

    // pickup_assigned, en_route_pickup, accepted, assigned, pending, etc.
    return 'accepted';
  }

  bool _isOtpPending(Map<String, dynamic> delivery) {
    if (!DeliveryOtp.otpRequiredForDelivery(delivery)) return false;

    final otp = DeliveryOtp.fromDelivery(delivery);
    if (otp?.verified == true) return false;
    if (otp?.locked == true && _isPostPickupPhase(delivery)) return true;
    if (!_isPostPickupPhase(delivery)) return false;

    return otp?.verified != true;
  }

  bool _isPostPickupPhase(Map<String, dynamic> delivery) {
    if (delivery['started_at'] != null) return true;

    final status = delivery['status']?.toString().toLowerCase().trim() ?? '';
    final current =
        delivery['current_status']?.toString().toLowerCase().trim() ?? '';
    final raw = status.isNotEmpty ? status : current;

    return raw == 'in_transit' ||
        raw == 'picked_up' ||
        raw == 'out_for_delivery' ||
        raw == 'started' ||
        raw == 'en_route_dropoff' ||
        raw == 'at_dropoff' ||
        raw.contains('transit');
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString());
  }

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static String? _contactPhone(
    Map<String, dynamic> delivery, {
    required String nestedKey,
    required String flatKey,
  }) {
    final nested = delivery[nestedKey];
    if (nested is Map && nested['contact_phone'] != null) {
      final phone = nested['contact_phone'].toString();
      if (phone.isNotEmpty) return phone;
    }
    final flat = delivery[flatKey]?.toString();
    if (flat != null && flat.isNotEmpty) return flat;
    return null;
  }

  static LatLng? _extractLatLng(
    Map<String, dynamic> source, {
    required String nestedKey,
    required List<String> flatLatKeys,
    required List<String> flatLngKeys,
  }) {
    final nested = source[nestedKey];
    if (nested is Map) {
      final lat = _asDouble(nested['latitude'] ?? nested['lat']);
      final lng = _asDouble(
        nested['longitude'] ?? nested['lng'] ?? nested['lon'],
      );
      if (lat != null && lng != null) return LatLng(lat, lng);
    }

    double? lat;
    double? lng;
    for (final key in flatLatKeys) {
      lat ??= _asDouble(source[key]);
    }
    for (final key in flatLngKeys) {
      lng ??= _asDouble(source[key]);
    }
    if (lat != null && lng != null) return LatLng(lat, lng);
    return null;
  }

  LatLng? get _routeTargetLatLng {
    if (!_hasActiveDelivery) return null;
    final nav = _serverNavigation;
    if (nav != null && nav.latitude != null && nav.longitude != null) {
      return LatLng(nav.latitude!, nav.longitude!);
    }
    // Until arrive-at-pickup: navigate to pickup. After that: dropoff.
    if (nav?.isToDropoff == true) return _dropoffLatLng;
    if (nav?.isToPickup == true) return _pickupLatLng;
    if (_deliveryStatus == 'accepted') return _pickupLatLng;
    return _dropoffLatLng;
  }

  Future<void> _openServerNavigation() async {
    final uri = _serverNavigation?.externalMapsUri;
    if (uri == null) {
      final target = _routeTargetLatLng;
      if (target == null) return;
      final fallback = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${target.latitude},${target.longitude}',
      );
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _applyNavigationFromPayload(dynamic payload) {
    final nav = DriverNavigation.fromPayload(payload);
    if (nav == null) return;
    _serverNavigation = nav;
    if (nav.latitude != null && nav.longitude != null) {
      if (nav.isToPickup) {
        _pickupLatLng = LatLng(nav.latitude!, nav.longitude!);
        if (nav.address != null && nav.address!.isNotEmpty) {
          _pickupAddress = nav.address;
        }
      } else if (nav.isToDropoff) {
        _dropoffLatLng = LatLng(nav.latitude!, nav.longitude!);
        if (nav.address != null && nav.address!.isNotEmpty) {
          _dropoffAddress = nav.address;
        }
      }
    }
  }

  Set<Marker> get _mapMarkers {
    final markers = <Marker>{};
    if (_userPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('user'),
          position: LatLng(_userPosition!.latitude, _userPosition!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: const InfoWindow(title: 'You'),
        ),
      );
    }
    if (!_hasActiveDelivery) return markers;

    if (_deliveryStatus == 'accepted') {
      if (_pickupLatLng != null) {
        markers.add(
          Marker(
            markerId: const MarkerId('pickup'),
            position: _pickupLatLng!,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: InfoWindow(
              title: 'Pickup',
              snippet: _pickupAddress,
            ),
          ),
        );
      }
    } else if (_dropoffLatLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: _dropoffLatLng!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'Dropoff',
            snippet: _dropoffAddress,
          ),
        ),
      );
    }
    return markers;
  }

  Set<Polyline> get _mapPolylines {
    if (!_hasActiveDelivery || _userPosition == null) return {};
    final target = _routeTargetLatLng;
    if (target == null) return {};
    final points = _routePoints.length >= 2
        ? _routePoints
        : <LatLng>[
            LatLng(_userPosition!.latitude, _userPosition!.longitude),
            target,
          ];
    return {
      Polyline(
        polylineId: const PolylineId('active_route'),
        points: points,
        color: Colors.orange.shade700,
        width: 5,
        geodesic: false,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ),
    };
  }

  Future<void> _loadActiveDrivingRoute({bool fitCamera = false}) async {
    if (!_hasActiveDelivery || _userPosition == null) return;
    final target = _routeTargetLatLng;
    if (target == null) return;

    final origin = LatLng(_userPosition!.latitude, _userPosition!.longitude);
    final requestId = ++_routeRequestId;
    try {
      final points = await DirectionsService().getDrivingRoute(
        origin: origin,
        destination: target,
      );
      if (!mounted || requestId != _routeRequestId) return;
      setState(() => _routePoints = points);
      if (fitCamera) _fitRouteCamera();
    } catch (_) {
      if (!mounted || requestId != _routeRequestId) return;
      // Fall back to a straight segment so the map still shows a connector.
      setState(() => _routePoints = [origin, target]);
      if (fitCamera) _fitRouteCamera();
    }
  }

  void _fitRouteCamera() {
    final controller = _googleMapController;
    if (controller == null) return;

    if (_routePoints.length >= 2) {
      var minLat = _routePoints.first.latitude;
      var maxLat = _routePoints.first.latitude;
      var minLng = _routePoints.first.longitude;
      var maxLng = _routePoints.first.longitude;
      for (final p in _routePoints) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }
      controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          72,
        ),
      );
      return;
    }

    if (_userPosition == null) return;
    final target = _routeTargetLatLng;
    if (target == null) {
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_userPosition!.latitude, _userPosition!.longitude),
          14,
        ),
      );
      return;
    }

    final driver = LatLng(_userPosition!.latitude, _userPosition!.longitude);
    final bounds = LatLngBounds(
      southwest: LatLng(
        driver.latitude < target.latitude ? driver.latitude : target.latitude,
        driver.longitude < target.longitude ? driver.longitude : target.longitude,
      ),
      northeast: LatLng(
        driver.latitude > target.latitude ? driver.latitude : target.latitude,
        driver.longitude > target.longitude ? driver.longitude : target.longitude,
      ),
    );
    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 72));
  }

  Future<bool> _loadDeliveryDetail(int deliveryId, {bool silent = false}) async {
    try {
      final delivery = await getIt<ApiService>().getDeliveryDetail(deliveryId);
      if (!mounted) return false;
      final pickup = delivery['pickup'];
      final dropoff = delivery['dropoff'];
      final customer = delivery['customer'];
      final payment = delivery['payment'];
      String? pickupAddress;
      String? dropoffAddress;
      if (pickup is Map) {
        pickupAddress = pickup['address']?.toString();
      }
      if (dropoff is Map) {
        dropoffAddress = dropoff['address']?.toString();
      }
      final pickupLatLng = _extractLatLng(
        delivery,
        nestedKey: 'pickup',
        flatLatKeys: const [
          'pickup_latitude',
          'pickup_lat',
          'pickupLatitude',
        ],
        flatLngKeys: const [
          'pickup_longitude',
          'pickup_lng',
          'pickup_lon',
          'pickupLongitude',
        ],
      );
      final dropoffLatLng = _extractLatLng(
        delivery,
        nestedKey: 'dropoff',
        flatLatKeys: const [
          'dropoff_latitude',
          'dropoff_lat',
          'dropoffLatitude',
          'delivery_latitude',
        ],
        flatLngKeys: const [
          'dropoff_longitude',
          'dropoff_lng',
          'dropoff_lon',
          'dropoffLongitude',
          'delivery_longitude',
        ],
      );
      String? customerName;
      if (customer is Map) {
        customerName = customer['name']?.toString();
      }
      final senderPhone = _contactPhone(
        delivery,
        nestedKey: 'pickup',
        flatKey: 'sender_phone',
      );
      final receiverPhone = _contactPhone(
        delivery,
        nestedKey: 'dropoff',
        flatKey: 'receiver_phone',
      );
      String? paymentLabel;
      if (payment is Map) {
        final method = payment['method']?.toString() ?? '';
        final amount = payment['amount']?.toString() ?? '';
        final currency = AppCurrency.resolve(payment['currency']?.toString());
        paymentLabel = [
          if (method.isNotEmpty) method,
          if (amount.isNotEmpty) AppCurrency.format(amount, currency: currency),
        ].where((s) => s.isNotEmpty).join(' · ');
      }
      final estimatedFare = DeliveryPricing.serverQuoteAmount(delivery);
      final pricing = DeliveryPricing.fromDelivery(delivery);
      final estimatedDistance = _asDouble(delivery['estimated_distance']);
      final estimatedDuration = _asInt(delivery['estimated_duration']);
      final mappedStatus = _mapDeliveryStatus(delivery);
      if (mappedStatus == 'completed') {
        _clearActiveDelivery();
        return false;
      }
      final otpState = DeliveryOtp.fromDelivery(delivery);
      final otpRequired = DeliveryOtp.otpRequiredForDelivery(delivery);
      setState(() {
        _hasActiveDelivery = true;
        _activeDeliveryId = deliveryId;
        _deliveryStatus = mappedStatus;
        _pickupAddress = pickupAddress;
        _dropoffAddress = dropoffAddress;
        _pickupLatLng = pickupLatLng;
        _dropoffLatLng = dropoffLatLng;
        _customerName = customerName;
        _senderPhone = senderPhone;
        _receiverPhone = receiverPhone;
        _paymentLabel = paymentLabel?.isEmpty == true ? null : paymentLabel;
        _estimatedDistance = estimatedDistance;
        _estimatedDuration = estimatedDuration;
        _estimatedFare = estimatedFare;
        _pricing = pricing;
        _otpRequired = otpRequired;
        _otpDigitLength = otpState?.digitLength ?? DeliveryOtp.defaultDigitLength;
        _otpAttemptsRemaining = otpState?.attemptsRemaining;
        _otpLocked = otpState?.locked ?? false;
        _applyNavigationFromPayload(delivery);
      });
      getIt<ActiveDeliveryCache>().saveDeliveryId(deliveryId);
      _notificationDeduper.recordFromApi(deliveryId, mappedStatus);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadActiveDrivingRoute(fitCamera: true);
        if (mappedStatus == 'pending_otp' && _autoOpenedOtpForId != deliveryId) {
          _autoOpenedOtpForId = deliveryId;
          _openCompletionPage(resumeOtp: true);
        }
      });
      unawaited(getIt<DriverLocationHeartbeat>().setHighAccuracy(true));
      return true;
    } on GoneException catch (e) {
      _clearActiveDelivery(snackMessage: silent ? null : e.message);
      return false;
    } on ForbiddenException catch (e) {
      _clearActiveDelivery(snackMessage: silent ? null : e.message);
      return false;
    } on NotFoundException catch (e) {
      _clearActiveDelivery(snackMessage: silent ? null : e.message);
      return false;
    } catch (e) {
      if (!silent && mounted) {
        final message = e is AppException
            ? e.message
            : e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
      return false;
    }
  }

  Future<void> _requestAndUseLocation() async {
    final permission = await _locationService.requestLocationPermission();
    if (!mounted) return;
    setState(() => _locationAlwaysGranted = permission.always);
    if (!permission.whenInUse) {
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
        if (!mounted) return;
        if (_hasActiveDelivery) {
          _loadActiveDrivingRoute(fitCamera: true);
        } else {
          _googleMapController?.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(position.latitude, position.longitude),
              14,
            ),
          );
        }
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
            content: Text('Turn on location services to go online for nearby offers.'),
          ),
        );
        return;
      }
      final permission = await _locationService.requestLocationPermission();
      if (!mounted) return;
      setState(() => _locationAlwaysGranted = permission.always);
      if (!permission.whenInUse) {
        _locationService.showPermissionSettingsDialog(context);
        return;
      }
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
        reason: goOnline ? 'Going online for deliveries' : 'Going offline',
      );
      if (!mounted) return;
      setState(() {
        _isOnline = goOnline;
        _isUpdatingAvailability = false;
      });
      if (goOnline) {
        _startActiveRideCheck();
        unawaited(getIt<DriverLocationHeartbeat>().start(
          highAccuracy: _hasActiveDelivery,
        ));
        _startAvailableRequestsPoll();
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
    _checkActiveDeliveryAndSync();
    _activeRideCheckTimer = Timer.periodic(_activeRideCheckInterval, (_) => _checkActiveDeliveryAndSync());
  }

  void _stopActiveRideCheck() {
    _activeRideCheckTimer?.cancel();
    _activeRideCheckTimer = null;
  }

  Future<void> _checkActiveDeliveryAndSync() async {
    try {
      final api = getIt<ApiService>();
      try {
        final status = await api.getDriverCurrentStatus();
        if (!mounted) return;
        final deliveryId = status.deliveryId ??
            widget.initialDeliveryId ??
            _activeDeliveryId;
        if (deliveryId != null) {
          if (status.navigation != null) {
            _applyNavigationFromPayload(status.raw);
            if (status.navigation != null) {
              _serverNavigation = status.navigation;
            }
          }
          await _loadDeliveryDetail(deliveryId, silent: true);
          return;
        }
        if (status.activeJob == null && mounted) {
          _clearActiveDelivery();
          return;
        }
      } on NotFoundException {
        // Fall through to profile/cache recovery.
      } on AppException {
        // Fall through to profile/cache recovery.
      }

      final cache = getIt<ActiveDeliveryCache>();
      final cachedId = await cache.getDeliveryId();
      final profile = await api.getDriverProfile();
      if (!mounted) return;
      final deliveryId = ActiveJob.resolveDeliveryIdForHome(
        profile: profile,
        initialDeliveryId: widget.initialDeliveryId,
        currentActiveId: _activeDeliveryId,
        cachedDeliveryId: cachedId,
      );
      if (deliveryId != null) {
        await _loadDeliveryDetail(deliveryId, silent: true);
      } else if (mounted) {
        _clearActiveDelivery();
      }
    } catch (_) {
      if (!mounted) return;
      final fallbackId = ActiveJob.resolveDeliveryIdForHome(
        initialDeliveryId: widget.initialDeliveryId,
        currentActiveId: _activeDeliveryId,
        cachedDeliveryId: await getIt<ActiveDeliveryCache>().getDeliveryId(),
      );
      if (fallbackId != null) {
        await _loadDeliveryDetail(fallbackId, silent: true);
      }
    }
  }

  void _startAvailableRequestsPoll() {
    _availableRequestsTimer?.cancel();
    _refreshAvailableOrdersCount();
    _availableRequestsTimer = Timer.periodic(
      _availableRequestsInterval,
      (_) => _refreshAvailableOrdersCount(),
    );
  }

  void _stopAvailableRequestsPoll() {
    _availableRequestsTimer?.cancel();
    _availableRequestsTimer = null;
  }

  Future<void> _refreshAvailableOrdersCount() async {
    if (!_isOnline || !_canWork) return;
    try {
      final result = await getIt<ApiService>().getAvailableDeliveryRequests();
      if (mounted) {
        setState(() {
          _availableDeliveries = result.deliveries.length;
          _dispatchMessage = result.dispatch?.message;
        });
      }
    } catch (e) {
      await _handleWorkForbidden(e);
    }
  }

  Future<void> _openCompletionPage({bool resumeOtp = false}) async {
    if (_activeDeliveryId == null || _otpSheetOpen) return;
    if (!resumeOtp) {
      final ok = await _loadDeliveryDetail(_activeDeliveryId!);
      if (!ok || !mounted || _activeDeliveryId == null) return;
    }
    _otpSheetOpen = true;
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => DeliveryCompletionPage(
          deliveryId: _activeDeliveryId!,
          estimatedDistance: _estimatedDistance,
          estimatedDuration: _estimatedDuration,
          estimatedCost: _estimatedFare,
          pickupLocation: _pickupAddress,
          dropoffLocation: _dropoffAddress,
          otpRequired: _otpRequired,
          resumeOtp: resumeOtp,
          otpDigitLength: _otpDigitLength,
          initialAttemptsRemaining: _otpAttemptsRemaining,
          initialLocked: _otpLocked,
          receiverPhone: _receiverPhone,
        ),
      ),
    );
    _otpSheetOpen = false;
    if (mounted && completed == true) {
      _clearActiveDelivery();
      _refreshAvailableOrdersCount();
    }
  }

  Future<void> _arriveAtPickup() async {
    if (_activeDeliveryId == null) return;
    setState(() => _isArrivingPickup = true);
    try {
      final refreshed = await _loadDeliveryDetail(_activeDeliveryId!);
      if (!refreshed || !mounted || _activeDeliveryId == null) return;
      final api = getIt<ApiService>();
      final position = await _locationService.getCurrentLocation();
      if (position != null && mounted) {
        setState(() => _userPosition = latlong.LatLng(position.latitude, position.longitude));
      }
      final lat = position?.latitude ?? 0.0;
      final lng = position?.longitude ?? 0.0;
      final res = await api.arriveAtPickup(
        deliveryId: _activeDeliveryId!,
        latitude: lat,
        longitude: lng,
      );
      if (!mounted) return;
      _applyNavigationFromPayload(res);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Arrived at pickup'), backgroundColor: Colors.green),
      );
      await _loadDeliveryDetail(_activeDeliveryId!, silent: true);
      if (mounted) await _loadActiveDrivingRoute(fitCamera: true);
    } catch (e) {
      if (!mounted) return;
      final message = e is AppException
          ? e.message
          : e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isArrivingPickup = false);
    }
  }

  Future<void> _startDelivery() async {
    if (_activeDeliveryId == null) return;
    setState(() => _isStartingDelivery = true);
    try {
      final refreshed = await _loadDeliveryDetail(_activeDeliveryId!);
      if (!refreshed || !mounted || _activeDeliveryId == null) return;
      final api = getIt<ApiService>();
      final res = await api.startDeliveryRequest(_activeDeliveryId!);
      if (!mounted) return;
      _applyNavigationFromPayload(res);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Delivery started'), backgroundColor: Colors.green),
      );
      await _loadDeliveryDetail(_activeDeliveryId!, silent: true);
      if (mounted) await _loadActiveDrivingRoute(fitCamera: true);
    } catch (e) {
      if (!mounted) return;
      final message = e is AppException
          ? e.message
          : e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isStartingDelivery = false);
    }
  }

  Future<void> _cancelOrder() async {
    if (_activeDeliveryId == null) return;
    final deliveryId = _activeDeliveryId!;
    setState(() => _isCancellingOrder = true);
    try {
      final api = getIt<ApiService>();
      await api.cancelDeliveryRequest(deliveryId);
      if (!mounted) return;

      final detail = await api.getDeliveryDetail(deliveryId);
      final cancellationFee = _asDouble(detail['cancellation_fee']);
      final metadata = detail['metadata'];
      final isPartialFee = metadata is Map && metadata['is_partial_fee'] == true;

      String message = 'Delivery cancelled';
      if (isPartialFee == true || cancellationFee != null) {
        final feeToShow = cancellationFee ??
            (metadata is Map && metadata['partial_cancellation_quote'] is Map
                ? _asDouble((metadata['partial_cancellation_quote'] as Map)['total'])
                : null);

        if (feeToShow != null) {
          message = 'Cancellation fee: ${AppCurrency.format(feeToShow)}';
        } else {
          message = 'Delivery cancelled';
        }
      }

      _clearActiveDelivery();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e is AppException
          ? e.message
          : e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isCancellingOrder = false);
    }
  }

  Map<String, dynamic>? _mapFrom(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  void _applyWalletFromProfile(dynamic wallet) {
    final walletMap = _mapFrom(wallet);
    if (walletMap == null) return;

    _walletCurrency = AppCurrency.resolve(walletMap['currency']?.toString());
    final balance = walletMap['balance'];
    if (balance == null) {
      _walletBalance = '0';
      return;
    }
    if (balance is num) {
      _walletBalance = AppCurrency.formatDecimal(balance);
      return;
    }
    final parsed = double.tryParse(balance.toString().trim());
    _walletBalance =
        parsed != null ? AppCurrency.formatDecimal(parsed) : balance.toString();
  }

  String get _walletDisplay =>
      AppCurrency.format(_walletBalance, currency: _walletCurrency);

  Future<void> _openFinanceHub() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DriverFinanceHubPage(),
      ),
    );
    if (mounted) _loadDriverProfile();
  }

  Widget _buildWalletChip({
    required Color backgroundColor,
    required Color iconColor,
    required Color textColor,
  }) {
    return Expanded(
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: _openFinanceHub,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 20,
                  color: iconColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _walletDisplay,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadDriverProfile() async {
    try {
      final api = getIt<ApiService>();
      final profile = await api.getDriverProfile();
      if (!mounted) return;
      if (profile != null) {
        setState(() {
          final user = _mapFrom(profile['user']);
          if (user != null) {
            _userName = user['name']?.toString() ?? 'Courier';
          }

          final driverProfile = _mapFrom(profile['driver_profile']);
          if (driverProfile != null) {
            final make = driverProfile['vehicle_make']?.toString();
            final model = driverProfile['vehicle_model']?.toString();
            final plate = driverProfile['vehicle_plate_number']?.toString();
            if (make != null && model != null && plate != null) {
              _vehicleDisplay = '$make $model - $plate';
            } else if (plate != null) {
              _vehicleDisplay = plate;
            }
            _profilePictureUrl = driverProfile['profile_picture']?.toString();
          } else {
            _vehicleDisplay = '—';
          }

          _applyWalletFromProfile(profile['wallet']);
        });
        final available = DriverAvailability.fromProfile(profile);
        if (available == true && _canWork) {
          final wasOnline = _isOnline;
          if (!wasOnline) {
            setState(() => _isOnline = true);
            _startActiveRideCheck();
            unawaited(getIt<DriverLocationHeartbeat>().start(
              highAccuracy: _hasActiveDelivery,
            ));
            _startAvailableRequestsPoll();
          }
        }
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
                          errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2, size: 32, color: Colors.orange),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildWalletChip(
                        backgroundColor: Colors.orange.withValues(alpha: 0.12),
                        iconColor: Colors.orange.shade700,
                        textColor: Colors.orange.shade800,
                      ),
                      // TODO: re-enable ride/delivery toggle when ride mode is ready
                      // const SizedBox(width: 8),
                      // Material(
                      //   color: Colors.deepPurple.withOpacity(0.15),
                      //   borderRadius: BorderRadius.circular(10),
                      //   child: InkWell(
                      //     borderRadius: BorderRadius.circular(10),
                      //     onTap: () async {
                      //       await getIt<SecureStorageService>().saveDriverMode('ride');
                      //       if (context.mounted) {
                      //         context.goNamed(AppRouter.rideHome);
                      //       }
                      //     },
                      //     child: Padding(
                      //       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      //       child: Row(
                      //         mainAxisSize: MainAxisSize.min,
                      //         children: [
                      //           Icon(Icons.swap_horiz, size: 20, color: Colors.deepPurple[800]),
                      //           const SizedBox(width: 4),
                      //           Text(
                      //             'Ride',
                      //             style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.deepPurple[800]),
                      //           ),
                      //         ],
                      //       ),
                      //     ),
                      //   ),
                      // ),
                      const SizedBox(width: 4),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.message_outlined),
                            onPressed: _openChatInbox,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            tooltip: 'chat.messages'.tr(),
                          ),
                          if (_chatUnreadCount > 0)
                            Positioned(
                              right: 4,
                              top: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                child: Text(
                                  _chatUnreadCount > 99 ? '99+' : '$_chatUnreadCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
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
                  onMapCreated: (controller) {
                    _googleMapController = controller;
                    if (_hasActiveDelivery) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _loadActiveDrivingRoute(fitCamera: true);
                      });
                    }
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  markers: _mapMarkers,
                  polylines: _mapPolylines,
                ),
                if (_hasActiveDelivery)
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
                          color: Colors.orange.shade700,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _deliveryStatus == 'in_transit'
                                  ? Icons.navigation
                                  : _deliveryStatus == 'arrived_pickup'
                                      ? Icons.inventory_2
                                      : Icons.directions,
                              color: Colors.white,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _serverNavigation?.label?.isNotEmpty == true
                                    ? 'Navigate: ${_serverNavigation!.label}'
                                    : _deliveryStatus == 'in_transit'
                                        ? 'Delivering to customer'
                                        : _deliveryStatus == 'arrived_pickup'
                                            ? 'Package collected — head to dropoff'
                                            : 'Head to pickup location',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                            ),
                            IconButton(
                              onPressed: _openServerNavigation,
                              icon: const Icon(Icons.open_in_new, color: Colors.white, size: 20),
                              tooltip: 'Open in Maps',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
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
                        foregroundColor: Colors.orange,
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
              child: _hasActiveDelivery ? _buildActiveDeliveryCard() : _buildDefaultBottomCard(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAvailableDeliveries() async {
    final accepted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const AvailableDeliveriesScreen(),
      ),
    );
    _refreshAvailableOrdersCount();
    if (accepted == true) {
      await _checkActiveDeliveryAndSync();
    }
  }

  Widget _buildDefaultBottomCard() {
    return Material(
      elevation: 12,
      shadowColor: Colors.black26,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _isOnline
                ? [Colors.orange.shade600, Colors.deepOrange.shade800]
                : [Colors.orange.shade700, Colors.deepOrange.shade700],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildAvailabilityHeader(),
              const SizedBox(height: 14),
              _buildOnlineToggleRow(),
              if (_isOnline) ...[
                if (!_locationAlwaysGranted) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Background location is off — nearby offers may stop when you leave the app.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
                if (getIt<DriverLocationHeartbeat>().isLocationStale) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _locationService.showPermissionSettingsDialog(
                      context,
                      message:
                          'Location is not updating. Enable location and Always permission so you stay eligible for nearby offers.',
                    ),
                    child: const Text(
                      'Location not updating — tap to open settings',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
                if (_dispatchMessage != null) ...[
                  const SizedBox(height: 10),
                  DispatchMessageBanner(
                    message: _dispatchMessage!,
                    dark: true,
                  ),
                ],
                const SizedBox(height: 10),
                _buildAvailableDeliveriesButton(),
              ] else ...[
                const SizedBox(height: 8),
                Text(
                  'Go online to start receiving delivery requests',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Divider(color: Colors.white.withValues(alpha: 0.25), height: 1),
              const SizedBox(height: 14),
              _buildProfileRow(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvailabilityHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: _isOnline ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isOnline ? Colors.lightGreenAccent : Colors.white54,
              boxShadow: _isOnline
                  ? [
                      BoxShadow(
                        color: Colors.lightGreenAccent.withValues(alpha: 0.6),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _isOnline
                  ? 'You\'re online — ready for nearby deliveries'
                  : 'You are currently offline',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.95),
              ),
            ),
          ),
          if (_isOnline)
            Icon(
              Icons.wifi_tethering,
              size: 18,
              color: Colors.white.withValues(alpha: 0.9),
            ),
        ],
      ),
    );
  }

  Widget _buildOnlineToggleRow() {
    return Row(
      children: [
        Text(
          _isOnline ? 'Go Offline' : 'Go Online',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const Spacer(),
        if (_isUpdatingAvailability)
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        else
          Switch(
            value: _isOnline,
            onChanged: !_canWork ? null : _setAvailability,
            activeThumbColor: Colors.white,
            activeTrackColor: Colors.green.shade300,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.35),
          ),
      ],
    );
  }

  Widget _buildAvailableDeliveriesButton() {
    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: _openAvailableDeliveries,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.local_shipping_rounded,
                color: Colors.orange.shade800,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Available deliveries',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade900,
                  ),
                ),
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 28),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade700,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$_availableDeliveries',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: Colors.orange.shade700,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileRow() {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const DeliveryProfilePage(),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white.withValues(alpha: 0.3),
            backgroundImage: _profilePictureUrl != null &&
                    _profilePictureUrl!.isNotEmpty
                ? NetworkImage(_profilePictureUrl!)
                : null,
            child: _profilePictureUrl == null || _profilePictureUrl!.isEmpty
                ? Text(
                    _userName.isNotEmpty
                        ? _userName[0].toUpperCase()
                        : 'C',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
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
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveDeliveryCard() {
    String statusLabel;
    switch (_deliveryStatus) {
      case 'arrived_pickup':
        statusLabel = 'At pickup location';
        break;
      case 'in_transit':
        statusLabel = 'In transit to customer';
        break;
      default:
        statusLabel = 'Delivery accepted';
    }

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
                  const Icon(Icons.local_shipping, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Active delivery',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.95)),
                  ),
                  const Spacer(),
                  if (_activeCallPhone != null && _activeCallPhone!.isNotEmpty)
                    IconButton(
                      onPressed: _callActiveContact,
                      icon: const Icon(Icons.call, color: Colors.white, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      tooltip: _callReceiver ? 'Call receiver' : 'Call sender',
                    ),
                  IconButton(
                    onPressed: _openActiveDeliveryChat,
                    icon: const Icon(Icons.message_outlined, color: Colors.white, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    tooltip: 'chat.chat_with_customer'.tr(),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusLabel,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ],
              ),
              if (_customerName != null && _customerName!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _customerName!,
                  style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.95)),
                ),
              ],
              if (_pickupAddress != null && _pickupAddress!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Pickup: $_pickupAddress',
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (_dropoffAddress != null && _dropoffAddress!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Dropoff: $_dropoffAddress',
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (_paymentLabel != null && _paymentLabel!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Payment: $_paymentLabel${_otpRequired ? ' · OTP required' : ''}',
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)),
                ),
              ],
              if (_pricing?.zone != null || _pricing?.routeBasis != null) ...[
                const SizedBox(height: 4),
                Text(
                  [
                    if (_pricing?.zone?.name != null)
                      '${_pricing?.zone?.name}${_pricing?.zone?.version != null ? ' v${_pricing?.zone?.version}' : ''}',
                    if (_pricing?.routeBasis != null) _pricing?.routeBasis,
                  ].where((s) => s != null && s.toString().isNotEmpty).join(' · '),
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.85)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // accepted → Arrive at Pickup + Cancel
              if (_deliveryStatus == 'accepted') ...[
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
                            : const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isArrivingPickup ? null : _arriveAtPickup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.deepOrange.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isArrivingPickup
                            ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepOrange.shade700))
                            : const Text('Arrive at Pickup'),
                      ),
                    ),
                  ],
                ),
              ],

              // arrived_pickup → Start Delivery
              if (_deliveryStatus == 'arrived_pickup') ...[
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
                        ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepOrange.shade700))
                        : const Text('Start Delivery'),
                  ),
                ),
              ],

              // pending_otp → resume verification without re-completing
              if (_deliveryStatus == 'pending_otp') ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _openCompletionPage(resumeOtp: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.deepOrange.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Verify Delivery OTP'),
                  ),
                ),
              ],

              // in_transit → Complete Delivery (opens completion + OTP page)
              if (_deliveryStatus == 'in_transit') ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _openCompletionPage(),
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
