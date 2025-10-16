import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/services/secure_storage_service.dart';

import '../../../../core/utils/logger.dart';

class VerifyPhoneNumberPage extends StatefulWidget {
  final String? phone;
  
  const VerifyPhoneNumberPage({
    Key? key,
    this.phone,
  }) : super(key: key);

  @override
  State<VerifyPhoneNumberPage> createState() => _VerifyPhoneNumberPageState();
}

class _VerifyPhoneNumberPageState extends State<VerifyPhoneNumberPage> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  late final ApiService _apiService;
  final SecureStorageService _storageService = SecureStorageService();
  
  Timer? _timer;
  int _remainingSeconds = 60;
  bool _isResendEnabled = false;
  bool _isLoading = false;
  bool _isResending = false;
  String _userPhone = '';
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(
      secureStorage: _storageService,
      logger: AppLogger(),
    );
    _userPhone = widget.phone ?? '';
    _loadUserPhone();
    _startTimer();
  }

  Future<void> _loadUserPhone() async {
    try {
      if (_userPhone.isEmpty) {
        final storedPhone = await _storageService.getUserPhone();
        setState(() {
          _userPhone = storedPhone ?? '';
        });
      }
      
      // Send verification code if phone is available
      if (_userPhone.isNotEmpty) {
        _sendVerificationCode();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load phone number';
      });
    }
  }

  Future<void> _sendVerificationCode() async {
    if (_userPhone.isEmpty) return;

    try {
      final response = await _apiService.sendPhoneVerificationCode(_userPhone);
      
      if (response['success'] == true) {
        setState(() {
          _successMessage = 'Verification code sent successfully!';
          _errorMessage = null;
        });
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to send verification code';
          _successMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error. Please try again.';
        _successMessage = null;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _isResendEnabled = true;
          _timer?.cancel();
        }
      });
    });
  }

  void _resendCode() async {
    if (_isResendEnabled && !_isResending) {
      setState(() {
        _remainingSeconds = 60;
        _isResendEnabled = false;
        _isResending = true;
        _errorMessage = null;
        _successMessage = null;
      });
      
      _startTimer();
      
      try {
        final response = await _apiService.sendPhoneVerificationCode(_userPhone);
        
        if (response['success'] == true) {
          setState(() {
            _successMessage = 'Verification code resent successfully!';
          });
        } else {
          setState(() {
            _errorMessage = response['message'] ?? 'Failed to resend verification code';
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Network error. Please try again.';
        });
      } finally {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  void _verifyPhone() async {
    final code = _controllers.map((controller) => controller.text).join();

    if (code.length != 6) {
      setState(() {
        _errorMessage = 'Please enter the complete 6-digit code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await _apiService.verifyPhoneCode(_userPhone, code);

      if (response['success'] == true) {
        // Update user verification status
        await _storageService.saveUserPhoneVerified(true);

        setState(() {
          _successMessage = 'Phone verified successfully!';
          _errorMessage = null;
          _isLoading = false;
        });

        // Navigate back or to home page after successful verification
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Invalid verification code';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error. Please try again.';
        _isLoading = false;
      });
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
        title: const Text('Verify Phone Number'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Verify your phone number",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "We've sent a verification code to ${_userPhone.isNotEmpty ? _userPhone : 'your phone number'}",
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            
            // Error message
            if (_errorMessage != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Success message
            if (_successMessage != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Text(
                  _successMessage!,
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              "Verification code",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            // OTP input fields
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                6,
                (index) => SizedBox(
                  width: 45,
                  height: 50,
                  child: TextField(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    decoration: InputDecoration(
                      counterText: "",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (value) {
                      if (value.isNotEmpty && index < 5) {
                        FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Timer and resend button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Resend code ${_isResendEnabled ? '' : '00:${_remainingSeconds.toString().padLeft(2, '0')}'}",
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                TextButton(
                  onPressed: _isResendEnabled ? _resendCode : null,
                  child: Text(
                    "Didn't receive code?",
                    style: TextStyle(
                      color: _isResendEnabled ? Colors.purple : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Verify button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyPhone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Verify Phone Number',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}