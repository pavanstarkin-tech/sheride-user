import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
        // Lady Pilot Logo Asset
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
                    'assets/images/final-logo1-1.jpeg',
                    width: size,
                    height: size,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Image.asset(
                      'assets/images/logo.png',
                      width: size,
                      height: size,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/images/bannerlog.png',
                        width: size,
                        height: size,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(size * 0.22),
                child: Image.asset(
                  'assets/images/final-logo1-1.jpeg',
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Image.asset(
                    'assets/images/logo.png',
                    width: size,
                    height: size,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Image.asset(
                      'assets/images/bannerlog.png',
                      width: size,
                      height: size,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

        if (showTagline) ...[
          const SizedBox(height: 10),
          Text(
            'Women Ride Together',
            style: GoogleFonts.inter(
              color: isDark ? Colors.white70 : AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Safe Rides • Stronger Women • Brighter Cities',
            style: GoogleFonts.inter(
              color: AppColors.primaryDark.withValues(alpha: 0.85),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class SheRideBannerLogo extends StatelessWidget {
  final double? height;
  final double? width;
  final BoxFit fit;

  const SheRideBannerLogo({
    super.key,
    this.height,
    this.width = 260,
    this.fit = BoxFit.contain,
  });

  // bannerlog.png natural dimensions are 731x240 (~3.0458:1 aspect ratio)
  static const double bannerAspectRatio = 731.0 / 240.0;

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = width ?? (height != null ? height! * bannerAspectRatio : 260.0);
    final effectiveHeight = height ?? (effectiveWidth / bannerAspectRatio);

    return SizedBox(
      width: effectiveWidth,
      height: effectiveHeight,
      child: AspectRatio(
        aspectRatio: bannerAspectRatio,
        child: Image.asset(
          'assets/images/bannerlog.png',
          fit: fit,
          errorBuilder: (_, __, ___) => Image.asset(
            'assets/images/banner_logo.png',
            fit: fit,
            errorBuilder: (_, __, ___) => Image.asset(
              'assets/images/final-logo1-1.jpeg',
              fit: fit,
              errorBuilder: (_, __, ___) => Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Lady ',
                    style: GoogleFonts.fraunces(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppColors.secondary,
                    ),
                  ),
                  Text(
                    'pilot',
                    style: GoogleFonts.fraunces(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
