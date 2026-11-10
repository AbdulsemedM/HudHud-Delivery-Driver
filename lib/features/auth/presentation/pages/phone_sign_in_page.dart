import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hudhud_delivery_driver/common/theme/app_text_styles.dart';
import 'package:hudhud_delivery_driver/core/services/phone_sign_in_service.dart';
import 'package:hudhud_delivery_driver/core/utils/ethiopian_phone_number.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/theme/auth_colors.dart';
import 'package:sms_autofill/sms_autofill.dart';

/// Passwordless sign-in: phone number -> SMS code.
///
/// Pops with a [PhoneSignInVerifyResult] once the session is established (the
/// service has already persisted token, user and application status). The
/// caller owns post-login routing, so password and phone sign-in share one
/// path. Pops with null if the rider backs out.
class PhoneSignInPage extends StatefulWidget {
  const PhoneSignInPage({super.key, this.initialPhone});

  final String? initialPhone;

  @override
  State<PhoneSignInPage> createState() => _PhoneSignInPageState();
}

class _PhoneSignInPageState extends State<PhoneSignInPage> {
  static const int _codeLength = 6;

  final PhoneSignInService _service = PhoneSignInService();
  final _phoneFormKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocus = FocusNode();

  /// Canonical number returned by requestCode. Non-null means we are on the
  /// code step; verify must be sent this exact value.
  String? _canonicalPhone;
  bool _isLoading = false;
  String? _error;
  int _resendIn = 0;
  Timer? _resendTimer;
  StreamSubscription<String>? _smsSub;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialPhone?.trim();
    if (initial != null &&
        initial.isNotEmpty &&
        !initial.contains('@') &&
        EthiopianPhoneNumber.isValid(initial)) {
      _phoneController.text = initial;
    }
    if (kDebugMode) _logAppSignature();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _stopSmsListener();
    _phoneController.dispose();
    _codeController.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- SMS autofill

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// The backend appends this 11-char hash to the SMS so Android's SMS
  /// Retriever can hand it to us. It depends on the signing key: debug and
  /// release builds differ, and SMS_APP_HASH_RIDER on the API must match the
  /// build in use or auto-read silently does nothing.
  Future<void> _logAppSignature() async {
    if (!_isAndroid) return;
    try {
      final sig = await SmsAutoFill().getAppSignature;
      debugPrint('[PhoneSignIn] Android SMS app hash: $sig');
    } catch (_) {}
  }

  Future<void> _startSmsListener() async {
    if (!_isAndroid) return;
    await _stopSmsListener();
    _smsSub = SmsAutoFill().code.listen((raw) {
      final match = RegExp(r'\d{' '$_codeLength' r'}').firstMatch(raw);
      if (match == null || !mounted || _canonicalPhone == null) return;
      _codeController.text = match.group(0)!;
      _verify();
    });
    try {
      await SmsAutoFill().listenForCode(
        smsCodeRegexPattern: r'\d{' '$_codeLength' r'}',
      );
    } catch (_) {
      // Auto-read is a convenience; typing the code always works.
    }
  }

  Future<void> _stopSmsListener() async {
    await _smsSub?.cancel();
    _smsSub = null;
    if (!_isAndroid) return;
    try {
      await SmsAutoFill().unregisterListener();
    } catch (_) {}
  }

  // ---------------------------------------------------------------- actions

