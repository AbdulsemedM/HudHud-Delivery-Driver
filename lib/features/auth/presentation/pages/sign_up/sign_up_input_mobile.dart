import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/widgets/custom_text_field.dart';

class SignUpInputMobile extends StatefulWidget {
  const SignUpInputMobile({Key? key}) : super(key: key);

  @override
  State<SignUpInputMobile> createState() => _SignUpInputMobileState();
}

class _SignUpInputMobileState extends State<SignUpInputMobile> {
  final TextEditingController _mobileController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _phoneError;
  Country _selectedCountry = Country(
    phoneCode: '251',
    countryCode: 'ET',
    e164Sc: 0,
    geographic: true,
    level: 0,
    name: 'Ethiopia',
    example: '911234567',
    displayName: 'Ethiopia (ET) [+251]',
    displayNameNoCountryCode: 'Ethiopia (ET)',
    e164Key: '251-ET-0',
  );

  @override
  void dispose() {
    _mobileController.dispose();
    super.dispose();
  }

  bool _validatePhone() {
    final phoneNumber = _mobileController.text.trim();
    if (phoneNumber.isEmpty) {
      setState(() {
        _phoneError = 'Phone number is required';
      });
      return false;
    }

    try {
      // Parse phone number with country code
      final phoneInfo = PhoneNumber.parse(
        '+${_selectedCountry.phoneCode}$phoneNumber'
      );

      if (!phoneInfo.isValid()) {
        setState(() {
          _phoneError = 'Please enter a valid phone number';
        });
        return false;
      }

      setState(() {
        _phoneError = null;
      });
      return true;
    } catch (e) {
      setState(() {
        _phoneError = 'Invalid phone number format';
      });
      return false;
    }
  }

  void _showCountryPicker() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      onSelect: (Country country) {
        setState(() {
          _selectedCountry = country;
        });
      },
    );
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
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "What's your number?",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "We'll text you a code to verify your phone",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              // Country selection button
              InkWell(
                onTap: _showCountryPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_selectedCountry.flagEmoji} ${_selectedCountry.name} (+${_selectedCountry.phoneCode})',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Phone number field
              CustomTextField(
                hintText: "Enter your mobile number",
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                errorText: _phoneError,
                onChanged: (_) {
                  if (_phoneError != null) {
                    setState(() {
                      _phoneError = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 8),
              const Text(
                "Enter your number without country code",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      // Navigate to login page or handle existing account
                    },
                    child: const Text(
                      "Have an account and a new number?",
                      style: TextStyle(
                        color: Colors.purple,
                      ),
                    ),
                  ),
                  FloatingActionButton(
                    onPressed: () {
                      if (_validatePhone()) {
                        context.goNamed(AppRouter.signUpOtp);
                      }
                    },
                    child: const Icon(Icons.arrow_forward),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}