import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // SheRide Brand Pink Palette
  static const Color primary = Color(0xFFE91E63);       // SheRide Vibrant Pink
  static const Color primaryDark = Color(0xFFC2185B);   // Deep Pink
  static const Color primaryLight = Color(0xFFF8BBD0);  // Soft Accent Pink
  static const Color secondary = Color(0xFFAD1457);     // Accent Magenta
  static const Color accentRose = Color(0xFFFF4081);     // Bright Rose Pink

  // Backgrounds & Surfaces
  static const Color background = Color(0xFFFDF7FA);   // Ultra Soft Blush White
  static const Color surface = Color(0xFFFFFFFF);      // Pure White Card
  static const Color surfaceVariant = Color(0xFFFFF0F5); // Lavender Blush

  // Text Colors
  static const Color textPrimary = Color(0xFF1E1E24);   // Deep Charcoal
  static const Color textSecondary = Color(0xFF7A7E85); // Slate Gray
  static const Color textLight = Color(0xFF9E9E9E);     // Subdued Gray
  static const Color textOnPrimary = Colors.white;

  // Status & Safety Colors
  static const Color success = Color(0xFF00C853);       // Safety Verified Green
  static const Color warning = Color(0xFFFF9100);       // Amber
  static const Color error = Color(0xFFE53935);         // Alert Red
  static const Color emergencyRed = Color(0xFFD50000);   // SOS Red

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFE91E63), Color(0xFFD81B60), Color(0xFFAD1457)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFFFFF0F5), Color(0xFFFFFFFF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF880E4F), Color(0xFFE91E63)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
