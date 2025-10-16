import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../../../core/utils/logger.dart';

class VerifyEmailPage extends StatefulWidget {
  final String? email;
  const VerifyEmailPage({Key? key, this.email}) : super(key: key);

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  final List<TextEditingController> _controllers =
      List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  final SecureStorageService _storageService = SecureStorageService();
  late final ApiService _apiService;

  bool _isLoading = false;
  bool _isResending = false;
  int _resendCountdown = 0;
  Timer? _timer;
  String? _errorMessage;
  // ignore: unused_field
  String? _successMessage;
  String _userEmail = '';

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(
      secureStorage: _storageService,
      logger: AppLogger(),
    );
    _loadUserEmail();
  }

  Future<void> _loadUserEmail() async {
    final email = await _storageService.getUserEmail();
    setState(() {
      _userEmail = widget.email ?? email ?? '';
    });
    if (_userEmail.isNotEmpty) {
      _sendVerificationCode();
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _startResendCountdown() {
    setState(() {
      _resendCountdown = 60;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _sendVerificationCode() async {
    setState(() {
      _isResending = true;
      _errorMessage = '';
    });

    try {
      final response = await _apiService.sendEmailVerificationCode(_userEmail);

      if (response['success'] == true) {
        _startResendCountdown();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification code sent to your email'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _errorMessage =
              response['message'] ?? 'Failed to send verification code';
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

  Future<void> _verifyCode() async {
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
      final response = await _apiService.verifyEmailCode(_userEmail, code);

      if (response['success'] == true) {
        // Update user verification status
        await _storageService.saveUserEmailVerified(true);

        setState(() {
          _successMessage = 'Email verified successfully!';
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
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onCodeChanged(String value, int index) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    // Auto-verify when all fields are filled
    if (_controllers.every((controller) => controller.text.isNotEmpty)) {
      _verifyCode();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Verify Email',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              // Email icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.email_outlined,
                  size: 40,
                  color: Colors.deepPurple,
                ),
              ),

              const SizedBox(height: 32),

              // Title
              const Text(
                'Check your email',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),

              const SizedBox(height: 16),

              // Description
              Text(
                'We sent a verification code to\n$_userEmail',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 40),

              // OTP Input Fields
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 45,
                    height: 55,
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Colors.deepPurple, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: (value) => _onCodeChanged(value, index),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 24),

              // Error message
              if (_errorMessage?.isNotEmpty == true)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 32),

              // Verify Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Verify Email',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 24),

              // Resend Code
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Didn't receive the code? ",
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  GestureDetector(
                    onTap: _resendCountdown > 0 || _isResending
                        ? null
                        : _sendVerificationCode,
                    child: Text(
                      _resendCountdown > 0
                          ? 'Resend in ${_resendCountdown}s'
                          : _isResending
                              ? 'Sending...'
                              : 'Resend',
                      style: TextStyle(
                        color: _resendCountdown > 0 || _isResending
                            ? Colors.grey[400]
                            : Colors.deepPurple,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Help text
              Text(
                'Check your spam folder if you don\'t see the email',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
