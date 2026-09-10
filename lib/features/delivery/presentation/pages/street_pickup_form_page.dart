import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hudhud_delivery_driver/core/constants/payment_method_codes.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/services/driver_location_heartbeat.dart';
import 'package:hudhud_delivery_driver/core/services/location_service.dart';
import 'package:hudhud_delivery_driver/core/services/places_service.dart';
import 'package:hudhud_delivery_driver/core/utils/ethiopian_phone_number.dart';
import 'package:hudhud_delivery_driver/features/delivery/presentation/pages/street_pickup_confirm_page.dart';

/// Draft values collected before the confirmation / submit step.
class StreetPickupDraft {
  const StreetPickupDraft({
    required this.customerPhone,
    required this.deliveryLocation,
    required this.deliveryLatitude,
    required this.deliveryLongitude,
    this.pickupLocation,
    this.paymentMethod = PaymentMethodCodes.cashOnDelivery,
  });

  final String customerPhone;
  final String deliveryLocation;
  final double deliveryLatitude;
  final double deliveryLongitude;
  final String? pickupLocation;
  final String paymentMethod;
}

/// Collects customer phone and destination for street pickup.
class StreetPickupFormPage extends StatefulWidget {
  const StreetPickupFormPage({super.key});

  @override
  State<StreetPickupFormPage> createState() => _StreetPickupFormPageState();
}

