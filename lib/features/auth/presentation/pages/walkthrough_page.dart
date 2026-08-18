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
      header: 'Welcome to HudHud Admin',
      headline: 'Your partner for growth',
      description:
          'We care about your success. Let\'s work together to grow your business.',
      icon: Icons.handshake_outlined,
    ),
    WalkthroughSlide(
      header: 'Earn on your terms',
      headline: 'Make a living by driving',
      description:
          'Access our platform and clients. Earn based on every trip you complete.',
      icon: Icons.savings_outlined,
    ),
    WalkthroughSlide(
      header: 'Flexible schedule',
      headline: 'Drive when it works for you',
      description:
          'Choose your hours and accept only the deliveries that fit your day.',
      icon: Icons.schedule_outlined,
    ),
    WalkthroughSlide(
      header: 'Support when you need it',
      headline: 'We\'re here to help',
      description:
          'Get support from our team and tools that make every trip smoother.',
      icon: Icons.support_agent_outlined,
    ),
  ];

  static const _primary = Color(0xFF5B4BB4);
  static const _textPrimary = Color(0xFF1A1A2E);
  static const _textSecondary = Color(0xFF6B6B80);
  static const _accent = Color(0xFFE8E4F8);

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
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    await WalkthroughPage.markWalkthroughSeen();
    if (!mounted) return;
    _navigateAfterWalkthrough();
  }

  void _skip() async {
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
                const SizedBox(height: 16),
                _buildTopBar(),
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
                _buildPageIndicator(),
                const SizedBox(height: 24),
                _buildGetStartedButton(),
                const SizedBox(height: 12),
                Text(
                  'Version 0.0.1',
                  style: AppTextStyles.caption.copyWith(
                    color: _textSecondary.withValues(alpha: 0.6),
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

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF0EEFA),
            Color(0xFFF8F7FC),
            Colors.white,
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: CustomPaint(
        painter: _MeshGradientPainter(),
        size: Size.infinite,
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_currentPage < _slides.length - 1)
            TextButton(
              onPressed: _skip,
              child: Text(
                'Skip',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: _textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            const SizedBox(height: 48),
        ],
      ),
    );
  }

  static const String _logoAsset = 'assets/images/logo.jpg';

  Widget _buildLogo() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.asset(
        _logoAsset,
        height: 56,
        width: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildSlide(WalkthroughSlide slide) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: _accent,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: _primary.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              slide.icon,
              size: 44,
              color: _primary,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            slide.header,
            style: AppTextStyles.bodyMedium.copyWith(
              color: _primary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            slide.headline,
            style: AppTextStyles.headline2.copyWith(
              color: _textPrimary,
              fontWeight: FontWeight.bold,
              height: 1.2,
              fontSize: 26,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            slide.description,
            style: AppTextStyles.bodyMedium.copyWith(
              color: _textSecondary,
              height: 1.5,
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          _slides.length,
          (i) {
            final isActive = i == _currentPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: isActive ? _primary : _textSecondary.withValues(alpha: 0.25),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGetStartedButton() {
    final isLast = _currentPage == _slides.length - 1;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _onGetStarted,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isLast ? 'Get Started' : 'Next',
                style: AppTextStyles.button.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isLast ? Icons.arrow_forward : Icons.arrow_forward_ios,
                size: 18,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MeshGradientPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF5B4BB4).withValues(alpha: 0.04),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.6));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Soft circles for depth
    final circlePaint = Paint()
      ..color = const Color(0xFF7C6FD4).withValues(alpha: 0.06);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.15), 120, circlePaint);
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.45), 80, circlePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
