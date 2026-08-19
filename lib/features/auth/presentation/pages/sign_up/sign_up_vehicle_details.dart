import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hudhud_delivery_driver/common/theme/app_text_styles.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/services/notification_service.dart';
import 'package:hudhud_delivery_driver/features/auth/data/models/driver_registration_data.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/theme/auth_colors.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/widgets/auth_header.dart';

class SignUpVehicleDetails extends StatefulWidget {
  final DriverAccountData account;

  const SignUpVehicleDetails({
    super.key,
    required this.account,
  });

  @override
  State<SignUpVehicleDetails> createState() => _SignUpVehicleDetailsState();
}

class _SignUpVehicleDetailsState extends State<SignUpVehicleDetails> {
  static const _presetColors = [
    'Black',
    'White',
    'Red',
    'Blue',
    'Green',
  ];

  final _licenseController = TextEditingController();
  final _plateController = TextEditingController();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _customColorController = TextEditingController();
  final _serviceAreasController = TextEditingController();

  VehicleType _selectedVehicleType = VehicleType.bicycle;
  String? _selectedColor;
  bool _useCustomColor = false;
  File? _profilePicture;
  bool _isLoading = false;
  bool _rateLimitActive = false;
  bool _showUnavailableRetry = false;
  String? _accountErrorBanner;
  Timer? _rateLimitTimer;

