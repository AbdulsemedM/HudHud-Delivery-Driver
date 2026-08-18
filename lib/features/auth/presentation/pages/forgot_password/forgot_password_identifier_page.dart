import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hudhud_delivery_driver/common/theme/app_text_styles.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/utils/ethiopian_phone_number.dart';
import 'package:hudhud_delivery_driver/core/utils/forgot_password.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/theme/auth_colors.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/widgets/auth_header.dart';

class ForgotPasswordIdentifierPage extends StatefulWidget {
  const ForgotPasswordIdentifierPage({super.key});

  @override
  State<ForgotPasswordIdentifierPage> createState() =>
      _ForgotPasswordIdentifierPageState();
}

class _ForgotPasswordIdentifierPageState
    extends State<ForgotPasswordIdentifierPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  late final TabController _tabs;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool get _isEmailTab => _tabs.index == 0;

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.orange),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _loading) return;

    final method = _isEmailTab
        ? ForgotPassword.emailMethod
        : ForgotPassword.phoneMethod;
    String identifier;
    if (_isEmailTab) {
      identifier = _emailController.text.trim();
    } else {
      identifier =
          EthiopianPhoneNumber.tryNormalize(_phoneController.text) ?? '';
      if (identifier.isEmpty) {
        _showError('Enter a valid Ethiopian phone number');
        return;
      }
    }

    setState(() => _loading = true);
    try {
      final result = await ApiService.requestPasswordResetOtp(
        identifier: identifier,
        method: method,
      );
      if (!mounted) return;
      if (result['success'] != true) {
        _showError(result['message']?.toString() ?? 'Request failed');
        return;
      }
      final resetId = ForgotPassword.requiredString(result['data'], 'reset_id');
      if (resetId == null) {
        _showError(ForgotPassword.invalidServerResponse);
        return;
      }
      final minutes = ForgotPassword.expiresInMinutesForRequest(result['data']);
      context.pushNamed(
        AppRouter.forgotPasswordOtp,
        extra: {
          'resetId': resetId,
          'identifier': identifier,
          'expiresInMinutes': minutes,
        },
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const AuthHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 12),
                      Text(
                        'Forgot password',
                        style: AppTextStyles.headline2.copyWith(
                          color: AuthColors.title,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter the email or phone on your account. We will send a 6-digit code.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AuthColors.hint,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Container(
                        decoration: BoxDecoration(
                          color: AuthColors.inputBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TabBar(
                          controller: _tabs,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: BoxDecoration(
                            color: AuthColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          labelColor: Colors.white,
                          unselectedLabelColor: AuthColors.label,
                          tabs: const [
                            Tab(text: 'Email'),
                            Tab(text: 'Phone'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_isEmailTab) ...[
                        _label('Email'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AuthColors.title),
                          decoration: _decoration(
                            hint: 'e.g. johndoe@email.com',
                            prefixIcon: const Icon(
                              Icons.email_outlined,
                              size: 20,
                              color: AuthColors.hint,
                            ),
                          ),
                          validator: ForgotPassword.validateEmail,
                        ),
                      ] else ...[
                        _label('Phone'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AuthColors.title),
                          decoration: _decoration(
                            hint: 'e.g. 0911234567',
                            prefixIcon: const Icon(
                              Icons.phone_outlined,
                              size: 20,
                              color: AuthColors.hint,
                            ),
                          ),
                          validator: EthiopianPhoneNumber.formValidator,
                        ),
                      ],
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AuthColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Send code',
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: AppTextStyles.bodySmall.copyWith(
          color: AuthColors.label,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  InputDecoration _decoration({required String hint, Widget? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AuthColors.hint, fontSize: 14),
      filled: true,
      fillColor: AuthColors.inputBg,
      prefixIcon: prefixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AuthColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AuthColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AuthColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
