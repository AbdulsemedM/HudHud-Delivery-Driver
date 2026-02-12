import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hudhud_delivery_driver/common/theme/app_text_styles.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/theme/auth_colors.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/widgets/auth_header.dart';

class SignUpOtpVerification extends StatefulWidget {
  final String? email;
  final String? phone;

  const SignUpOtpVerification({
    super.key,
    this.email,
    this.phone,
  });

  @override
  State<SignUpOtpVerification> createState() => _SignUpOtpVerificationState();
}

class _SignUpOtpVerificationState extends State<SignUpOtpVerification> {
  static const int _otpLength = 5;
  static const int _resendSeconds = 180;

  final List<TextEditingController> _controllers =
      List.generate(_otpLength, (_) => TextEditingController());
  Timer? _timer;
  int _remainingSeconds = _resendSeconds;
  bool _isResendEnabled = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
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

  void _resendCode() {
    if (_isResendEnabled) {
      setState(() {
        _remainingSeconds = _resendSeconds;
        _isResendEnabled = false;
      });
      _startTimer();
    }
  }

  String get _maskedPhone {
    final p = widget.phone ?? '';
    if (p.length <= 4) return p;
    final last = p.substring(p.length - 2);
    return '+25 712 ****** $last';
  }

  String get _otpCode =>
      _controllers.map((c) => c.text).join();

  void _onKeypad(String key) {
    if (key == 'backspace') {
      for (int i = _otpLength - 1; i >= 0; i--) {
        if (_controllers[i].text.isNotEmpty) {
          _controllers[i].clear();
          setState(() {});
          return;
        }
      }
      return;
    }
    if (key == 'enter') {
      _verifyOtp();
      return;
    }
    final digit = key;
    if (digit.length != 1 || !RegExp(r'[0-9]').hasMatch(digit)) return;
    for (int i = 0; i < _otpLength; i++) {
      if (_controllers[i].text.isEmpty) {
        _controllers[i].text = digit;
        setState(() {});
        if (i == _otpLength - 1) _verifyOtp();
        return;
      }
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpCode;
    if (otp.length != _otpLength) return;

    setState(() => _isLoading = true);
    try {
      if (widget.email != null && widget.email!.isNotEmpty) {
        final result = await ApiService.verifyEmail(
          email: widget.email!,
          code: otp,
        );
        if (!mounted) return;
        if (!result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Verification failed'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
          return;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification successful!')),
        );
        context.goNamed(AppRouter.login);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _remainingSeconds ~/ 60;
    final secs = _remainingSeconds % 60;
    final timeStr =
        '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AuthHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _buildPhoneIllustration(),
                    const SizedBox(height: 24),
                    Text(
                      'Verification',
                      style: AppTextStyles.headline2.copyWith(
                        color: AuthColors.title,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'We have sent you a verification code to',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AuthColors.label,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _maskedPhone,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AuthColors.label,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _otpLength,
                        (i) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: SizedBox(
                            width: 52,
                            height: 52,
                            child: TextField(
                              controller: _controllers[i],
                              readOnly: true,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.headline4.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                counterText: '',
                                filled: true,
                                fillColor: Colors.white,
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
                                  borderSide: const BorderSide(color: AuthColors.primary, width: 2),
                                ),
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(1),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _isResendEnabled ? _resendCode : null,
                      child: RichText(
                        text: TextSpan(
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AuthColors.label,
                          ),
                          children: [
                            const TextSpan(text: 'Resend Code in '),
                            TextSpan(
                              text: _isResendEnabled ? 'Resend' : timeStr,
                              style: const TextStyle(
                                color: AuthColors.link,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildKeypad(),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneIllustration() {
    return Container(
      width: 160,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.phone_android, size: 48, color: AuthColors.primary.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          Text(
            'OTP',
            style: AppTextStyles.caption.copyWith(color: AuthColors.label),
          ),
          Text(
            'Sent to your phone',
            style: AppTextStyles.caption.copyWith(
              color: AuthColors.hint,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeypad() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      color: Colors.transparent,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _keypadGrid(),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  _keypadActionKey('-', onTap: () {}),
                  const SizedBox(height: 8),
                  _keypadActionKey('}', onTap: () {}),
                  const SizedBox(height: 8),
                  _keypadActionKey(Icons.backspace_outlined, onTap: () => _onKeypad('backspace')),
                  const SizedBox(height: 8),
                  _keypadEnterKey(),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _keypadGrid() {
    const keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      [',', '0', '.'],
    ];
    return Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: row.map((k) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _keypadDigitKey(k),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _keypadDigitKey(String digit) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => _onKeypad(digit),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AuthColors.border),
          ),
          child: Text(
            digit,
            style: AppTextStyles.headline4.copyWith(
              color: AuthColors.title,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _keypadActionKey(dynamic iconOrChar, {VoidCallback? onTap}) {
    return Material(
      color: Colors.grey.shade200,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 52,
          height: 48,
          alignment: Alignment.center,
          child: iconOrChar is IconData
              ? Icon(iconOrChar, size: 22, color: AuthColors.label)
              : Text(
                  iconOrChar.toString(),
                  style: AppTextStyles.bodyLarge.copyWith(color: AuthColors.label),
                ),
        ),
      ),
    );
  }

  Widget _keypadEnterKey() {
    return Material(
      color: AuthColors.primary,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: _isLoading ? null : () => _onKeypad('enter'),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 52,
          height: 48,
          alignment: Alignment.center,
          child: _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.arrow_back, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}
