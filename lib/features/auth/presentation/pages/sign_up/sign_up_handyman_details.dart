import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/pages/sign_up/sign_up_otp_verification.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/theme/auth_colors.dart';

/// Available skills a handyman can select.
const List<String> _availableSkills = [
  'plumbing',
  'electrical',
  'carpentry',
  'painting',
  'tiling',
  'roofing',
  'landscaping',
  'cleaning',
  'appliance repair',
  'general maintenance',
];

/// Service type options.
const List<String> _serviceTypes = [
  'handyman',
  'specialist',
  'contractor',
];

class SignUpHandymanDetails extends StatefulWidget {
  final String name;
  final String email;
  final String phone;
  final String password;

  const SignUpHandymanDetails({
    Key? key,
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
  }) : super(key: key);

  @override
  State<SignUpHandymanDetails> createState() => _SignUpHandymanDetailsState();
}

class _SignUpHandymanDetailsState extends State<SignUpHandymanDetails> {
  final _formKey = GlobalKey<FormState>();

  final _hourlyRateController = TextEditingController();
  final _experienceController = TextEditingController();
  final _serviceRadiusController = TextEditingController();
  final _addressController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _bioController = TextEditingController();

  final Set<String> _selectedSkills = {};
  String _selectedServiceType = _serviceTypes.first;
  bool _isLoading = false;

  @override
  void dispose() {
    _hourlyRateController.dispose();
    _experienceController.dispose();
    _serviceRadiusController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String hint,
      {Widget? suffixIcon, Widget? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AuthColors.hint, fontSize: 14),
      filled: true,
      fillColor: AuthColors.inputBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AuthColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AuthColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AuthColors.primary, width: 1.5),
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
      suffixIcon: suffixIcon,
      prefixIcon: prefixIcon,
    );
  }

  Future<void> _registerHandyman() async {
    if (_selectedSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one skill'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.registerHandyman(
        name: widget.name,
        email: widget.email,
        phone: widget.phone,
        password: widget.password,
        passwordConfirmation: widget.password,
        skills: _selectedSkills.toList(),
        serviceType: _selectedServiceType,
        hourlyRate: double.parse(_hourlyRateController.text.trim()),
        experienceYears: int.parse(_experienceController.text.trim()),
        serviceRadius: int.parse(_serviceRadiusController.text.trim()),
        address: _addressController.text.trim(),
        latitude: double.parse(_latitudeController.text.trim()),
        longitude: double.parse(_longitudeController.text.trim()),
        bio: _bioController.text.trim(),
      );

      if (result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['message']?.toString() ??
                    'Registration successful! Please verify your email.',
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
              content:
                  Text(result['message']?.toString() ?? 'Registration failed'),
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
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Handyman Details',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AuthColors.title,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter your professional details and skills to complete registration.',
                style: TextStyle(
                    fontSize: 14, color: AuthColors.label, height: 1.4),
              ),
              const SizedBox(height: 24),

              // Skills selection
              const Text(
                'Skills',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AuthColors.label,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select all skills that apply',
                style: TextStyle(fontSize: 12, color: AuthColors.hint),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableSkills.map((skill) {
                  final isSelected = _selectedSkills.contains(skill);
                  return FilterChip(
                    label: Text(
                      skill[0].toUpperCase() + skill.substring(1),
                      style: TextStyle(
                        fontSize: 13,
                        color: isSelected ? Colors.white : AuthColors.label,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedSkills.add(skill);
                        } else {
                          _selectedSkills.remove(skill);
                        }
                      });
                    },
                    selectedColor: AuthColors.primary,
                    backgroundColor: AuthColors.inputBg,
                    checkmarkColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color:
                            isSelected ? AuthColors.primary : AuthColors.border,
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (_selectedSkills.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${_selectedSkills.length} skill(s) selected',
                  style:
                      const TextStyle(fontSize: 12, color: AuthColors.primary),
                ),
              ],
              const SizedBox(height: 24),

              // Service type
              _label('Service Type'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedServiceType,
                decoration: _decoration('Select service type'),
                items: _serviceTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(
                      type[0].toUpperCase() + type.substring(1),
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedServiceType = value);
                  }
                },
              ),
              const SizedBox(height: 20),

              // Hourly rate and Experience years side by side
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Hourly Rate (\$)'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _hourlyRateController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: _decoration('e.g. 35.00'),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            final rate = double.tryParse(v);
                            if (rate == null || rate <= 0)
                              return 'Invalid rate';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Experience (yrs)'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _experienceController,
                          keyboardType: TextInputType.number,
                          decoration: _decoration('e.g. 5'),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            final years = int.tryParse(v);
                            if (years == null || years < 0) return 'Invalid';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Service radius
              _label('Service Radius (km)'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _serviceRadiusController,
                keyboardType: TextInputType.number,
                decoration: _decoration('e.g. 20'),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final radius = int.tryParse(v);
                  if (radius == null || radius <= 0) return 'Invalid radius';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Address
              _label('Address'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _addressController,
                decoration:
                    _decoration('e.g. 456 Handyman Street, City, Country'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 20),

              // Latitude and Longitude
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Latitude'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _latitudeController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: _decoration('e.g. 40.7129'),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            final lat = double.tryParse(v);
                            if (lat == null || lat < -90 || lat > 90)
                              return 'Invalid';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Longitude'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _longitudeController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: _decoration('e.g. -74.0061'),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            final lng = double.tryParse(v);
                            if (lng == null || lng < -180 || lng > 180)
                              return 'Invalid';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Bio
              _label('Bio'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _bioController,
                maxLines: 3,
                decoration: _decoration(
                  'Tell clients about yourself and your experience...',
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 32),

              // Register button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _registerHandyman,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AuthColors.primary,
                    foregroundColor: Colors.white,
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
                      : const Text(
                          'Complete Registration',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AuthColors.label,
      ),
    );
  }
}
