import 'package:flutter/animation.dart';

class AppAnimations {
  AppAnimations._();

  // Durations
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 550);

  // Perceived Response Target Timings
  static const Duration instantFeedback = Duration(milliseconds: 90);
  static const Duration pageTransition = Duration(milliseconds: 280);

  // Curves
  static const Curve gentle = Curves.easeInOutCubic;
  static const Curve snappy = Curves.easeOutQuart;
  static const Curve bounce = Curves.elasticOut;
  static const Curve spring = Curves.easeOutBack;
}
