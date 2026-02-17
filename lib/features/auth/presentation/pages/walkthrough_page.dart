import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

  const WalkthroughSlide({
    required this.header,
    required this.headline,
    required this.description,
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
      header: 'Welcome to HudHud Driver.',
      headline: 'A true partner for your taxi business',
      description:
          'At Hudhud we care about you as our driver let\'s work together in growing your business.',
    ),
    WalkthroughSlide(
      header: 'Earn Money.',
      headline: 'Make a daily living by simply driving',
      description:
          'Get access to our client and platform to earn based on trips you make.',
    ),
    WalkthroughSlide(
      header: 'Flexible Schedule.',
      headline: 'Drive when it works for you',
      description:
          'Choose your own hours and accept deliveries that fit your schedule.',
    ),
    WalkthroughSlide(
      header: 'Support When You Need It.',
      headline: 'We\'re here to help you succeed',
      description:
          'Get support from our team and access to tools that make every trip smoother.',
    ),
  ];

  static const _walkthroughPurple = Color(0xFF6F81BF);
  static const _walkthroughBlue = Color(0xFF2196F3);
  static const _walkthroughOrange = Color(0xFFFF9800);
  static const _lightPurple = Color(0xFFE8E0F0);
  static const _dotGrey = Color(0xFFB0B0B0);

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
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
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
    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 24),
                _buildLogo(),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemCount: _slides.length,
                    itemBuilder: (context, index) => _buildSlide(_slides[index]),
                  ),
                ),
                _buildDots(),
                const SizedBox(height: 16),
                _buildGetStartedButton(),
                const SizedBox(height: 8),
                Text(
                  'Version 1.0',
                  style: AppTextStyles.caption.copyWith(color: _dotGrey),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_lightPurple, Colors.white],
              stops: [0.0, 0.5],
            ),
          ),
          child: CustomPaint(
            painter: _DotsPainter(),
            size: Size.infinite,
          ),
        ),
        // Soft orange curved shape below logo area
        Positioned(
          top: 140,
          left: -80,
          right: -80,
          height: 220,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.elliptical(400, 180),
                bottomRight: Radius.elliptical(400, 180),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _walkthroughOrange.withValues(alpha: 0.2),
                  _walkthroughOrange.withValues(alpha: 0.05),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  static const String _logoAsset = 'assets/images/sign.png';

  Widget _buildLogo() {
    return Image.asset(
      _logoAsset,
      height: 48,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }

  Widget _buildSlide(WalkthroughSlide slide) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          Text(
            slide.header,
            style: AppTextStyles.bodyMedium.copyWith(
              color: _walkthroughBlue,
              fontWeight: FontWeight.w500,
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            slide.headline,
            style: AppTextStyles.headline2.copyWith(
              color: const Color(0xFF212121),
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            slide.description,
            style: AppTextStyles.bodyMedium.copyWith(
              color: _dotGrey,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _slides.length,
        (i) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i == _currentPage ? _walkthroughBlue : _dotGrey,
          ),
        ),
      ),
    );
  }

  Widget _buildGetStartedButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _onGetStarted,
          style: ElevatedButton.styleFrom(
            backgroundColor: _walkthroughPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
            elevation: 0,
          ),
          child: Text(
            'Get Started',
            style: AppTextStyles.button.copyWith(
              fontSize: 16,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const dotColor = Color(0xFFD0C4E0);
    const spacing = 24.0;
    const radius = 2.0;
    final paint = Paint()..color = dotColor;
    for (double y = 0; y < size.height * 0.6; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