  final Map<String, String?> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _licenseController,
      _plateController,
      _makeController,
      _modelController,
      _yearController,
      _customColorController,
      _serviceAreasController,
    ]) {
      controller.addListener(_onFormChanged);
    }
  }

  @override
  void dispose() {
    _rateLimitTimer?.cancel();
    _licenseController.dispose();
    _plateController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _customColorController.dispose();
    _serviceAreasController.dispose();
    super.dispose();
  }

  void _onFormChanged() => setState(() {});

  bool get _isMotorVehicle => _selectedVehicleType != VehicleType.bicycle;

  String get _vehicleColor {
    if (_useCustomColor) return _customColorController.text.trim();
    return _selectedColor ?? '';
  }

  bool get _canSubmit {
    if (_isLoading || _rateLimitActive || _profilePicture == null) return false;

    if (_makeController.text.trim().isEmpty ||
        _modelController.text.trim().isEmpty ||
        _vehicleColor.isEmpty) {
      return false;
    }

    if (_isMotorVehicle) {
      if (_licenseController.text.trim().isEmpty ||
          _plateController.text.trim().isEmpty ||
          _yearController.text.trim().isEmpty) {
        return false;
      }
    }

    final areas = DriverRegistrationData.serviceAreasFromInput(
      _serviceAreasController.text,
    );
    if (areas.isEmpty) return false;

    if (DriverRegistrationData.photoValidationError(_profilePicture!) != null) {
      return false;
    }

    return true;
  }

  (String title, String subtitle) get _headerCopy {
    switch (_selectedVehicleType) {
      case VehicleType.bicycle:
        return (
          'Your bicycle',
          'Add a face photo and tell us about your bicycle and service areas.',
        );
      case VehicleType.motorcycle:
        return (
          'Vehicle & license',
          'Add a face photo, license details, and motorcycle information.',
        );
      case VehicleType.car:
        return (
          'Vehicle & license',
          'Add a face photo, license details, and car information.',
        );
    }
  }

  (String makeHint, String modelHint) get _makeModelHints {
    switch (_selectedVehicleType) {
      case VehicleType.bicycle:
        return ('Eg. Giant', 'Eg. Escape 3');
      case VehicleType.motorcycle:
        return ('Eg. Honda', 'Eg. CB 125');
      case VehicleType.car:
        return ('Eg. Toyota', 'Eg. Corolla');
    }
  }

  InputDecoration _decoration(String hint, {String? errorText}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AuthColors.hint, fontSize: 14),
      filled: true,
      fillColor: AuthColors.inputBg,
      errorText: errorText,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AuthColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: errorText != null ? Colors.red : AuthColors.border,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: errorText != null ? Colors.red : AuthColors.primary,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  void _clearFieldError(String key) {
    if (_fieldErrors.containsKey(key)) {
      setState(() => _fieldErrors.remove(key));
    }
  }

  void _selectVehicleType(VehicleType type) {
    setState(() {
      _selectedVehicleType = type;
      _fieldErrors.remove('driver_license_number');
      _fieldErrors.remove('vehicle_plate_number');
      _fieldErrors.remove('vehicle_year');
      if (type == VehicleType.bicycle) {
        _licenseController.clear();
        _plateController.clear();
      }
    });
  }

  void _selectColor(String color) {
    setState(() {
      _selectedColor = color;
      _useCustomColor = false;
      _customColorController.clear();
      _clearFieldError('vehicle_color');
    });
  }

  void _selectOtherColor() {
    setState(() {
      _useCustomColor = true;
      _selectedColor = null;
      _clearFieldError('vehicle_color');
    });
  }

  Future<void> _pickFacePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose Photo'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      imageQuality: 85,
    );
    if (xFile == null || !mounted) return;

    final file = File(xFile.path);
    setState(() {
      _profilePicture = file;
      _fieldErrors['profile_picture'] =
          DriverRegistrationData.photoValidationError(file);
      if (_fieldErrors['profile_picture'] == null) {
        _fieldErrors.remove('profile_picture');
      }
    });
  }

  DriverRegistrationData _buildRegistrationData({String? deviceToken}) {
    final yearText = _yearController.text.trim();
    final year = yearText.isEmpty ? null : int.tryParse(yearText);

    return DriverRegistrationData.fromAccount(
      account: widget.account,
      vehicleType: _selectedVehicleType,
      profilePicture: _profilePicture!,
      driverLicenseNumber:
          _isMotorVehicle ? _licenseController.text.trim() : null,
      vehiclePlateNumber:
          _isMotorVehicle ? _plateController.text.trim() : null,
      vehicleMake: _makeController.text.trim(),
      vehicleModel: _modelController.text.trim(),
      vehicleYear: year,
      vehicleColor: _vehicleColor,
      serviceAreas: DriverRegistrationData.serviceAreasFromInput(
        _serviceAreasController.text,
      ),
      deviceToken: deviceToken,
    );
  }

  void _applyFieldErrors(Map<String, String> errors) {
    setState(() {
      _fieldErrors
        ..clear()
        ..addAll(errors);

      const accountFields = {'name', 'first_name', 'last_name', 'email', 'phone', 'password', 'password_confirmation'};
      final accountIssues = errors.entries
          .where((entry) => accountFields.contains(entry.key))
          .map((entry) => entry.value)
          .toList();

      _accountErrorBanner = accountIssues.isEmpty
          ? null
          : accountIssues.join('\n');
    });
  }

  void _startRateLimitCooldown() {
    _rateLimitTimer?.cancel();
    setState(() => _rateLimitActive = true);
    _rateLimitTimer = Timer(const Duration(seconds: 30), () {
      if (mounted) setState(() => _rateLimitActive = false);
    });
  }

  Future<void> _registerDriver() async {
    if (!_canSubmit) return;

    final registration = _buildRegistrationData();
    final clientErrors = registration.validate();
    if (clientErrors.isNotEmpty) {
      _applyFieldErrors(clientErrors);
      return;
    }

    setState(() {
      _isLoading = true;
      _showUnavailableRetry = false;
      _accountErrorBanner = null;
    });

    try {
      final fcmToken = await getIt<NotificationService>().getFcmToken();
      final payload = _buildRegistrationData(deviceToken: fcmToken);
      final result = await ApiService.registerDriver(payload);

      if (!mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account created. Log in and verify your phone.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        context.goNamed(AppRouter.login);
        return;
      }

      if (result.rateLimited) {
        _startRateLimitCooldown();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.message ??
                  'Too many registration attempts. Please wait a moment and try again.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (result.unavailable) {
        setState(() => _showUnavailableRetry = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.message ??
                  'Driver registration is temporarily unavailable. Please try again.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (result.fieldErrors.isNotEmpty) {
        _applyFieldErrors(result.fieldErrors);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Registration failed.'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _label(String text) {
    return Text(
      text,
      style: AppTextStyles.bodyMedium.copyWith(
        color: AuthColors.label,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  IconData _vehicleIcon(VehicleType type) {
    switch (type) {
      case VehicleType.bicycle:
        return Icons.pedal_bike;
      case VehicleType.motorcycle:
        return Icons.two_wheeler;
      case VehicleType.car:
        return Icons.directions_car;
    }
  }

  @override
  Widget build(BuildContext context) {
    final header = _headerCopy;
    final hints = _makeModelHints;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AuthHeader(
                  onBack: () => Navigator.pop(context),
                ),
                const SizedBox(height: 24),
                Text(
                  header.$1,
                  style: AppTextStyles.headline2.copyWith(
                    color: AuthColors.title,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  header.$2,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AuthColors.label,
                    height: 1.4,
                  ),
                ),
                if (_accountErrorBanner != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _accountErrorBanner!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.red.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Back to account details'),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_showUnavailableRetry) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Text(
                      'Registration is temporarily unavailable. Tap Create Account again when you are ready.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                _label('Vehicle type'),
                const SizedBox(height: 12),
                Row(
                  children: VehicleType.values.map((type) {
                    final isSelected = _selectedVehicleType == type;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Material(
                          color: isSelected
                              ? AuthColors.primary.withOpacity(0.12)
                              : AuthColors.inputBg,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: _isLoading
                                ? null
                                : () => _selectVehicleType(type),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 8,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AuthColors.primary
                                      : AuthColors.border,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _vehicleIcon(type),
                                    size: 28,
                                    color: isSelected
                                        ? AuthColors.primary
                                        : AuthColors.label,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    type.label,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? AuthColors.primary
                                          : AuthColors.label,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                _label('Profile photo'),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _isLoading ? null : _pickFacePhoto,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AuthColors.inputBg,
                      border: Border.all(
                        color: _fieldErrors['profile_picture'] != null
                            ? Colors.red
                            : AuthColors.border,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: _profilePicture != null
                              ? FileImage(_profilePicture!)
                              : null,
                          child: _profilePicture == null
                              ? Icon(
                                  Icons.person,
                                  size: 32,
                                  color: Colors.grey.shade600,
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _profilePicture == null
                                    ? 'Add a clear photo of your face'
                                    : 'Photo selected',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AuthColors.title,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'JPG, JPEG, PNG, or WebP. Max 5 MB.',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AuthColors.hint,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.camera_alt_outlined,
                          color: AuthColors.label,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_fieldErrors['profile_picture'] != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _fieldErrors['profile_picture']!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                if (_isMotorVehicle) ...[
                  _label('Driver license number'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _licenseController,
                    decoration: _decoration(
                      'Enter license number',
                      errorText: _fieldErrors['driver_license_number'],
                    ),
                    onChanged: (_) => _clearFieldError('driver_license_number'),
                  ),
                  const SizedBox(height: 16),
                  _label('Plate number'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _plateController,
                    decoration: _decoration(
                      'Enter plate number',
                      errorText: _fieldErrors['vehicle_plate_number'],
                    ),
                    onChanged: (_) => _clearFieldError('vehicle_plate_number'),
                  ),
                  const SizedBox(height: 16),
                ],

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Make'),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _makeController,
                            decoration: _decoration(
                              hints.$1,
                              errorText: _fieldErrors['vehicle_make'],
                            ),
                            onChanged: (_) => _clearFieldError('vehicle_make'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Model'),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _modelController,
                            decoration: _decoration(
                              hints.$2,
                              errorText: _fieldErrors['vehicle_model'],
                            ),
                            onChanged: (_) => _clearFieldError('vehicle_model'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label(_isMotorVehicle ? 'Year' : 'Year (optional)'),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _yearController,
                            keyboardType: TextInputType.number,
                            decoration: _decoration(
                              '${DriverRegistrationData.minVehicleYear}–${DriverRegistrationData.maxVehicleYear}',
                              errorText: _fieldErrors['vehicle_year'],
                            ),
                            onChanged: (_) => _clearFieldError('vehicle_year'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                _label('Color'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._presetColors.map((color) {
                      final selected = !_useCustomColor && _selectedColor == color;
                      return ChoiceChip(
                        label: Text(color),
                        selected: selected,
                        onSelected: _isLoading ? null : (_) => _selectColor(color),
                        selectedColor: AuthColors.primary.withOpacity(0.15),
                        labelStyle: TextStyle(
                          color: selected ? AuthColors.primary : AuthColors.label,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      );
                    }),
                    ChoiceChip(
                      label: const Text('Other'),
                      selected: _useCustomColor,
                      onSelected:
                          _isLoading ? null : (_) => _selectOtherColor(),
                      selectedColor: AuthColors.primary.withOpacity(0.15),
                      labelStyle: TextStyle(
                        color: _useCustomColor
                            ? AuthColors.primary
                            : AuthColors.label,
                        fontWeight: _useCustomColor
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                if (_useCustomColor) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _customColorController,
                    decoration: _decoration(
                      'Enter color',
                      errorText: _fieldErrors['vehicle_color'],
                    ),
                    onChanged: (_) => _clearFieldError('vehicle_color'),
                  ),
                ] else if (_fieldErrors['vehicle_color'] != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _fieldErrors['vehicle_color']!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                _label('Service areas'),
                const SizedBox(height: 6),
                TextField(
                  controller: _serviceAreasController,
                  decoration: _decoration(
                    'Eg. Bole, Piassa',
                    errorText: _fieldErrors['service_areas'],
                  ),
                  onChanged: (_) => _clearFieldError('service_areas'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter areas separated by commas',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AuthColors.hint,
                  ),
                ),
                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _canSubmit ? _registerDriver : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AuthColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AuthColors.primary.withOpacity(0.4),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _rateLimitActive
                                ? 'Please wait…'
                                : 'Create Account',
                            style: AppTextStyles.button.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