class _StreetPickupFormPageState extends State<StreetPickupFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _searchController = TextEditingController();
  final _addressController = TextEditingController();

  static const LatLng _addisFallback = LatLng(8.9806, 38.7578);
  static const Duration _searchDebounce = Duration(milliseconds: 350);
  static const Duration _geocodeDebounce = Duration(milliseconds: 400);

  GoogleMapController? _mapController;

  /// Confirmed destination (set after place select, or map drag once unlocked).
  LatLng? _destination;
  LatLng? _searchBias;
  LatLng? _cameraTarget;
  bool _geocoding = false;
  bool _loadingCamera = true;
  bool _searchingPlaces = false;
  bool _resolvingPlace = false;

  /// False until the driver picks a Places suggestion; map gestures stay locked.
  bool _mapInteractive = false;

  /// Bumped on each place select so [GoogleMap] remounts at the chosen coords.
  int _mapSessionId = 0;

  /// True while we animate the camera from a search selection (ignore idle sync thrash).
  bool _programmaticCameraMove = false;
  List<PlacePrediction> _predictions = const [];
  Timer? _searchDebounceTimer;
  Timer? _geocodeDebounceTimer;
  int _searchRequestId = 0;
  int _geocodeRequestId = 0;

  /// Skips autocomplete when we set the search field after a place pick / reverse geocode.
  bool _suppressSearchListener = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    unawaited(_initCameraTarget());
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _geocodeDebounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _phoneController.dispose();
    _searchController.dispose();
    _addressController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initCameraTarget() async {
    final heartbeat = getIt<DriverLocationHeartbeat>().lastLatLng;
    LatLng target = _addisFallback;
    if (heartbeat != null) {
      target = LatLng(heartbeat.latitude, heartbeat.longitude);
    } else {
      final pos = await LocationService().getCurrentLocation();
      if (pos != null) {
        target = LatLng(pos.latitude, pos.longitude);
      }
    }
    if (!mounted) return;
    // GPS is only bias / preview — do not fill search or confirm destination yet.
    setState(() {
      _cameraTarget = target;
      _searchBias = target;
      _loadingCamera = false;
    });
  }

  void _setSearchText(String value) {
    _suppressSearchListener = true;
    _searchController.text = value;
    _suppressSearchListener = false;
  }

  Future<void> _reverseGeocode(
    LatLng point, {
    bool syncSearchField = false,
  }) async {
    final requestId = ++_geocodeRequestId;
    setState(() => _geocoding = true);
    try {
      final marks = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      if (!mounted || requestId != _geocodeRequestId) return;
      if (marks.isEmpty) return;
      final p = marks.first;
      final parts = [
        p.street,
        p.subLocality,
        p.locality,
        p.administrativeArea,
      ].whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty);
      final address = parts.join(', ');
      if (address.isNotEmpty) {
        _addressController.text = address;
        if (syncSearchField) {
          _setSearchText(address);
        }
      }
    } catch (_) {
      // Address remains manually editable.
    } finally {
      if (mounted && requestId == _geocodeRequestId) {
        setState(() => _geocoding = false);
      }
    }
  }

  void _onCameraMove(CameraPosition position) {
    _cameraTarget = position.target;
  }

  void _onCameraIdle() {
    if (!_mapInteractive || _programmaticCameraMove) return;
    final target = _cameraTarget;
    if (target == null) return;
    setState(() {
      _destination = target;
      _searchBias = target;
      _predictions = const [];
    });
    _geocodeDebounceTimer?.cancel();
    _geocodeDebounceTimer = Timer(_geocodeDebounce, () {
      unawaited(_reverseGeocode(target, syncSearchField: true));
    });
  }

  Future<void> _animateTo(LatLng point) async {
    _programmaticCameraMove = true;
    try {
      // Unlock rebuild can recreate the platform view; wait for a controller.
      GoogleMapController? controller = _mapController;
      for (var i = 0; i < 20 && controller == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        if (!mounted) return;
        controller = _mapController;
      }
      if (controller == null) return;
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(point, 15),
      );
    } finally {
      // Let the idle callback settle, then re-enable map→search sync.
      await Future<void>.delayed(const Duration(milliseconds: 350));
      _programmaticCameraMove = false;
      if (!mounted) return;
      setState(() {
        _destination = point;
        _cameraTarget = point;
        _searchBias = point;
      });
    }
  }

  void _onSearchChanged() {
    if (_suppressSearchListener) return;
    _searchDebounceTimer?.cancel();
    final query = _searchController.text.trim();
    // Rebuild so the clear / spinner suffix stays in sync with text.
    setState(() {});
    if (query.length < 2) {
      if (_predictions.isNotEmpty || _searchingPlaces) {
        setState(() {
          _predictions = const [];
          _searchingPlaces = false;
        });
      }
      return;
    }
    _searchDebounceTimer = Timer(_searchDebounce, () {
      unawaited(_runAutocomplete(query));
    });
  }

  Future<void> _runAutocomplete(String query) async {
    final requestId = ++_searchRequestId;
    setState(() => _searchingPlaces = true);
    try {
      final results = await getIt<PlacesService>().autocomplete(
        query,
        bias: _searchBias ?? _destination ?? _addisFallback,
      );
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _predictions = results;
        _searchingPlaces = false;
      });
    } on PlacesException catch (e) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _predictions = const [];
        _searchingPlaces = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _predictions = const [];
        _searchingPlaces = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _mapInteractive
                ? 'Place search failed. Try again or adjust the map pin.'
                : 'Place search failed. Try a different search.',
          ),
        ),
      );
    }
  }

  Future<void> _selectPrediction(PlacePrediction prediction) async {
    FocusScope.of(context).unfocus();
    _searchDebounceTimer?.cancel();
    _geocodeDebounceTimer?.cancel();
    _searchRequestId++; // drop any in-flight autocomplete
    setState(() {
      _resolvingPlace = true;
      _predictions = const [];
      _searchingPlaces = false;
    });
    _setSearchText(prediction.description);
    try {
      final details =
          await getIt<PlacesService>().placeDetails(prediction.placeId);
      if (!mounted) return;
      _programmaticCameraMove = true;
      _mapController = null;
      setState(() {
        _destination = details.location;
        _cameraTarget = details.location;
        _searchBias = details.location;
        _mapInteractive = true;
        _mapSessionId++;
        _addressController.text = details.formattedAddress;
        _resolvingPlace = false;
      });
      _setSearchText(details.formattedAddress.isNotEmpty
          ? details.formattedAddress
          : prediction.description);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      await _animateTo(details.location);
    } on PlacesException catch (e) {
      if (!mounted) return;
      setState(() => _resolvingPlace = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _resolvingPlace = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _mapInteractive
                ? 'Could not open that place. Try another or adjust the map.'
                : 'Could not open that place. Try another search result.',
          ),
        ),
      );
    }
  }

  Future<void> _continueToConfirm() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_mapInteractive || _destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Search and select a destination first.'),
        ),
      );
      return;
    }
    final dest = _destination!;
    final phone = EthiopianPhoneNumber.tryNormalize(_phoneController.text);
    if (phone == null) return;

    final draft = StreetPickupDraft(
      customerPhone: phone,
      deliveryLocation: _addressController.text.trim(),
      deliveryLatitude: dest.latitude,
      deliveryLongitude: dest.longitude,
    );

    final created = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => StreetPickupConfirmPage(draft: draft),
      ),
    );
    if (created != null && mounted) {
      Navigator.of(context).pop(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapTarget = _destination ?? _cameraTarget ?? _searchBias;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Street pickup'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Customer phone',
                hintText: '0911…',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: EthiopianPhoneNumber.formValidator,
            ),
            const SizedBox(height: 16),
            Text(
              'Delivery destination',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _mapInteractive
                  ? 'Adjust the map if needed — the pin marks the destination.'
                  : 'Search “Where to?” and select a suggestion to unlock the map.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Where to?',
                hintText: 'Bole Atlas, Piazza…',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchingPlaces || _resolvingPlace
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : (_searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _predictions = const []);
                            },
                          )
                        : null),
              ),
            ),
            if (_predictions.isNotEmpty) ...[
              const SizedBox(height: 4),
              Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(10),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _predictions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final p = _predictions[index];
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.place_outlined,
                          color: Colors.orange.shade700,
                        ),
                        title: Text(
                          p.mainText ?? p.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: p.secondaryText != null
                            ? Text(
                                p.secondaryText!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        onTap: _resolvingPlace
                            ? null
                            : () => unawaited(_selectPrediction(p)),
                      );
                    },
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 320,
                child: _loadingCamera || mapTarget == null
                    ? const Center(child: CircularProgressIndicator())
                    : Stack(
                        alignment: Alignment.center,
                        children: [
                          GoogleMap(
                            key: ValueKey('street-pickup-map-$_mapSessionId'),
                            initialCameraPosition: CameraPosition(
                              target: mapTarget,
                              zoom: 15,
                            ),
                            onMapCreated: (c) {
                              _mapController = c;
                              final dest = _destination;
                              if (dest != null) {
                                _programmaticCameraMove = true;
                                unawaited(() async {
                                  try {
                                    await c.moveCamera(
                                      CameraUpdate.newLatLngZoom(dest, 15),
                                    );
                                  } finally {
                                    await Future<void>.delayed(
                                      const Duration(milliseconds: 350),
                                    );
                                    _programmaticCameraMove = false;
                                  }
                                }());
                              }
                            },
                            onCameraMove: _onCameraMove,
                            onCameraIdle: _onCameraIdle,
                            myLocationEnabled: true,
                            myLocationButtonEnabled: _mapInteractive,
                            zoomControlsEnabled: _mapInteractive,
                            scrollGesturesEnabled: _mapInteractive,
                            zoomGesturesEnabled: _mapInteractive,
                            tiltGesturesEnabled: _mapInteractive,
                            rotateGesturesEnabled: _mapInteractive,
                            // Win gesture arena over the parent ListView so
                            // pan / pinch-zoom work reliably inside the form.
                            gestureRecognizers: _mapInteractive
                                ? <Factory<OneSequenceGestureRecognizer>>{
                                    Factory<OneSequenceGestureRecognizer>(
                                      () => EagerGestureRecognizer(),
                                    ),
                                  }
                                : const <Factory<
                                    OneSequenceGestureRecognizer>>{},
                          ),
                          // Fixed center pin — destination is always the map center.
                          IgnorePointer(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 36),
                              child: Icon(
                                Icons.location_on,
                                size: 44,
                                color: Colors.orange.shade700,
                                shadows: const [
                                  Shadow(
                                    blurRadius: 4,
                                    color: Colors.black38,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (!_mapInteractive)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: ColoredBox(
                                  color: Colors.black.withOpacity(0.35),
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                      ),
                                      child: Text(
                                        'Search and select a destination to use the map',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          shadows: const [
                                            Shadow(
                                              blurRadius: 4,
                                              color: Colors.black54,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
            if (_geocoding) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(minHeight: 2),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressController,
              textInputAction: TextInputAction.next,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Delivery address',
                hintText: 'Bole Atlas, Addis Ababa',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.place_outlined),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Enter the delivery address';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _continueToConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Review & confirm'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
