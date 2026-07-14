import 'package:flutter/material.dart';

class AppColors {
  // Primary
  static const Color primary = Color(0xFF0392CA);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF007DAD);
  static const Color onPrimaryContainer = Color(0xFFFCFCFF);

  // Gradient
  static const Color gradientStart = Color(0xFF0392CA);
  static const Color gradientEnd = Color(0xFF004C6B);

  // Secondary
  static const Color secondary = Color(0xFF4648D4);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFF6063EE);
  static const Color onSecondaryContainer = Color(0xFFFFFBFF);

  // Tertiary
  static const Color tertiary = Color(0xFFB90538);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFFDC2C4F);

  // Surface
  static const Color surface = Color(0xFFF8F9FB);
  static const Color surfaceDim = Color(0xFFD9DADC);
  static const Color surfaceBright = Color(0xFFF8F9FB);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF3F4F6);
  static const Color surfaceContainer = Color(0xFFEDEEF0);
  static const Color surfaceContainerHigh = Color(0xFFE7E8EA);
  static const Color surfaceContainerHighest = Color(0xFFE1E2E4);

  // On Surface
  static const Color onSurface = Color(0xFF191C1E);
  static const Color onSurfaceVariant = Color(0xFF3E484F);
  static const Color inverseSurface = Color(0xFF2E3132);
  static const Color inverseOnSurface = Color(0xFFF0F1F3);

  // Outline
  static const Color outline = Color(0xFF6F7880);
  static const Color outlineVariant = Color(0xFFBEC8D0);

  // Background
  static const Color background = Color(0xFFF8F9FB);
  static const Color onBackground = Color(0xFF191C1E);

  // Error
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);

  // Gradient helper
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [gradientStart, gradientEnd],
  );
}
