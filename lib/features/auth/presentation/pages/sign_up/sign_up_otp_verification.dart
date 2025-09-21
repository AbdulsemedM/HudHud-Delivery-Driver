import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';

class SignUpOtpVerification extends StatefulWidget {
  const SignUpOtpVerification({Key? key}) : super(key: key);

  @override
  State<SignUpOtpVerification> createState() => _SignUpOtpVerificationState();
}

class _SignUpOtpVerificationState extends State<SignUpOtpVerification> {
  final List<TextEditingController> _controllers = List.generate(5, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(5, (_) => FocusNode());
  Timer? _timer;
  int _remainingSeconds = 60;
  bool _isResendEnabled = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
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

  void _resendCode() {
    if (_isResendEnabled) {
      setState(() {
        _remainingSeconds = 60;
        _isResendEnabled = false;
      });
      _startTimer();
      // Here you would implement the actual code resending logic
    }
  }

  void _verifyOtp() {
    // Collect the OTP from all fields
    final otp = _controllers.map((controller) => controller.text).join();
    
    // Check if OTP is complete
    if (otp.length == 5) {
      // Here you would implement the actual verification logic
      // Navigate to login page after successful verification
      context.goNamed(AppRouter.login);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the complete verification code')),
      );
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
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "We have sent you the code.",
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
            const Text(
              "Secure code",
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
                5,
                (index) => SizedBox(
                  width: 50,
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
                      if (value.isNotEmpty && index < 4) {
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
                  "Resend the code ${_isResendEnabled ? '' : '00:${_remainingSeconds.toString().padLeft(2, '0')}'}",
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                TextButton(
                  onPressed: _isResendEnabled ? _resendCode : null,
                  child: Text(
                    "Unable to get the code?",
                    style: TextStyle(
                      color: _isResendEnabled ? Colors.purple : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Continue button
            Align(
              alignment: Alignment.bottomRight,
              child: FloatingActionButton(
                onPressed: _verifyOtp,
                child: const Icon(Icons.arrow_forward),
              ),
            ),
          ],
        ),
      ),
    );
  }
}