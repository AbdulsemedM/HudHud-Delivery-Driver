import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hudhud_delivery_driver/common/theme/app_text_styles.dart';
import 'package:hudhud_delivery_driver/core/constants/user_type_constants.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';
import 'package:hudhud_delivery_driver/core/services/api_service.dart';
import 'package:hudhud_delivery_driver/core/services/secure_storage_service.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/theme/auth_colors.dart';
import 'package:hudhud_delivery_driver/features/auth/presentation/widgets/auth_header.dart';

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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    print('🔘 Login button pressed!');
    print('📝 Form validation check...');
    
    if (!_formKey.currentState!.validate()) {
      print('❌ Form validation failed!');
      return;
    }
    
    print('✅ Form validation passed!');

    setState(() {
      _isLoading = true;
    });

    try {
      print('🚀 Starting login API call...');
      print('Email: ${_emailController.text.trim()}');
      print('Password: ${_passwordController.text.replaceAll(RegExp(r'.'), '*')}');
      
      final result = await ApiService.loginDriver(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      print('📥 Login API Response: $result');

      if (result['success'] == true) {
        final data = result['data'];
        final user = data is Map ? data['user'] : null;
        final userType = user is Map && user['type'] != null
            ? user['type'].toString()
            : null;
        if (UserTypeConstants.isAdmin(userType)) {
          if (mounted) {
            context.goNamed(AppRouter.dashboard);
          }
          return;
        }
        if (UserTypeConstants.isHandyman(userType)) {
          if (mounted) {
            context.goNamed(AppRouter.handymanHome);
          }
          return;
        }
        if (UserTypeConstants.isDriver(userType)) {
          if (mounted) {
            _showDriverModeChoice(context);
          }
          return;
        }
        if (UserTypeConstants.isCourier(userType)) {
          if (mounted) {
            context.goNamed(AppRouter.deliveryHome);
          }
          return;
        }
        if (mounted) {
          await getIt<SecureStorageService>().clearAll();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unauthorized. This app is for drivers, handymen and admins.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        print('❌ Login failed: ${result['message']}');
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Login failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('💥 Login error: $e');
      // Show error message
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
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showDriverModeChoice(BuildContext context) async {
    final storage = getIt<SecureStorageService>();
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Choose mode'),
        content: const Text(
          'Do you want to take ride requests or delivery requests?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('ride'),
            child: const Text('Ride'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('delivery'),
            child: const Text('Delivery'),
          ),
        ],
      ),
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
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AuthHeader(),
                  const SizedBox(height: 24),
                  Text(
                    'Sign In',
                    style: AppTextStyles.headline2.copyWith(
                      color: AuthColors.title,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kindly fill the following details to proceed to your account and access all Businesses offered',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AuthColors.label,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Email address or Phone number',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AuthColors.label,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _inputDecoration(hint: 'Eg. JohnDoe@gmail.com'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email or phone number';
                      }
                      if (value.contains('@') && !value.contains('.') && value.length < 5) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Password',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AuthColors.label,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: _inputDecoration(
                      hint: 'Enter password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: AuthColors.hint,
                          size: 22,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Sign In',
                              style: AppTextStyles.button.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: AppTextStyles.bodyMedium.copyWith(color: AuthColors.label),
                        ),
                        GestureDetector(
                          onTap: () => context.pushNamed(AppRouter.signUp),
                          child: Text(
                            'Sign Up',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AuthColors.link,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
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
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AuthColors.hint, fontSize: 14),
      filled: true,
      fillColor: AuthColors.inputBg,
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
        borderSide: const BorderSide(color: AuthColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      suffixIcon: suffixIcon,
    );
  }
}
