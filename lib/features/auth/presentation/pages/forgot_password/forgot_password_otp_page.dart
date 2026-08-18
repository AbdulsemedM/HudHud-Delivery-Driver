import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hudhud_delivery_driver/common/theme/app_text_styles.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/utils/ethiopian_phone_number.dart';
import 'package:hudhud_delivery_driver/core/utils/forgot_password.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/theme/auth_colors.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/widgets/auth_header.dart';

class ForgotPasswordOtpPage extends StatefulWidget {
  const ForgotPasswordOtpPage({
    super.key,
    required this.resetId,
    required this.identifier,
    this.expiresInMinutes = ForgotPassword.defaultOtpMinutes,
  });

  final String resetId;
  final String identifier;
  final int expiresInMinutes;

  @override
  State<ForgotPasswordOtpPage> createState() => _ForgotPasswordOtpPageState();
}

class _ForgotPasswordOtpPageState extends State<ForgotPasswordOtpPage> {
  static const int _otpLength = 6;

  final List<TextEditingController> _controllers =
      List.generate(_otpLength, (_) => TextEditingController());
  Timer? _timer;
  late int _remainingSeconds;
  bool _isLoading = false;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.expiresInMinutes * 60;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _expired => _remainingSeconds <= 0;

  String get _otpCode => _controllers.map((c) => c.text).join();

  String get _maskedIdentifier {
    if (widget.identifier.contains('@')) return widget.identifier;
    return EthiopianPhoneNumber.mask(widget.identifier);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _timer?.cancel();
        }
      });
    });
  }

  void _restartTimer(int minutes) {
    setState(() {
      _remainingSeconds = minutes * 60;
    });
    _startTimer();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.orange),
    );
  }

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
    if (key.length != 1 || !RegExp(r'[0-9]').hasMatch(key)) return;
    for (int i = 0; i < _otpLength; i++) {
      if (_controllers[i].text.isEmpty) {
        _controllers[i].text = key;
        setState(() {});
        if (i == _otpLength - 1) _verifyOtp();
        return;
      }
    }
  }

  Future<void> _verifyOtp() async {
    if (_isLoading || _isResending) return;
    if (_expired) {
      _showError(ForgotPassword.codeExpiredMessage);
      return;
    }
    final otp = _otpCode;
    if (otp.length != _otpLength) return;

    setState(() => _isLoading = true);
    try {
      final result = await ApiService.verifyPasswordResetOtp(
        resetId: widget.resetId,
        otp: otp,
      );
      if (!mounted) return;
      if (result['success'] != true) {
        _showError(result['message']?.toString() ?? 'Verification failed');
        return;
      }
      final resetToken =
          ForgotPassword.requiredString(result['data'], 'reset_token');
      if (resetToken == null) {
        _showError(ForgotPassword.invalidServerResponse);
        return;
      }
      context.pushNamed(
        AppRouter.forgotPasswordReset,
        extra: {'resetToken': resetToken},
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resend() async {
    if (_isLoading || _isResending) return;
    setState(() => _isResending = true);
    try {
      final result = await ApiService.resendPasswordResetOtp(
        resetId: widget.resetId,
      );
      if (!mounted) return;
      if (result['success'] != true) {
        _showError(result['message']?.toString() ?? 'Failed to resend code');
        return;
      }
      final minutes =
          ForgotPassword.expiresInMinutesForResend(result['data']);
      if (minutes != null && minutes > 0) {
        _restartTimer(minutes);
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _remainingSeconds ~/ 60;
    final secs = _remainingSeconds % 60;
    final timeStr =
        '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: Colors.white,
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
                      _maskedIdentifier,
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
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: SizedBox(
                            width: 44,
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
                                  borderSide: const BorderSide(
                                    color: AuthColors.border,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AuthColors.border,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AuthColors.primary,
                                    width: 2,
                                  ),
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
                    if (_expired)
                      Text(
                        ForgotPassword.codeExpiredMessage,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.orange.shade800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: (!_expired || _isLoading || _isResending)
                          ? null
                          : _resend,
                      child: RichText(
                        text: TextSpan(
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AuthColors.label,
                          ),
                          children: [
                            const TextSpan(text: 'Resend Code in '),
                            TextSpan(
                              text: _expired || _remainingSeconds == 0
                                  ? (_isResending ? 'Sending…' : 'Resend')
                                  : timeStr,
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

  Widget _buildKeypad() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Row(
        children: [
          Expanded(child: _keypadGrid()),
          const SizedBox(width: 12),
          Column(
            children: [
              _keypadActionKey(
                Icons.backspace_outlined,
                onTap: () => _onKeypad('backspace'),
              ),
              const SizedBox(height: 8),
              _keypadEnterKey(),
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
      ['', '0', ''],
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
                  child: k.isEmpty ? const SizedBox(height: 48) : _digitKey(k),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _digitKey(String digit) {
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

  Widget _keypadActionKey(IconData icon, {VoidCallback? onTap}) {
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
          child: Icon(icon, size: 22, color: AuthColors.label),
        ),
      ),
    );
  }

  Widget _keypadEnterKey() {
    final disabled = _isLoading || _expired;
    return Material(
      color: disabled ? AuthColors.primary.withValues(alpha: 0.5) : AuthColors.primary,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: disabled ? null : () => _onKeypad('enter'),
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
              : const Icon(Icons.arrow_forward, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}
