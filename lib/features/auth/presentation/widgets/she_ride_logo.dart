import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class SheRideLogo extends StatelessWidget {
  final double size;
  final bool showTagline;
  final bool isDark;
  final bool useCircle;

  const SheRideLogo({
    super.key,
    this.size = 80,
    this.showTagline = true,
    this.isDark = false,
    this.useCircle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Real SheRide Logo Asset
        useCircle
            ? Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: size,
                    height: size,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Image.asset(
                      'assets/images/ogo.png',
                      width: size,
                      height: size,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              )
            : Image.asset(
                'assets/images/logo.png',
                width: size,
                height: size,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Image.asset(
                  'assets/images/ogo.png',
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                ),
              ),

        if (showTagline) ...[
          const SizedBox(height: 10),
          Text(
            'Women Ride Together',
            style: TextStyle(
              color: isDark ? Colors.white70 : AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Safe Rides • Stronger Women • Brighter Cities',
            style: TextStyle(
              color: AppColors.primaryDark.withValues(alpha: 0.8),
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class SheRideBannerLogo extends StatelessWidget {
  final double height;
  final double? width;
  final BoxFit fit;

  const SheRideBannerLogo({
    super.key,
    this.height = 42,
    this.width,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/banner_logo.png',
      height: height,
      width: width,
      fit: fit,
      errorBuilder: (_, __, ___) => Image.asset(
        'assets/images/logo.png',
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFFE91E63),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.female_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8),
            const Text(
              'SheRide',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFFE91E63),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