  void _startResendCountdown(int seconds) {
    _resendTimer?.cancel();
    setState(() => _resendIn = seconds);
    if (seconds <= 0) return;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn = _resendIn > 0 ? _resendIn - 1 : 0);
      if (_resendIn == 0) t.cancel();
    });
  }

  Future<void> _requestCode() async {
    if (_isLoading) return;
    if (_canonicalPhone == null && !_phoneFormKey.currentState!.validate()) {
      return;
    }
    final phone = _canonicalPhone ?? _phoneController.text;

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _service.requestCode(phone);
      if (!mounted) return;
      setState(() => _canonicalPhone = result.phone);
      _codeController.clear();
      _startResendCountdown(result.resendAfterSeconds);
      await _startSmsListener();
      if (mounted) _codeFocus.requestFocus();
    } on PhoneSignInException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      if (e.retryAfterSeconds != null) {
        _startResendCountdown(e.retryAfterSeconds!);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verify() async {
    final phone = _canonicalPhone;
    final code = _codeController.text.trim();
    if (_isLoading || phone == null || code.length != _codeLength) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _service.verifyCode(
        phone: phone,
        code: code,
        deviceName: 'HudHud Driver (${defaultTargetPlatform.name})',
      );
      await _stopSmsListener();
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } on PhoneSignInException catch (e) {
      if (!mounted) return;
      _codeController.clear();
      if (e.isNotARider) {
        // Wrong account type: a new code will not help. Back to the number.
        await _stopSmsListener();
        _resendTimer?.cancel();
        setState(() {
          _canonicalPhone = null;
          _resendIn = 0;
          _error = e.message;
        });
        return;
      }
      setState(() => _error = e.isRetryableOnCodeScreen
          ? e.message
          : '${e.message}\nRequest a new code to try again.');
      if (e.retryAfterSeconds != null) {
        _startResendCountdown(e.retryAfterSeconds!);
      }
      _codeFocus.requestFocus();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _changeNumber() async {
    await _stopSmsListener();
    _resendTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _canonicalPhone = null;
      _resendIn = 0;
      _error = null;
      _codeController.clear();
    });
  }

  // -------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final onCodeStep = _canonicalPhone != null;
    return PopScope(
      canPop: !onCodeStep,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && onCodeStep) _changeNumber();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: AuthColors.title,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: onCodeStep ? _buildCodeStep() : _buildPhoneStep(),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          title,
          style: AppTextStyles.headline2.copyWith(
            color: AuthColors.title,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AuthColors.hint,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildPhoneStep() {
    return Form(
      key: _phoneFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(
            'Sign in with phone',
            'We will text you a $_codeLength-digit code. No password needed.',
          ),
          _label('Phone number'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _requestCode(),
            enabled: !_isLoading,
            style: AppTextStyles.bodyMedium.copyWith(color: AuthColors.title),
            decoration: _inputDecoration(
              hint: 'e.g. 0912 345 678',
              prefixIcon: const Icon(Icons.phone_outlined,
                  size: 20, color: AuthColors.hint),
            ),
            validator: EthiopianPhoneNumber.formValidator,
          ),
          _buildError(),
          const SizedBox(height: 28),
          _primaryButton(
            label: _resendIn > 0 ? 'Try again in ${_resendIn}s' : 'Send code',
            onPressed: _resendIn > 0 ? null : _requestCode,
          ),
        ],
      ),
    );
  }

  Widget _buildCodeStep() {
    final display = EthiopianPhoneNumber.formatForDisplay(_canonicalPhone!);
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(
            'Enter the code',
            'If $display can receive SMS, a $_codeLength-digit code is on its way.',
          ),
          TextField(
            controller: _codeController,
            focusNode: _codeFocus,
            enabled: !_isLoading,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(_codeLength),
            ],
            textAlign: TextAlign.center,
            style: AppTextStyles.headline2.copyWith(
              color: AuthColors.title,
              letterSpacing: 12,
              fontWeight: FontWeight.w600,
            ),
            decoration: _inputDecoration(hint: '•' * _codeLength),
            onChanged: (v) {
              if (_error != null) setState(() => _error = null);
              if (v.length == _codeLength) _verify();
            },
          ),
          _buildError(),
          const SizedBox(height: 28),
          _primaryButton(label: 'Verify', onPressed: _verify),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _isLoading ? null : _changeNumber,
                child: const Text('Change number'),
              ),
              TextButton(
                onPressed:
                    _isLoading || _resendIn > 0 ? null : _requestCode,
                child: Text(
                  _resendIn > 0 ? 'Resend in ${_resendIn}s' : 'Resend code',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    if (_error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        _error!,
        style: AppTextStyles.bodySmall.copyWith(color: Colors.red.shade700),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: AppTextStyles.bodySmall.copyWith(
          color: AuthColors.label,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      );

  Widget _primaryButton({required String label, VoidCallback? onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AuthColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                label,
                style: AppTextStyles.button.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, Widget? prefixIcon}) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AuthColors.hint, fontSize: 14),
      filled: true,
      fillColor: AuthColors.inputBg,
      prefixIcon: prefixIcon,
      border: border(AuthColors.border),
      enabledBorder: border(AuthColors.border),
      focusedBorder: border(AuthColors.primary, 1.5),
      errorBorder: border(Colors.red),
      focusedErrorBorder: border(Colors.red, 1.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
