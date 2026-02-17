import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/theme/auth_colors.dart';

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

const List<String> _serviceTypes = [
  'handyman',
  'specialist',
  'contractor',
];

class EditHandymanProfilePage extends StatefulWidget {
  const EditHandymanProfilePage({super.key});

  @override
  State<EditHandymanProfilePage> createState() =>
      _EditHandymanProfilePageState();
}

class _EditHandymanProfilePageState extends State<EditHandymanProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _hourlyRateController = TextEditingController();
  final _experienceController = TextEditingController();
  final _serviceRadiusController = TextEditingController();
  final _addressController = TextEditingController();
  final _bioController = TextEditingController();

  Set<String> _selectedSkills = {};
  String _selectedServiceType = _serviceTypes.first;
  bool _isLoading = false;
  bool _isSaving = false;
  int? _profileId;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _hourlyRateController.dispose();
    _experienceController.dispose();
    _serviceRadiusController.dispose();
    _addressController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final api = getIt<ApiService>();
      final data = await api.getHandymanProfile();
      if (!mounted || data == null) {
        setState(() => _isLoading = false);
        return;
      }
      final hp = data['handyman_profile'];
      if (hp is Map<String, dynamic>) {
        _profileId = hp['id'] is int
            ? hp['id'] as int
            : int.tryParse(hp['id']?.toString() ?? '');
      }
      _profileId ??= data['handyman_profile_id'] is int
          ? data['handyman_profile_id'] as int
          : int.tryParse(data['handyman_profile_id']?.toString() ?? '');
      _profileId ??= data['id'] is int
          ? data['id'] as int
          : int.tryParse(data['id']?.toString() ?? '');

      final rawSkills = data['skills'];
      if (rawSkills is List) {
        _selectedSkills =
            rawSkills.map((e) => e.toString().toLowerCase()).toSet();
      }
      final st = data['service_type']?.toString().toLowerCase() ?? '';
      _selectedServiceType =
          _serviceTypes.contains(st) ? st : _serviceTypes.first;
      _hourlyRateController.text =
          data['hourly_rate']?.toString() ?? '0';
      _experienceController.text =
          data['experience_years']?.toString() ?? '0';
      _serviceRadiusController.text =
          data['service_radius']?.toString() ?? '0';
      _addressController.text = data['address']?.toString() ?? '';
      _bioController.text = data['bio']?.toString() ?? '';
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  InputDecoration _decoration(String hint) {
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Future<void> _save() async {
    if (_profileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile ID not found. Cannot update.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
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

    setState(() => _isSaving = true);
    try {
      final api = getIt<ApiService>();
      await api.updateHandymanProfile(
        _profileId!,
        {
          'skills': _selectedSkills.toList(),
          'service_type': _selectedServiceType,
          'hourly_rate': double.tryParse(_hourlyRateController.text.trim()) ?? 0,
          'experience_years': int.tryParse(_experienceController.text.trim()) ?? 0,
          'service_radius': int.tryParse(_serviceRadiusController.text.trim()) ?? 0,
          'address': _addressController.text.trim(),
          'bio': _bioController.text.trim(),
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'Edit profile',
          style: TextStyle(
            color: AuthColors.title,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Skills',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AuthColors.label,
                ),
              ),
              const SizedBox(height: 8),
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
                        color: isSelected
                            ? AuthColors.primary
                            : AuthColors.border,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              const Text(
                'Service type',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AuthColors.label,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedServiceType,
                decoration: _decoration('Select service type'),
                items: _serviceTypes
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(
                            type[0].toUpperCase() + type.substring(1),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedServiceType = value);
                  }
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hourly rate (\$)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AuthColors.label,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _hourlyRateController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: _decoration('e.g. 35.00'),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            final rate = double.tryParse(v);
                            if (rate == null || rate <= 0) return 'Invalid rate';
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
                        const Text(
                          'Experience (yrs)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AuthColors.label,
                          ),
                        ),
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
              const Text(
                'Service radius (km)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AuthColors.label,
                ),
              ),
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
              const Text(
                'Address',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AuthColors.label,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _addressController,
                decoration: _decoration('Your address'),
              ),
              const SizedBox(height: 20),
              const Text(
                'Bio',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AuthColors.label,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _bioController,
                maxLines: 4,
                decoration: _decoration('Short bio'),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AuthColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save changes'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
