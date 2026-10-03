import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class SheRideLogo extends StatelessWidget {
  final double size;
  final bool showTagline;
  final bool isDark;

  const SheRideLogo({
    super.key,
    this.size = 80,
    this.showTagline = true,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Brand Icon Circle
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.primaryGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.electric_scooter_rounded,
                  color: Colors.white,
                  size: size * 0.52,
                ),
                Positioned(
                  right: size * 0.16,
                  top: size * 0.16,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.shield_rounded,
                      color: AppColors.primary,
                      size: size * 0.22,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Brand Name "SheRide"
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'She',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: size * 0.42,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              TextSpan(
                text: 'Ride',
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.textPrimary,
                  fontSize: size * 0.42,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),

        if (showTagline) ...[
          const SizedBox(height: 4),
          Text(
            'Women Ride Together',
            style: TextStyle(
              color: isDark ? Colors.white70 : AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
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
