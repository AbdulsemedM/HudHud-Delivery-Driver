import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hudhud_delivery_driver/core/auth/application_status_gate.dart';
import 'package:hudhud_delivery_driver/core/constants/application_status.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/services/directions_service.dart';
import 'package:hudhud_delivery_driver/core/utils/app_currency.dart';
import 'package:hudhud_delivery_driver/core/utils/error_handler.dart';

/// Map preview for an available delivery: pickup/dropoff markers + details sheet.
class AvailableDeliveryMapPage extends StatefulWidget {
  const AvailableDeliveryMapPage({
    Key? key,
    required this.delivery,
  }) : super(key: key);

  final Map<String, dynamic> delivery;

  @override
  State<AvailableDeliveryMapPage> createState() =>
      _AvailableDeliveryMapPageState();
}

class _AvailableDeliveryMapPageState extends State<AvailableDeliveryMapPage> {
  late Map<String, dynamic> _delivery;
  GoogleMapController? _mapController;
  LatLng? _pickup;
  LatLng? _dropoff;
  List<LatLng> _routePoints = const [];
  bool _loadingDetail = false;
  bool _loadingRoute = false;
  bool _accepting = false;
  bool _declining = false;
  bool _coordsWarned = false;

  @override
  void initState() {
    super.initState();
    _delivery = Map<String, dynamic>.from(widget.delivery);
    _applyCoordsFrom(_delivery);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureCoordsAndFit();
    });
  }

  int? get _deliveryId {
    final id = _delivery['id'];
    if (id == null) return null;
    if (id is int) return id;
    return int.tryParse(id.toString());
  }

  void _applyCoordsFrom(Map<String, dynamic> source) {
    _pickup = _extractLatLng(
      source,
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
    _dropoff = _extractLatLng(
      source,
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
  }

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
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

  Future<void> _ensureCoordsAndFit() async {
    if (_pickup != null && _dropoff != null) {
      _fitCamera();
      await _loadDrivingRoute();
      return;
    }

    final id = _deliveryId;
    if (id == null) {
      _warnMissingCoords();
      return;
    }

    setState(() => _loadingDetail = true);
    try {
      final detail = await getIt<ApiService>().getDeliveryDetail(id);
      if (!mounted) return;
      setState(() {
        _delivery = {
          ..._delivery,
          ...detail,
          if (detail['pickup'] != null) 'pickup': detail['pickup'],
          if (detail['dropoff'] != null) 'dropoff': detail['dropoff'],
        };
        _applyCoordsFrom(_delivery);
        _loadingDetail = false;
      });
      if (_pickup != null || _dropoff != null) {
        _fitCamera();
        if (_pickup != null && _dropoff != null) {
          await _loadDrivingRoute();
        }
      } else {
        _warnMissingCoords();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingDetail = false);
      _warnMissingCoords();
    }
  }

  Future<void> _loadDrivingRoute() async {
    if (_pickup == null || _dropoff == null) return;
    setState(() => _loadingRoute = true);
    try {
      final points = await DirectionsService().getDrivingRoute(
        origin: _pickup!,
        destination: _dropoff!,
      );
      if (!mounted) return;
      setState(() {
        _routePoints = points;
        _loadingRoute = false;
      });
      _fitCameraToRoute();
    } catch (_) {
      if (!mounted) return;
      // Fall back to a straight segment so the map still shows a connector.
      setState(() {
        _routePoints = [_pickup!, _dropoff!];
        _loadingRoute = false;
      });
    }
  }

  void _warnMissingCoords() {
    if (_coordsWarned || !mounted) return;
    _coordsWarned = true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Map coordinates unavailable for this delivery.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _fitCamera() {
    final controller = _mapController;
    if (controller == null) return;

    if (_routePoints.length >= 2) {
      _fitCameraToRoute();
      return;
    }

    if (_pickup != null && _dropoff != null) {
      final bounds = LatLngBounds(
        southwest: LatLng(
          _pickup!.latitude < _dropoff!.latitude
              ? _pickup!.latitude
              : _dropoff!.latitude,
          _pickup!.longitude < _dropoff!.longitude
              ? _pickup!.longitude
              : _dropoff!.longitude,
        ),
        northeast: LatLng(
          _pickup!.latitude > _dropoff!.latitude
              ? _pickup!.latitude
              : _dropoff!.latitude,
          _pickup!.longitude > _dropoff!.longitude
              ? _pickup!.longitude
              : _dropoff!.longitude,
        ),
      );
      controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 72));
      return;
    }

    final single = _pickup ?? _dropoff;
    if (single != null) {
      controller.animateCamera(CameraUpdate.newLatLngZoom(single, 14));
    }
  }

  void _fitCameraToRoute() {
    final controller = _mapController;
    if (controller == null || _routePoints.isEmpty) return;

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
  }

  Set<Marker> get _markers {
    final markers = <Marker>{};
    if (_pickup != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: _pickup!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: 'Pickup',
            snippet: _pickupAddress,
          ),
        ),
      );
    }
    if (_dropoff != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: _dropoff!,
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

  Set<Polyline> get _polylines {
    final points = _routePoints.length >= 2
        ? _routePoints
        : (_pickup != null && _dropoff != null
            ? <LatLng>[_pickup!, _dropoff!]
            : const <LatLng>[]);
    if (points.length < 2) return {};
    return {
      Polyline(
        polylineId: const PolylineId('pickup_to_dropoff'),
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

  String get _pickupAddress {
    final nested = _delivery['pickup'];
    if (nested is Map && nested['address'] != null) {
      return nested['address'].toString();
    }
    return _delivery['pickup_location']?.toString() ?? '—';
  }

  String get _dropoffAddress {
    final nested = _delivery['dropoff'];
    if (nested is Map && nested['address'] != null) {
      return nested['address'].toString();
    }
    return _delivery['dropoff_location']?.toString() ?? '—';
  }

  String? get _senderName {
    final nested = _delivery['pickup'];
    if (nested is Map && nested['contact_name'] != null) {
      return nested['contact_name'].toString();
    }
    return _delivery['sender_name']?.toString();
  }

  String? get _receiverName {
    final nested = _delivery['dropoff'];
    if (nested is Map && nested['contact_name'] != null) {
      return nested['contact_name'].toString();
    }
    return _delivery['receiver_name']?.toString();
  }

  CodAcceptance? get _codAcceptance => CodAcceptance.fromDelivery(_delivery);

  bool get _canAcceptCod => _codAcceptance?.canAccept ?? true;

  Future<void> _accept() async {
    final id = _deliveryId;
    if (id == null || _accepting || !_canAcceptCod) return;
    setState(() => _accepting = true);
    try {
      final res = await getIt<ApiService>().acceptDeliveryRequest(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'Delivery accepted'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } on ConflictException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      Navigator.pop(context, false);
    } catch (e) {
      if (await ApplicationStatusGate.handleForbidden(context, e)) return;
      if (!mounted) return;
      final message = e is AppException
          ? e.message
          : e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  Future<void> _decline() async {
    final id = _deliveryId;
    if (id == null || _declining) return;
    setState(() => _declining = true);
    try {
      final res = await getIt<ApiService>().cancelDriverOrder(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'Delivery declined'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, false);
    } catch (e) {
      if (!mounted) return;
      final message = e is AppException
          ? e.message
          : e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _declining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final packageType =
        _capitalize(_delivery['package_type']?.toString() ?? 'Package');
    final packageDesc = _delivery['package_description']?.toString();
    final status = _delivery['status']?.toString() ??
        _delivery['current_status']?.toString() ??
        'pending';
    final estimatedCost = _delivery['estimated_cost']?.toString() ??
        _delivery['final_cost']?.toString() ??
        '—';
    final estimatedDistance = _delivery['estimated_distance']?.toString();
    final estimatedDuration = _delivery['estimated_duration'];
    final specialInstructions = _delivery['special_instructions']?.toString() ??
        _delivery['notes']?.toString();
    final initialTarget = _pickup ??
        _dropoff ??
        const LatLng(9.03, 38.74);

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initialTarget,
              zoom: 13,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              _fitCamera();
            },
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Material(
                color: Colors.white,
                elevation: 2,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
          if (_loadingDetail || _loadingRoute)
            const Positioned(
              top: 72,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 10),
                        Text('Loading route…'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          DraggableScrollableSheet(
            initialChildSize: 0.42,
            minChildSize: 0.28,
            maxChildSize: 0.82,
            builder: (context, scrollController) {
              return Material(
                elevation: 12,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                color: Colors.white,
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            packageType,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _capitalize(status.replaceAll('_', ' ')),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (packageDesc != null && packageDesc.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        packageDesc,
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade700),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _buildPointTile(
                      icon: Icons.radio_button_checked,
                      color: Colors.green.shade600,
                      label: 'PICKUP',
                      address: _pickupAddress,
                      person: _senderName,
                      coords: _pickup,
                    ),
                    const SizedBox(height: 12),
                    _buildPointTile(
                      icon: Icons.location_on,
                      color: Colors.red.shade600,
                      label: 'DROPOFF',
                      address: _dropoffAddress,
                      person: _receiverName,
                      coords: _dropoff,
                    ),
                    if (specialInstructions != null &&
                        specialInstructions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              size: 16, color: Colors.amber.shade700),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              specialInstructions,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.amber.shade900,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (estimatedDistance != null)
                          _estimateChip(
                              Icons.straighten, '$estimatedDistance km'),
                        if (estimatedDuration != null) ...[
                          const SizedBox(width: 8),
                          _estimateChip(
                              Icons.schedule, '$estimatedDuration min'),
                        ],
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Estimated',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade600),
                            ),
                            Text(
                              AppCurrency.format(estimatedCost),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _declining ? null : _decline,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.shade700,
                              side: BorderSide(color: Colors.red.shade300),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _declining
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Text('Decline'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _accepting || !_canAcceptCod
                                ? null
                                : _accept,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade700,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: _accepting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Accept Delivery'),
                          ),
                        ),
                      ],
                    ),
                    if (!_canAcceptCod) ...[
                      const SizedBox(height: 10),
                      Text(
                        _codAcceptance!.blockedMessage,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPointTile({
    required IconData icon,
    required Color color,
    required String label,
    required String address,
    String? person,
    LatLng? coords,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
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
              const SizedBox(height: 2),
              Text(
                address,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500),
              ),
              if (person != null && person.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  person,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
              if (coords != null) ...[
                const SizedBox(height: 2),
                Text(
                  '${coords.latitude.toStringAsFixed(5)}, ${coords.longitude.toStringAsFixed(5)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _estimateChip(IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  static String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }
}
