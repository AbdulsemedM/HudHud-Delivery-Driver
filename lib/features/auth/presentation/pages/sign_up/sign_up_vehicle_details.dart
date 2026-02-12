import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/pages/sign_up/sign_up_otp_verification.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/widgets/custom_text_field.dart';

/// Vehicle type options for driver registration (API values: car, motorcycle, bike).
enum VehicleTypeOption {
  car('car', 'Car', Icons.directions_car),
  motorcycle('motorcycle', 'Motorcycle', Icons.two_wheeler),
  bike('bike', 'Bike', Icons.pedal_bike);

  const VehicleTypeOption(this.value, this.label, this.icon);
  final String value;
  final String label;
  final IconData icon;
}

class SignUpVehicleDetails extends StatefulWidget {
  final String name;
  final String email;
  final String phone;
  final String password;

  const SignUpVehicleDetails({
    Key? key,
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
  }) : super(key: key);

  @override
  State<SignUpVehicleDetails> createState() => _SignUpVehicleDetailsState();
}

class _SignUpVehicleDetailsState extends State<SignUpVehicleDetails> {
  final TextEditingController _licenseController = TextEditingController();
  final TextEditingController _plateController = TextEditingController();
  final TextEditingController _makeController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _serviceAreasController = TextEditingController();

  VehicleTypeOption _selectedVehicleType = VehicleTypeOption.car;
  String? _licenseError;
  String? _plateError;
  String? _makeError;
  String? _modelError;
  String? _yearError;
  String? _colorError;
  String? _serviceAreasError;
  bool _isLoading = false;

  @override
  void dispose() {
    _licenseController.dispose();
    _plateController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    _serviceAreasController.dispose();
    super.dispose();
  }

  bool _validateForm() {
    bool isValid = true;

    if (_licenseController.text.trim().isEmpty) {
      setState(() => _licenseError = 'Driver license number is required');
      isValid = false;
    } else {
      setState(() => _licenseError = null);
    }

    if (_plateController.text.trim().isEmpty) {
      setState(() => _plateError = 'Plate number is required');
      isValid = false;
    } else {
      setState(() => _plateError = null);
    }

    if (_makeController.text.trim().isEmpty) {
      setState(() => _makeError = 'Vehicle make is required');
      isValid = false;
    } else {
      setState(() => _makeError = null);
    }

    if (_modelController.text.trim().isEmpty) {
      setState(() => _modelError = 'Vehicle model is required');
      isValid = false;
    } else {
      setState(() => _modelError = null);
    }

    final yearStr = _yearController.text.trim();
    if (yearStr.isEmpty) {
      setState(() => _yearError = 'Vehicle year is required');
      isValid = false;
    } else {
      final year = int.tryParse(yearStr);
      final currentYear = DateTime.now().year;
      if (year == null || year < 1990 || year > currentYear + 1) {
        setState(() => _yearError = 'Enter a valid year (1990–${currentYear + 1})');
        isValid = false;
      } else {
        setState(() => _yearError = null);
      }
    }

    if (_colorController.text.trim().isEmpty) {
      setState(() => _colorError = 'Vehicle color is required');
      isValid = false;
    } else {
      setState(() => _colorError = null);
    }

    final areas = _serviceAreasController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (areas.isEmpty) {
      setState(() => _serviceAreasError = 'Enter at least one service area');
      isValid = false;
    } else {
      setState(() => _serviceAreasError = null);
    }

    return isValid;
  }

  Future<void> _registerDriver() async {
    if (!_validateForm()) return;

    setState(() => _isLoading = true);

    try {
      final serviceAreas = _serviceAreasController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final result = await ApiService.registerDriver(
        name: widget.name,
        email: widget.email,
        phone: widget.phone,
        password: widget.password,
        passwordConfirmation: widget.password,
        driverLicenseNumber: _licenseController.text.trim(),
        vehicleType: _selectedVehicleType.value,
        vehiclePlateNumber: _plateController.text.trim(),
        vehicleMake: _makeController.text.trim(),
        vehicleModel: _modelController.text.trim(),
        vehicleYear: int.parse(_yearController.text.trim()),
        vehicleColor: _colorController.text.trim(),
        serviceAreas: serviceAreas,
      );

      if (result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['message']?.toString() ??
                    'Registration successful. Please upload documents for verification.',
              ),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SignUpOtpVerification(
                email: widget.email,
                phone: widget.phone,
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']?.toString() ?? 'Registration failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vehicle & license',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select your vehicle type and enter your license and vehicle details.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // Vehicle type: 3 choices
            const Text(
              'Vehicle type',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: VehicleTypeOption.values.map((type) {
                final isSelected = _selectedVehicleType == type;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Material(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () =>
                            setState(() => _selectedVehicleType = type),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 8,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                type.icon,
                                size: 32,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.onPrimaryContainer
                                    : Colors.grey.shade700,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                type.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.onPrimaryContainer
                                      : Colors.grey.shade700,
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

            CustomTextField(
              hintText: 'Driver license number',
              controller: _licenseController,
              errorText: _licenseError,
              onChanged: (_) =>
                  setState(() => _licenseError = null),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              hintText: 'Vehicle plate number',
              controller: _plateController,
              errorText: _plateError,
              onChanged: (_) =>
                  setState(() => _plateError = null),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    hintText: 'Make (e.g. Toyota)',
                    controller: _makeController,
                    errorText: _makeError,
                    onChanged: (_) =>
                        setState(() => _makeError = null),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomTextField(
                    hintText: 'Model (e.g. Camry)',
                    controller: _modelController,
                    errorText: _modelError,
                    onChanged: (_) =>
                        setState(() => _modelError = null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: CustomTextField(
                    hintText: 'Year',
                    controller: _yearController,
                    keyboardType: TextInputType.number,
                    errorText: _yearError,
                    onChanged: (_) =>
                        setState(() => _yearError = null),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: CustomTextField(
                    hintText: 'Color',
                    controller: _colorController,
                    errorText: _colorError,
                    onChanged: (_) =>
                        setState(() => _colorError = null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CustomTextField(
              hintText: 'Service areas (e.g. Manhattan, Brooklyn)',
              controller: _serviceAreasController,
              errorText: _serviceAreasError,
              onChanged: (_) =>
                  setState(() => _serviceAreasError = null),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter areas separated by commas',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _registerDriver,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Complete registration'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
