import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Lady Pilot Brand Color Palette
  static const Color primary = Color(0xFF7F00FD);       // Lady Pilot Electric Purple
  static const Color primaryDark = Color(0xFF5C00BC);   // Deep Royal Purple
  static const Color primaryLight = Color(0xFFEDDCFF);  // Soft Lavender Tint
  static const Color primaryHover = Color(0xFF6E00DE);  // Rich Violet
  static const Color secondary = Color(0xFFFFB001);     // Lady Pilot Golden Orange (Primary CTA & Highlights)
  static const Color goldenOrange = Color(0xFFFFB001);  // Golden Orange
  static const Color goldenOrangeDark = Color(0xFFE69E00);
  static const Color goldenOrangeLight = Color(0xFFFFF0BF);
  static const Color accentRose = Color(0xFFFF4081);     // Accent Rose

  // Backgrounds & Surfaces
  static const Color background = Color(0xFFF6F6FE);   // Lady Pilot Soft White
  static const Color surface = Color(0xFFFFFFFF);      // Pure White Card
  static const Color surfaceVariant = Color(0xFFF0EEFD); // Tinted Soft Purple Card

  // Text Colors
  static const Color textPrimary = Color(0xFF180D2B);   // Deep Charcoal Purple (High Contrast AAA)
  static const Color textSecondary = Color(0xFF5E5974); // Slate Purple Gray
  static const Color textLight = Color(0xFF8F89A5);     // Subdued Lavender Gray
  static const Color textOnPrimary = Color(0xFFF6F6FE); // Soft White on Purple
  static const Color textOnGolden = Color(0xFF180D2B);  // High Contrast Text on Golden Orange

  // Status & Safety Colors
  static const Color success = Color(0xFF00C853);       // Safety Verified Green
  static const Color warning = Color(0xFFFFB001);       // Golden Orange Warning / Amber
  static const Color error = Color(0xFFE53935);         // Alert Red
  static const Color emergencyRed = Color(0xFFD50000);   // SOS Red

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF7F00FD), Color(0xFF6200C7), Color(0xFF480096)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldenGradient = LinearGradient(
    colors: [Color(0xFFFFB001), Color(0xFFFF8F00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFFF6F6FE), Color(0xFFFFFFFF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF310068), Color(0xFF7F00FD)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
