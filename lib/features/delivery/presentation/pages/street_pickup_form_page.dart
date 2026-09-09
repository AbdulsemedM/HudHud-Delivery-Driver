import 'dart:async';

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
    this.deliveryNotes,
    this.paymentMethod = PaymentMethodCodes.cashOnDelivery,
  });

  final String customerPhone;
  final String deliveryLocation;
  final double deliveryLatitude;
  final double deliveryLongitude;
  final String? pickupLocation;
  final String? deliveryNotes;
  final String paymentMethod;
}

/// Collects customer phone, destination, and notes for street pickup.
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
  final _notesController = TextEditingController();

  static const LatLng _addisFallback = LatLng(8.9806, 38.7578);
  static const Duration _searchDebounce = Duration(milliseconds: 350);

  GoogleMapController? _mapController;
  LatLng? _destination;
  LatLng? _searchBias;
  bool _geocoding = false;
  bool _loadingCamera = true;
  bool _searchingPlaces = false;
  bool _resolvingPlace = false;
  List<PlacePrediction> _predictions = const [];
  Timer? _searchDebounceTimer;
  int _searchRequestId = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    unawaited(_initCameraTarget());
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _phoneController.dispose();
    _searchController.dispose();
    _addressController.dispose();
    _notesController.dispose();
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
    setState(() {
      _destination = target;
      _searchBias = target;
      _loadingCamera = false;
    });
    await _reverseGeocode(target);
  }

  Future<void> _reverseGeocode(LatLng point) async {
    setState(() => _geocoding = true);
    try {
      final marks = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      if (!mounted || marks.isEmpty) return;
      final p = marks.first;
      final parts = [
        p.street,
        p.subLocality,
        p.locality,
        p.administrativeArea,
      ]
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty);
      final address = parts.join(', ');
      if (address.isNotEmpty) {
        _addressController.text = address;
      }
    } catch (_) {
      // Address remains manually editable.
    } finally {
      if (mounted) setState(() => _geocoding = false);
    }
  }

  void _onMapTap(LatLng point) {
    setState(() {
      _destination = point;
      _predictions = const [];
    });
    unawaited(_animateTo(point));
    unawaited(_reverseGeocode(point));
  }

  Future<void> _animateTo(LatLng point) async {
    final controller = _mapController;
    if (controller == null) return;
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(point, 15),
    );
  }

  void _onSearchChanged() {
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
        const SnackBar(
          content: Text('Place search failed. You can tap the map instead.'),
        ),
      );
    }
  }

  Future<void> _selectPrediction(PlacePrediction prediction) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _resolvingPlace = true;
      _predictions = const [];
      _searchController.text = prediction.description;
    });
    try {
      final details =
          await getIt<PlacesService>().placeDetails(prediction.placeId);
      if (!mounted) return;
      setState(() {
        _destination = details.location;
        _addressController.text = details.formattedAddress;
        _resolvingPlace = false;
      });
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
        const SnackBar(
          content: Text('Could not open that place. Try another or tap the map.'),
        ),
      );
    }
  }

  Future<void> _continueToConfirm() async {
    if (!_formKey.currentState!.validate()) return;
    final dest = _destination;
    if (dest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Search or tap the map to set the delivery destination.'),
        ),
      );
      return;
    }
    final phone = EthiopianPhoneNumber.tryNormalize(_phoneController.text);
    if (phone == null) return;

    final draft = StreetPickupDraft(
      customerPhone: phone,
      deliveryLocation: _addressController.text.trim(),
      deliveryLatitude: dest.latitude,
      deliveryLongitude: dest.longitude,
      deliveryNotes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => StreetPickupConfirmPage(draft: draft),
      ),
    );
    if (created == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dest = _destination;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Street pickup'),
        backgroundColor: Colors.deepOrange.shade700,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text(
              'Create a delivery for a customer you met on the street. '
              'They must already have a HudHud account.',
              style: TextStyle(color: Colors.grey.shade700, height: 1.35),
            ),
            const SizedBox(height: 20),
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
              'Search “Where to?” or tap the map to set coordinates.',
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
                          color: Colors.deepOrange.shade700,
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
                height: 220,
                child: _loadingCamera || dest == null
                    ? const Center(child: CircularProgressIndicator())
                    : GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: dest,
                          zoom: 15,
                        ),
                        onMapCreated: (c) => _mapController = c,
                        onTap: _onMapTap,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                        markers: {
                          Marker(
                            markerId: const MarkerId('destination'),
                            position: dest,
                            draggable: true,
                            onDragEnd: _onMapTap,
                          ),
                        },
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
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              textInputAction: TextInputAction.done,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes — optional',
                hintText: 'Call the customer on arrival',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.money, color: Colors.deepOrange.shade700),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Payment method: Cash on delivery',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _continueToConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange.shade700,
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
