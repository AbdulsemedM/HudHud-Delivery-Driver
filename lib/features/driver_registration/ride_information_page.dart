import 'package:flutter/material.dart';

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
  
  // Image picker
  bool _imageSelected = false;

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
                
                // Image of your Ride
                const Text(
                  'Image of your Ride',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
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
                
                // Image picker
                Center(
                  child: InkWell(
                    onTap: () {
                      // Image picker functionality would go here
                      setState(() {
                        _imageSelected = true;
                      });
                    },
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _imageSelected
                          ? const Icon(Icons.check_circle, color: Colors.green, size: 40)
                          : const Icon(Icons.camera_alt, size: 40),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Upload Front Photo text
                Center(
                  child: Text(
                    'Upload Front Photo of the Car',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                
                // Image formats
                Center(
                  child: Text(
                    '(JPG, PNG, JP2 (max. 600×600px)',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate() && _imageSelected) {
                        // Return true to indicate completion
                        Navigator.pop(context, true);
                      } else if (!_imageSelected) {
                        // Show validation message for image
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please upload an image of your ride'),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
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