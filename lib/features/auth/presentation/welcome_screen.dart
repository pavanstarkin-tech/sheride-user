import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/she_ride_logo.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image with Rider in Pink Helmet
          Image.asset(
            'assets/images/welcome.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),

          // Gradient Overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.95),
                  Colors.white.withValues(alpha: 0.7),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.75),
                  Colors.black.withValues(alpha: 0.95),
                ],
                stops: const [0.0, 0.18, 0.45, 0.75, 1.0],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // SheRide Banner Logo & Tagline Header
                  const SizedBox(height: 8),
                  const SheRideBannerLogo(height: 48),
                  const SizedBox(height: 6),
                  Text(
                    'Safe Rides • Stronger Women • Brighter Cities',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF616161),
                    ),
                  ),

                  const Spacer(),

                  // Bottom Headline matching Screenshot 1
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rides\nBy Women\nFor Women.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'A safer, kinder and more\nconfident way to move.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.85),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Big Pink Pill Button: "Get Started →"
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () => context.go('/login'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE91E63),
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Get Started',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3 Badges at Bottom matching Screenshot 1
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildBottomBadge(Icons.female_rounded, 'Women Riders\nOnly'),
                      _buildBottomBadge(Icons.verified_user_outlined, 'Verified &\nTrained'),
                      _buildBottomBadge(Icons.headset_mic_outlined, '24/7\nWomen Support'),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBadge(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.9),
            height: 1.2,
          ),
        ),
      ],
    );
  }
}
