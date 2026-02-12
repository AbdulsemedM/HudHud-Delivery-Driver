import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';

/// Shared header for auth screens: back button (left) and logo image (right).
class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    this.onBack,
  });

  final VoidCallback? onBack;

  static const String _logoAsset = 'assets/images/sign.png';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Material(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onBack ?? () => context.canPop() ? context.pop() : context.goNamed(AppRouter.login),
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.black87),
              ),
            ),
          ),
          const Spacer(),
          Image.asset(
            _logoAsset,
            height: 36,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
