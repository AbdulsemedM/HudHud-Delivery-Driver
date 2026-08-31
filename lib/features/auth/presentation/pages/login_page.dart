import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hudhud_delivery_driver/common/theme/app_text_styles.dart';
import 'package:hudhud_delivery_driver/core/auth/application_status_gate.dart';
import 'package:hudhud_delivery_driver/core/auth/phone_verification_gate.dart';
import 'package:hudhud_delivery_driver/core/constants/user_type_constants.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/services/biometric_credential_service.dart';
import 'package:hudhud_delivery_driver/core/services/notification_service.dart';
import 'package:hudhud_delivery_driver/core/services/secure_storage_service.dart';
import 'package:hudhud_delivery_driver/core/utils/ethiopian_phone_number.dart';
import 'package:hudhud_delivery_driver/core/utils/password_rules.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/pages/verification_required_page.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/theme/auth_colors.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _showBiometric = false;
  bool _prefersFaceIcon = false;

  BiometricCredentialService get _bio => getIt<BiometricCredentialService>();

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_refreshBiometricVisibility);
    _loadRememberedCredentials();
  }

  @override
  void dispose() {
    _emailController.removeListener(_refreshBiometricVisibility);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadRememberedCredentials() async {
    if (!await _bio.isRememberMeEnabled()) return;

    if (await _bio.isDeviceSupported()) {
      if (!mounted) return;
      setState(() => _rememberMe = true);
      await _refreshBiometricVisibility();
      return;
    }

    final creds = await _bio.peekCredentials();
    if (creds == null || !mounted) return;
    setState(() {
      _rememberMe = true;
      _emailController.text = creds.fieldType == 'phone'
          ? EthiopianPhoneNumber.formatForDisplay(creds.identifier)
          : creds.identifier;
      _passwordController.text = creds.password;
    });
  }

  Future<void> _refreshBiometricVisibility() async {
    if (kIsWeb) {
      if (mounted) setState(() => _showBiometric = false);
      return;
    }
    if (!await _bio.hasEnabledSession()) {
      if (mounted) setState(() => _showBiometric = false);
      return;
    }
    final prefersFace = await _bio.prefersFaceIcon();
    final identifier = _emailController.text.trim();
    final show = identifier.isEmpty ||
        await _bio.matchesStoredLoginIdentifier(identifier);
    if (mounted) {
      setState(() {
        _showBiometric = show;
        _prefersFaceIcon = prefersFace;
      });
    }
  }

  Future<void> _persistCredentialsAfterLogin({
    required String identifier,
    required String password,
    required bool rememberMe,
  }) async {
    final fieldType = identifier.contains('@') ? 'email' : 'phone';

    if (rememberMe) {
      if (await _bio.hasCredentialBlob()) {
        final matches = await _bio.matchesStoredLoginIdentifier(
          identifier,
          fieldType: fieldType,
        );
        if (!matches) {
          await _bio.clearSessionKeepOptOut();
        }
      }
      await _bio.saveCredentials(identifier, password, fieldType);
      await _bio.setRememberMeEnabled(true);
      if (await _bio.isDeviceSupported()) {
        await _bio.enableBiometricLogin();
      }
    } else {
      await _bio.clearRememberedLogin();
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final identifier = EthiopianPhoneNumber.normalizeIdentifier(
          _emailController.text,
        ) ??
        _emailController.text.trim();

    await _performLogin(
      identifier: identifier,
      password: _passwordController.text,
      rememberMe: _rememberMe,
    );
  }

  Future<void> _handleBiometricLogin() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      if (!await _bio.isDeviceSupported()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('auth.biometric_not_available'.tr())),
          );
        }
        return;
      }

      final biometrics = await _bio.getAvailableBiometrics();
      if (biometrics.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('auth.biometric_not_enrolled'.tr())),
          );
        }
        return;
      }

      final authenticated = await _bio.authenticate(
        localizedReason: 'auth.biometric_auth_reason'.tr(),
      );
      if (!authenticated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('auth.biometric_login_failed'.tr())),
          );
        }
        return;
      }
      if (!mounted) return;

      final creds = await _bio.readCredentials();
      if (creds == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('auth.biometric_login_failed'.tr())),
          );
        }
        return;
      }

      await _performLogin(
        identifier: creds.identifier,
        password: creds.password,
        rememberMe: await _bio.isRememberMeEnabled(),
        fromBiometric: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _performLogin({
    required String identifier,
    required String password,
    required bool rememberMe,
    bool fromBiometric = false,
  }) async {
    setState(() => _isLoading = true);

    try {
      final fcmToken = await getIt<NotificationService>().getFcmToken();
      final result = await ApiService.loginDriver(
        email: identifier,
        password: password,
        fcmToken: fcmToken,
        deviceToken: fcmToken,
      );

      if (result['success'] == true) {
        await _persistCredentialsAfterLogin(
          identifier: identifier,
          password: password,
          rememberMe: rememberMe,
        );
        await _refreshBiometricVisibility();

        await getIt<NotificationService>().onUserAuthenticated();

        final data = result['data'];
        final user = data is Map ? data['user'] : null;
        final userType = user is Map && user['type'] != null
            ? user['type'].toString()
            : null;

        // Extract verification status
        final bool emailVerified = user is Map && user['email_verified_at'] != null;
        final bool phoneVerified = user is Map && user['phone_verified_at'] != null;
        final String? email = user is Map ? user['email']?.toString() : null;
        final String? phone = user is Map ? user['phone']?.toString() : null;

        // Determine destination route
        String? destinationRoute;
        bool isDriver = false;
        if (UserTypeConstants.isAdmin(userType)) {
          destinationRoute = AppRouter.dashboard;
        } else if (UserTypeConstants.isHandyman(userType)) {
          destinationRoute = AppRouter.handymanHome;
        } else if (UserTypeConstants.isDriver(userType)) {
          isDriver = true;
        } else if (UserTypeConstants.isCourier(userType)) {
          destinationRoute = AppRouter.deliveryHome;
        }

        if (destinationRoute == null && !isDriver) {
          if (mounted) {
            await getIt<SecureStorageService>().clearSession();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Unauthorized. This app is for drivers, handymen and admins.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        if (!mounted) return;

        final bool mandatoryPhone =
            PhoneVerificationGate.requiresMandatoryPhone(userType);

        if (mandatoryPhone && !phoneVerified) {
          _showVerificationPage(
            email: email,
            phone: phone,
            emailVerified: emailVerified,
            phoneVerified: phoneVerified,
            destinationRoute: destinationRoute,
            isDriver: isDriver,
            requirePhoneVerification: true,
            showEmailVerification: false,
          );
        } else if (!emailVerified || !phoneVerified) {
          _showVerificationPage(
            email: email,
            phone: phone,
            emailVerified: emailVerified,
            phoneVerified: phoneVerified,
            destinationRoute: destinationRoute,
            isDriver: isDriver,
          );
        } else if (isDriver) {
          final status =
              await getIt<SecureStorageService>().getApplicationStatus();
          if (!mounted) return;
          final gate = ApplicationStatusGate.routeFor(status);
          if (gate != null) {
            context.goNamed(gate);
          } else {
            _showDriverModeChoice(context);
          }
        } else {
          context.goNamed(destinationRoute!);
        }
      } else {
        if (fromBiometric) {
          await _bio.clearAll();
          if (mounted) {
            setState(() {
              _rememberMe = false;
              _showBiometric = false;
            });
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'auth.login_error'.tr()),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showVerificationPage({
    required String? email,
    required String? phone,
    required bool emailVerified,
    required bool phoneVerified,
    required String? destinationRoute,
    required bool isDriver,
    bool requirePhoneVerification = false,
    bool showEmailVerification = true,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VerificationRequiredPage(
          email: email,
          phone: phone,
          emailVerified: emailVerified,
          phoneVerified: phoneVerified,
          requirePhoneVerification: requirePhoneVerification,
          showEmailVerification: showEmailVerification,
          onContinue: () async {
            if (requirePhoneVerification) {
              final verified = await PhoneVerificationGate.isPhoneVerified();
              if (!verified) return;
            }
            if (!context.mounted) return;
            Navigator.pop(context);
            if (isDriver) {
              final status =
                  await getIt<SecureStorageService>().getApplicationStatus();
              if (!context.mounted) return;
              final gate = ApplicationStatusGate.routeFor(status);
              if (gate != null) {
                context.goNamed(gate);
              } else {
                _showDriverModeChoice(context);
              }
            } else if (destinationRoute != null) {
              context.goNamed(destinationRoute);
            }
          },
        ),
      ),
    );
  }

  Future<void> _showDriverModeChoice(BuildContext context) async {
    final storage = getIt<SecureStorageService>();
    final choice = await showModalBottomSheet<String>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DriverModeSheet(),
    );
    if (!mounted || choice == null) return;
    await storage.saveDriverMode(choice);
    if (!mounted) return;
    if (choice == 'delivery') {
      context.goNamed(AppRouter.deliveryHome);
    } else {
      context.goNamed(AppRouter.rideHome);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 32),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/logo.jpg',
                      width: 90,
                      height: 90,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Welcome Back',
                    style: AppTextStyles.headline2.copyWith(
                      color: AuthColors.title,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sign in to continue to your account',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AuthColors.hint,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 36),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Email or Phone',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AuthColors.label,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: AppTextStyles.bodyMedium.copyWith(color: AuthColors.title),
                    decoration: _inputDecoration(
                      hint: 'e.g. johndoe@email.com',
                      prefixIcon: const Icon(Icons.email_outlined, size: 20, color: AuthColors.hint),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email or phone number';
                      }
                      if (value.contains('@')) {
                        if (!value.contains('.') && value.length < 5) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      }
                      if (!EthiopianPhoneNumber.isValid(value)) {
                        return 'Enter a valid Ethiopian phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Password',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AuthColors.label,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: AppTextStyles.bodyMedium.copyWith(color: AuthColors.title),
                    decoration: _inputDecoration(
                      hint: 'Enter your password',
                      prefixIcon: const Icon(Icons.lock_outline, size: 20, color: AuthColors.hint),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: AuthColors.hint,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (value) => PasswordRules.validate(
                      value,
                      emptyMessage: 'Please enter your password',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: Checkbox(
                          value: _rememberMe,
                          activeColor: AuthColors.primary,
                          onChanged: _isLoading
                              ? null
                              : (value) =>
                                  setState(() => _rememberMe = value ?? false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _isLoading
                            ? null
                            : () => setState(() => _rememberMe = !_rememberMe),
                        child: Text(
                          'auth.login_remember_me'.tr(),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AuthColors.label,
                          ),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => context.pushNamed(AppRouter.forgotPassword),
                        child: Text(
                          'auth.forgot_password'.tr(),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AuthColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AuthColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shadowColor: Colors.transparent,
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
                              'Sign In',
                              style: AppTextStyles.button.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                  if (_showBiometric && !kIsWeb) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'auth.login_biometric_or_divider'.tr(),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AuthColors.hint,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      label: 'auth.login_biometric_button_semantics'.tr(),
                      button: true,
                      child: IconButton(
                        onPressed: _isLoading ? null : _handleBiometricLogin,
                        iconSize: 48,
                        icon: Icon(
                          _prefersFaceIcon
                              ? Icons.face_rounded
                              : Icons.fingerprint,
                          color: AuthColors.primary,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Don\'t have an account? ',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AuthColors.label,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.pushNamed(AppRouter.signUp),
                        child: Text(
                          'Sign Up',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AuthColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
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
      suffixIcon: suffixIcon,
    );
  }
}

class _DriverModeSheet extends StatefulWidget {
  @override
  State<_DriverModeSheet> createState() => _DriverModeSheetState();
}

class _DriverModeSheetState extends State<_DriverModeSheet> {
  String? _selected = 'delivery';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'How would you like to earn?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose your service mode to get started',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 28),

          _buildModeCard(
            mode: 'ride',
            icon: Icons.directions_car_rounded,
            title: 'Ride Service',
            description: 'Pick up passengers and take them to their destinations',
            gradient: const [Color(0xFF4A00E0), Color(0xFF7B2FF7)],
          ),
          const SizedBox(height: 14),
          _buildModeCard(
            mode: 'delivery',
            icon: Icons.local_shipping_rounded,
            title: 'Delivery Service',
            description: 'Pick up packages and deliver them to customers',
            gradient: const [Color(0xFFE65100), Color(0xFFFF8F00)],
          ),

          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _selected != null ? () => Navigator.pop(context, _selected) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _selected == 'ride'
                    ? const Color(0xFF4A00E0)
                    : _selected == 'delivery'
                        ? const Color(0xFFE65100)
                        : Colors.grey.shade300,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade200,
                disabledForegroundColor: Colors.grey.shade400,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                _selected != null ? 'Continue as ${_selected == 'ride' ? 'Ride' : 'Delivery'} Driver' : 'Select a mode',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required String mode,
    required IconData icon,
    required String title,
    required String description,
    required List<Color> gradient,
  }) {
    final isSelected = _selected == mode;
    return GestureDetector(
      onTap: () => setState(() => _selected = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? gradient[0] : Colors.grey.shade200,
            width: isSelected ? 2.5 : 1.5,
          ),
          color: isSelected ? gradient[0].withOpacity(0.05) : Colors.white,
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isSelected ? gradient : [Colors.grey.shade200, Colors.grey.shade300],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? gradient[0] : const Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? gradient[0] : Colors.grey.shade300,
                  width: isSelected ? 2 : 1.5,
                ),
                color: isSelected ? gradient[0] : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
