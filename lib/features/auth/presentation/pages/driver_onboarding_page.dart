import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:hudhud_delivery_driver/common/theme/app_text_styles.dart';
import 'package:hudhud_delivery_driver/core/auth/logout_helper.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';
import 'package:hudhud_delivery_driver/core/services/driver_application_service.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/theme/auth_colors.dart';

/// The application a rider signed in by SMS code was never asked for.
///
/// Passwordless sign-in creates the account from a phone number alone, so a new
/// rider arrives here with no name, vehicle, licence or photo on file. Before
/// this screen existed they went straight to "Application Pending", which left
/// them waiting on a review of an empty application that no admin could approve.
///
/// Reached through [ApplicationStatusGate] when the stored status is
/// `onboarding_required`, so splash and login both land here without either
/// knowing about it. Submitting moves the rider to `pending`, and the same gate
/// then sends them to the pending screen instead.
class DriverOnboardingPage extends StatefulWidget {
  const DriverOnboardingPage({super.key});

  @override
  State<DriverOnboardingPage> createState() => _DriverOnboardingPageState();
}

class _DriverOnboardingPageState extends State<DriverOnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  final _service = DriverApplicationService();
  final _picker = ImagePicker();

  final _nameController = TextEditingController();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _colorController = TextEditingController();
  final _plateController = TextEditingController();
  final _licenceController = TextEditingController();
  final _yearController = TextEditingController();
  final _areaController = TextEditingController();

  DriverApplication? _application;
  String? _vehicleType;
  final List<String> _serviceAreas = <String>[];
  File? _photo;

  bool _loading = true;
  bool _submitting = false;
  String? _loadError;
  Map<String, List<String>> _fieldErrors = const <String, List<String>>{};

  /// Fallback list for the rare case the server does not send one, so the form
  /// is never unusable. The server's list wins whenever it arrives.
  static const List<String> _fallbackVehicleTypes = <String>[
    'bicycle',
    'motorcycle',
    'car',
    'bajaj',
    'pickup',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _nameController,
      _makeController,
      _modelController,
      _colorController,
      _plateController,
      _licenceController,
      _yearController,
      _areaController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _vehicleTypes =>
      _application?.vehicleTypes.isNotEmpty == true
          ? _application!.vehicleTypes
          : _fallbackVehicleTypes;

  /// A bicycle has no licence, plate or year; everything else must bring them.
  bool get _needsMotorDocuments =>
      _application?.requiresMotorDocuments(_vehicleType) ??
      (_vehicleType != null && _vehicleType != 'bicycle');

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final application = await _service.fetch();
      if (!mounted) return;

      // Fill back anything already on file, so a half-finished application is
      // corrected rather than retyped.
      _nameController.text = application.name ?? '';
      _makeController.text = application.vehicleMake ?? '';
      _modelController.text = application.vehicleModel ?? '';
      _colorController.text = application.vehicleColor ?? '';
      _plateController.text = application.vehiclePlateNumber ?? '';
      _licenceController.text = application.driverLicenseNumber ?? '';
      _yearController.text = application.vehicleYear?.toString() ?? '';
      _serviceAreas
        ..clear()
        ..addAll(application.serviceAreas);

      setState(() {
        _application = application;
        _vehicleType = application.vehicleTypes.contains(application.vehicleType)
            ? application.vehicleType
            : null;
        _loading = false;
      });
    } on DriverApplicationException catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.message;
        _loading = false;
      });
    }
  }

  void _addArea() {
    final value = _areaController.text.trim();
    if (value.isEmpty) return;
    if (_serviceAreas.any((a) => a.toLowerCase() == value.toLowerCase())) {
      _areaController.clear();
      return;
    }
    setState(() {
      _serviceAreas.add(value);
      _areaController.clear();
    });
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() => _photo = File(picked.path));
      }
    } catch (_) {
      _snack('Could not open your photos.');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() => _photo = File(picked.path));
      }
    } catch (_) {
      _snack('Could not open the camera.');
    }
  }

  void _snack(String message, {bool error = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _fieldErrors = const <String, List<String>>{});

    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_vehicleType == null) {
      _snack('Choose the vehicle you will use.');
      return;
    }
    if (_serviceAreas.isEmpty) {
      _snack('Add at least one area you will work in.');
      return;
    }
    // Required the first time; a photo already on file still stands.
    if (_photo == null && !(_application?.hasProfilePicture ?? false)) {
      _snack('Add a clear photo of your face.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await _service.submit(
        name: _nameController.text.trim(),
        vehicleType: _vehicleType!,
        vehicleMake: _makeController.text.trim(),
        vehicleModel: _modelController.text.trim(),
        vehicleColor: _colorController.text.trim(),
        serviceAreas: _serviceAreas,
        driverLicenseNumber:
            _needsMotorDocuments ? _licenceController.text.trim() : null,
        vehiclePlateNumber:
            _needsMotorDocuments ? _plateController.text.trim() : null,
        vehicleYear: _needsMotorDocuments
            ? int.tryParse(_yearController.text.trim())
            : null,
        profilePicture: _photo,
      );

      if (!mounted) return;
      _snack('Application submitted. We will review it shortly.', error: false);

      // The service already stored the new status, so the gate will keep the
      // rider here no longer.
      if (result.state == 'accepted') {
        context.goNamed(AppRouter.dashboard);
      } else {
        context.goNamed(AppRouter.applicationPending);
      }
    } on DriverApplicationException catch (error) {
      if (!mounted) return;
      setState(() => _fieldErrors = error.fieldErrors);
      _snack(error.fieldErrors.isEmpty
          ? error.message
          : 'Please correct the highlighted fields.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _serverError(String field) {
    final errors = _fieldErrors[field];
    return errors == null || errors.isEmpty ? null : errors.first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('Complete your application',
            style: AppTextStyles.headline2.copyWith(color: AuthColors.title)),
        actions: [
          TextButton(
            onPressed: () => LogoutHelper.logout(),
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _buildLoadError()
              : _buildForm(),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_loadError!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(color: AuthColors.label)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              'You are signed in. Before you can take jobs we need a few '
              'details, then HudHud will review your application.',
              style: AppTextStyles.bodyMedium.copyWith(color: AuthColors.label),
            ),
            const SizedBox(height: 24),

            _label('Full name'),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: _input('First and last name'),
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty) return 'Enter your name.';
                if (!text.contains(RegExp(r'\s'))) {
                  return 'Enter your first and last name.';
                }
                return _serverError('name');
              },
            ),
            const SizedBox(height: 20),

            _label('Vehicle'),
            DropdownButtonFormField<String>(
              value: _vehicleType,
              decoration: _input('Choose a vehicle'),
              items: _vehicleTypes
                  .map((type) => DropdownMenuItem<String>(
                        value: type,
                        child: Text(_vehicleLabel(type)),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _vehicleType = value),
            ),
            if (_serverError('vehicle_type') != null) _error('vehicle_type'),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _makeController,
                    decoration: _input('Make (e.g. Toyota)'),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Required'
                        : _serverError('vehicle_make'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _modelController,
                    decoration: _input('Model (e.g. Vitz)'),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Required'
                        : _serverError('vehicle_model'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _colorController,
              decoration: _input('Colour'),
              validator: (v) => (v ?? '').trim().isEmpty
                  ? 'Required'
                  : _serverError('vehicle_color'),
            ),

            // A bicycle has none of these, so asking for them would block an
            // application that is already complete.
            if (_needsMotorDocuments) ...[
              const SizedBox(height: 24),
              _label('Licence and plate'),
              TextFormField(
                controller: _licenceController,
                textCapitalization: TextCapitalization.characters,
                decoration: _input('Driving licence number'),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? 'Required for this vehicle.'
                    : _serverError('driver_license_number'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _plateController,
                textCapitalization: TextCapitalization.characters,
                decoration: _input('Plate number'),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? 'Required for this vehicle.'
                    : _serverError('vehicle_plate_number'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _yearController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                decoration: _input('Year (e.g. 2018)'),
                validator: (value) {
                  final year = int.tryParse((value ?? '').trim());
                  if (year == null) return 'Required for this vehicle.';
                  if (year < 1990 || year > DateTime.now().year + 1) {
                    return 'Enter a valid year.';
                  }
                  return _serverError('vehicle_year');
                },
              ),
            ],

            const SizedBox(height: 24),
            _label('Where will you work?'),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _areaController,
                    textCapitalization: TextCapitalization.words,
                    decoration: _input('Area (e.g. Bole)'),
                    onFieldSubmitted: (_) => _addArea(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _addArea,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            if (_serviceAreas.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _serviceAreas
                    .map((area) => Chip(
                          label: Text(area),
                          onDeleted: () =>
                              setState(() => _serviceAreas.remove(area)),
                        ))
                    .toList(),
              ),
            ],
            if (_serverError('service_areas') != null) _error('service_areas'),

            const SizedBox(height: 24),
            _label('Your photo'),
            Text(
              'A clear photo of your face. Customers see this when you arrive.',
              style: AppTextStyles.bodyMedium.copyWith(color: AuthColors.hint),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (_photo != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_photo!,
                        width: 72, height: 72, fit: BoxFit.cover),
                  )
                else if (_application?.hasProfilePicture == true)
                  const Icon(Icons.check_circle, color: Colors.green, size: 40),
                if (_photo != null || _application?.hasProfilePicture == true)
                  const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _takePhoto,
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Camera'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _pickPhoto,
                        icon: const Icon(Icons.photo_outlined),
                        label: const Text('Gallery'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_serverError('profile_picture') != null) _error('profile_picture'),

            const SizedBox(height: 32),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AuthColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Submit for review'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AuthColors.title, fontWeight: FontWeight.w600)),
      );

  Widget _error(String field) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(_serverError(field) ?? '',
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.red)),
      );

  InputDecoration _input(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AuthColors.hint),
        filled: true,
        fillColor: AuthColors.inputBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AuthColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AuthColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AuthColors.primary),
        ),
      );

  String _vehicleLabel(String type) {
    switch (type) {
      case 'bicycle':
        return 'Bicycle';
      case 'motorcycle':
        return 'Motorcycle';
      case 'car':
        return 'Car';
      case 'bajaj':
        return 'Bajaj';
      case 'pickup':
        return 'Pickup';
      default:
        return type;
    }
  }
}
