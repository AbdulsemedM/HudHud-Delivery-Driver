import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/utils/ethiopian_phone_number.dart';

class VerifyPhoneNumberPage extends StatefulWidget {
  final String? phone;

  const VerifyPhoneNumberPage({
    super.key,
    this.phone,
  });

  @override
  State<VerifyPhoneNumberPage> createState() => _VerifyPhoneNumberPageState();
}

class _VerifyPhoneNumberPageState extends State<VerifyPhoneNumberPage> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  Timer? _timer;
  int _remainingSeconds = 60;
  bool _isResendEnabled = false;
  bool _isLoading = false;
  bool _isResending = false;
  String _userPhone = '';
  String? _errorMessage;
  String? _successMessage;

  ApiService get _apiService => getIt<ApiService>();

  @override
  void initState() {
    super.initState();
    _loadUserPhone();
    _startTimer();
  }

  Future<void> _loadUserPhone() async {
    try {
      final registeredPhone = await _apiService.getRegisteredPhone();
      if (!mounted) return;

      if (registeredPhone == null || registeredPhone.isEmpty) {
        setState(() {
          _errorMessage =
              'No phone number found on your account. Please contact support.';
        });
        return;
      }

      setState(() {
        _userPhone = registeredPhone;
        _errorMessage = null;
      });

      await _sendVerificationCode();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load phone number';
        });
      }
    }
  }

  Future<void> _handleUnauthenticated(String message) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
    context.goNamed(AppRouter.login);
  }

  Future<void> _sendVerificationCode() async {
    if (_userPhone.isEmpty) return;

    try {
      final response =
          await _apiService.sendPhoneVerificationCode(_userPhone);

      if (!mounted) return;

      if (response['unauthenticated'] == true) {
        await _handleUnauthenticated(
          response['message']?.toString() ?? 'Session expired. Please log in again.',
        );
        return;
      }

      if (response['success'] == true) {
        setState(() {
          _successMessage =
              response['message']?.toString() ??
              'Verification code sent successfully!';
          _errorMessage = null;
        });
      } else {
        setState(() {
          _errorMessage =
              response['message']?.toString() ??
              'Failed to send verification code';
          _successMessage = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
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
      if (!mounted) return;
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

  Future<void> _resendCode() async {
    if (!_isResendEnabled || _isResending) return;

    setState(() {
      _remainingSeconds = 60;
      _isResendEnabled = false;
      _isResending = true;
      _errorMessage = null;
      _successMessage = null;
    });

    _startTimer();

    try {
      final response =
          await _apiService.sendPhoneVerificationCode(_userPhone);

      if (!mounted) return;

      if (response['unauthenticated'] == true) {
        await _handleUnauthenticated(
          response['message']?.toString() ?? 'Session expired. Please log in again.',
        );
        return;
      }

      if (response['success'] == true) {
        setState(() {
          _successMessage = 'Verification code resent successfully!';
        });
      } else {
        setState(() {
          _errorMessage =
              response['message']?.toString() ??
              'Failed to resend verification code';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Network error. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  Future<void> _verifyPhone() async {
    final code = _controllers.map((controller) => controller.text).join();

    if (code.length != 6) {
      setState(() {
        _errorMessage = 'Please enter the complete 6-digit code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.verifyPhoneCode(_userPhone, code);

      if (!mounted) return;

      if (response['unauthenticated'] == true) {
        await _handleUnauthenticated(
          response['message']?.toString() ?? 'Session expired. Please log in again.',
        );
        return;
      }

      if (response['success'] == true) {
        setState(() {
          _successMessage =
              response['message']?.toString() ??
              'Phone verified successfully!';
          _errorMessage = null;
          _isLoading = false;
        });

        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _errorMessage =
              response['message']?.toString() ?? 'Invalid verification code';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Network error. Please try again.';
        _isLoading = false;
      });
    }
  }

  String get _displayPhone {
    if (_userPhone.isEmpty) return 'your phone number';
    return EthiopianPhoneNumber.mask(_userPhone);
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
              'Verify your phone number',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "We've sent a verification code to $_displayPhone",
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),

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
              'Verification code',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
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
                      counterText: '',
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
                        FocusScope.of(context)
                            .requestFocus(_focusNodes[index + 1]);
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Resend code ${_isResendEnabled ? '' : '00:${_remainingSeconds.toString().padLeft(2, '0')}'}',
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
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
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
