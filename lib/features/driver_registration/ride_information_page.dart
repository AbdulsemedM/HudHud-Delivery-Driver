import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';

class RideInformationPage extends StatefulWidget {
  const RideInformationPage({Key? key}) : super(key: key);

  @override
  State<RideInformationPage> createState() => _RideInformationPageState();
}

class _RideInformationPageState extends State<RideInformationPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final _licensePlateController = TextEditingController();
  
  // Dropdown values
  String? _selectedRideType;
  String? _selectedRideMake;
  String? _selectedRideModel;
  String? _selectedRideColor;

  File? _vehicleRegistrationDocument;
  File? _vehicleInsuranceDocument;
  bool _isUploading = false;

  Future<void> _pickDocument(ImageSource source, bool isRegistration) async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: source, maxWidth: 1920, imageQuality: 85);
    if (xFile != null && mounted) {
      setState(() {
        if (isRegistration) {
          _vehicleRegistrationDocument = File(xFile.path);
        } else {
          _vehicleInsuranceDocument = File(xFile.path);
        }
      });
    }
  }

  void _showPickOptions(bool isRegistration) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(context);
                _pickDocument(ImageSource.camera, isRegistration);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickDocument(ImageSource.gallery, isRegistration);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _licensePlateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Ride Information'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ride Type
                const Text(
                  'Ride Type',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedRideType,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  hint: const Text('Select State'),
                  items: <String>['Sedan', 'SUV', 'Hatchback', 'Van', 'Motorcycle']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedRideType = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a ride type';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Ride Make
                const Text(
                  'Ride Make',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedRideMake,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  hint: const Text('Select State'),
                  items: <String>['Toyota', 'Honda', 'Ford', 'Chevrolet', 'BMW', 'Mercedes']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedRideMake = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a ride make';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Ride Model
                const Text(
                  'Ride Model',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedRideModel,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  hint: const Text('Select State'),
                  items: <String>['Camry', 'Corolla', 'Civic', 'Accord', 'F-150', 'Silverado']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedRideModel = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a ride model';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // License Plate Number
                const Text(
                  'License Plate Number',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _licensePlateController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    hintText: 'JFK 0000-000',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your license plate number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'This is a hint text to help user.',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Ride Body Paint Color
                const Text(
                  'Ride Body Paint Color',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedRideColor,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  hint: const Text('Select State'),
                  items: <String>['Black', 'White', 'Red', 'Blue', 'Silver', 'Gray', 'Green']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedRideColor = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a ride color';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                
                // Vehicle registration document
                const Text(
                  'Vehicle Registration',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _isUploading ? null : () => _showPickOptions(true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _vehicleRegistrationDocument != null ? Icons.check_circle : Icons.upload_file,
                          color: _vehicleRegistrationDocument != null ? Colors.green : Colors.grey,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _vehicleRegistrationDocument != null
                                ? 'Registration document selected'
                                : 'Tap to upload vehicle registration',
                            style: TextStyle(color: Colors.grey[700], fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Vehicle insurance document
                const Text(
                  'Vehicle Insurance',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _isUploading ? null : () => _showPickOptions(false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _vehicleInsuranceDocument != null ? Icons.check_circle : Icons.upload_file,
                          color: _vehicleInsuranceDocument != null ? Colors.green : Colors.grey,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _vehicleInsuranceDocument != null
                                ? 'Insurance document selected'
                                : 'Tap to upload vehicle insurance',
                            style: TextStyle(color: Colors.grey[700], fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : () async {
                      if (!_formKey.currentState!.validate()) return;
                      if (_vehicleRegistrationDocument == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please upload vehicle registration document'),
                          ),
                        );
                        return;
                      }
                      setState(() => _isUploading = true);
                      try {
                        final api = getIt<ApiService>();
                        await api.uploadDriverDocument(
                          file: _vehicleRegistrationDocument!,
                          documentType: 'vehicle_registration_image',
                          description: 'Vehicle registration document',
                        );
                        if (_vehicleInsuranceDocument != null) {
                          await api.uploadDriverDocument(
                            file: _vehicleInsuranceDocument!,
                            documentType: 'vehicle_insurance_image',
                            description: 'Vehicle insurance document',
                          );
                        }
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Documents uploaded successfully'),
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
                        if (mounted) setState(() => _isUploading = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isUploading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Submit Information',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
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
}