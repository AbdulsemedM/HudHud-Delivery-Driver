import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hudhud_delivery_driver/common/theme/app_colors.dart';
import 'package:hudhud_delivery_driver/common/theme/app_text_styles.dart';
import 'package:hudhud_delivery_driver/core/constants/user_type_constants.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';
import 'package:hudhud_delivery_driver/core/services/secure_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Walkthrough slide data.
class WalkthroughSlide {
  final String header;
  final String headline;
  final String description;
  final IconData icon;

  const WalkthroughSlide({
    required this.header,
    required this.headline,
    required this.description,
    required this.icon,
  });
}

/// First-run walkthrough with 4 slides. Shown only once; completion is persisted.
class WalkthroughPage extends StatefulWidget {
  const WalkthroughPage({super.key});

  static const String _seenKey = 'has_seen_walkthrough';

  static Future<bool> hasSeenWalkthrough() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seenKey) ?? false;
  }

  static Future<void> markWalkthroughSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
  }

  @override
  State<WalkthroughPage> createState() => _WalkthroughPageState();
}

class _WalkthroughPageState extends State<WalkthroughPage> {
  static const List<WalkthroughSlide> _slides = [
    WalkthroughSlide(
      header: 'Welcome',
      headline: 'Your partner in delivery',
      description:
          'We’re here to help you grow. Join the HudHud network and start earning on your schedule.',
      icon: Icons.local_shipping_rounded,
    ),
    WalkthroughSlide(
      header: 'Earn',
      headline: 'Get paid for every delivery',
      description:
          'Access our platform and clients. Your earnings grow with every trip you complete.',
      icon: Icons.payments_rounded,
    ),
    WalkthroughSlide(
      header: 'Flexibility',
      headline: 'Drive when it works for you',
      description:
          'Choose your hours and accept deliveries that fit your day. You’re in control.',
      icon: Icons.schedule_rounded,
    ),
    WalkthroughSlide(
      header: 'Support',
      headline: 'We’re here when you need us',
      description:
          'Get help from our team and use tools that make every delivery smoother.',
      icon: Icons.support_agent_rounded,
    ),
  ];

  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _onGetStarted() async {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
      return;
    }
    await WalkthroughPage.markWalkthroughSeen();
    if (!mounted) return;
    _navigateAfterWalkthrough();
  }

  Future<void> _navigateAfterWalkthrough() async {
    final secureStorage = getIt<SecureStorageService>();
    final hasToken = await secureStorage.hasToken();
    if (!hasToken) {
      context.goNamed(AppRouter.login);
      return;
    }
    final userType = await secureStorage.getUserType();
    if (UserTypeConstants.isAdmin(userType)) {
      context.goNamed(AppRouter.dashboard);
    } else if (UserTypeConstants.isHandyman(userType)) {
      context.goNamed(AppRouter.handymanHome);
    } else if (UserTypeConstants.isDriver(userType)) {
      final driverMode = await secureStorage.getDriverMode();
      if (driverMode == 'delivery') {
        context.goNamed(AppRouter.deliveryHome);
      } else {
        context.goNamed(AppRouter.rideHome);
      }
    } else if (UserTypeConstants.isCourier(userType)) {
      context.goNamed(AppRouter.deliveryHome);
    } else {
      await secureStorage.clearAll();
      context.goNamed(AppRouter.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _slides.length - 1;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          _buildBackground(context),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildLogo(),
                const SizedBox(height: 32),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemCount: _slides.length,
                    itemBuilder: (context, index) => _buildSlide(
                      context,
                      _slides[index],
                      index,
                    ),
                  ),
                ),
                _buildPageIndicator(context),
                const SizedBox(height: 24),
                _buildGetStartedButton(context, isLastPage),
                const SizedBox(height: 12),
                Text(
                  'Version 0.0.1',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondaryLight.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryColor.withValues(alpha: 0.06),
            AppColors.primaryLightColor.withValues(alpha: 0.03),
            Colors.white,
          ],
          stops: const [0.0, 0.35, 1.0],
        ),
      ),
    );
  }

  static const String _logoAsset = 'assets/images/logo.jpg';

  Widget _buildLogo() {
    return Image.asset(
      _logoAsset,
      height: 44,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }

  Widget _buildSlide(BuildContext context, WalkthroughSlide slide, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSlideIcon(slide.icon, index),
          const SizedBox(height: 32),
          Text(
            slide.header.toUpperCase(),
            style: AppTextStyles.overline.copyWith(
              color: AppColors.primaryColor,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.8,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            slide.headline,
            style: AppTextStyles.headline2.copyWith(
              color: AppColors.textPrimaryLight,
              fontWeight: FontWeight.w700,
              height: 1.25,
              fontSize: 26,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            slide.description,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondaryLight,
              height: 1.5,
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSlideIcon(IconData icon, int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryColor.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(
        icon,
        size: 40,
        color: AppColors.primaryColor,
      ),
    );
  }

  Widget _buildPageIndicator(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _slides.length,
        (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: i == _currentPage ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: i == _currentPage
                ? AppColors.primaryColor
                : AppColors.textSecondaryLight.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }

  Widget _buildGetStartedButton(BuildContext context, bool isLastPage) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: _onGetStarted,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            shadowColor: AppColors.primaryColor.withValues(alpha: 0.35),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            isLastPage ? 'Get Started' : 'Next',
            style: AppTextStyles.button.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}
