import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/features/driver_registration/license_information_page.dart';
import 'package:hudhud_delivery_driver/features/driver_registration/ride_information_page.dart';
import 'package:hudhud_delivery_driver/features/driver_registration/bank_information_page.dart';

class DriverRegistrationPage extends StatefulWidget {
  const DriverRegistrationPage({Key? key}) : super(key: key);

  @override
  State<DriverRegistrationPage> createState() => _DriverRegistrationPageState();
}

class _DriverRegistrationPageState extends State<DriverRegistrationPage> {
  // Track completion status of each step
  bool licenseInfoCompleted = false;
  bool rideInfoCompleted = false;
  bool bankInfoCompleted = false;

  @override
  Widget build(BuildContext context) {
    // Calculate progress percentage
    int completedSteps = 0;
    if (licenseInfoCompleted) completedSteps++;
    if (rideInfoCompleted) completedSteps++;
    if (bankInfoCompleted) completedSteps++;
    
    double progressPercentage = completedSteps / 3;
    
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Driver Registration',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // Progress bar
              LinearProgressIndicator(
                value: progressPercentage,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.purple),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              
              // Progress percentage
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${(progressPercentage * 100).toInt()}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              const Text(
                'Please complete the following steps.',
                style: TextStyle(
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              
              // License Information
              RegistrationStepItem(
                title: 'Your License Information',
                hintText: 'This is a hint text to help user.',
                isCompleted: licenseInfoCompleted,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LicenseInformationPage(),
                    ),
                  ).then((completed) {
                    if (completed == true) {
                      setState(() {
                        licenseInfoCompleted = true;
                      });
                    }
                  });
                },
              ),
              
              const SizedBox(height: 16),
              
              // Ride Information
              RegistrationStepItem(
                title: 'Your Ride Information',
                hintText: 'This is a hint text to help user.',
                isCompleted: rideInfoCompleted,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RideInformationPage(),
                    ),
                  ).then((completed) {
                    if (completed == true) {
                      setState(() {
                        rideInfoCompleted = true;
                      });
                    }
                  });
                },
              ),
              
              const SizedBox(height: 16),
              
              // Bank Information
              RegistrationStepItem(
                title: 'Your Bank Information',
                hintText: 'This is a hint text to help user.',
                isCompleted: bankInfoCompleted,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BankInformationPage(),
                    ),
                  ).then((completed) {
                    if (completed == true) {
                      setState(() {
                        bankInfoCompleted = true;
                      });
                    }
                  });
                },
              ),
              
              const Spacer(),
              
              // Submit button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: licenseInfoCompleted && rideInfoCompleted && bankInfoCompleted
                      ? () {
                          // Submit registration
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Registration submitted successfully!'),
                            ),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    disabledBackgroundColor: Colors.grey[200],
                    foregroundColor: Colors.black,
                    disabledForegroundColor: Colors.grey,
                  ),
                  child: const Text('Submit for Registration'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RegistrationStepItem extends StatelessWidget {
  final String title;
  final String hintText;
  final bool isCompleted;
  final VoidCallback onTap;

  const RegistrationStepItem({
    Key? key,
    required this.title,
    required this.hintText,
    required this.isCompleted,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            // Completion indicator
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? Colors.purple : Colors.white,
                border: Border.all(
                  color: isCompleted ? Colors.purple : Colors.grey,
                  width: 2,
                ),
              ),
              child: isCompleted
                  ? const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            
            // Step information
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    hintText,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            // Arrow icon
            const Icon(
              Icons.chevron_right,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}