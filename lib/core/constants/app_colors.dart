import 'package:flutter/material.dart';

/// High-contrast, accessible color palette for Let's Fly mobile client.
class AppColors {
  AppColors._();

  // Primary Theme
  static const Color primary = Color(0xFF1E88E5);
  static const Color primaryDark = Color(0xFF1565C0);
  static const Color accent = Color(0xFFFFB300);
  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color surfaceVariant = Color(0xFF2C2C2C);
  static const Color cardBg = Color(0xFF2C2C2C);

  // High-contrast text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0BEC5);
  static const Color textMuted = Color(0xFF78909C);
  static const Color textDisabled = Color(0xFF616161);

  // Status & Feedback
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFFA000);
  static const Color info = Color(0xFF29B6F6);

  // UNO Colors (High contrast)
  static const Color unoRed = Color(0xFFE53935);
  static const Color unoYellow = Color(0xFFFFD600);
  static const Color unoGreen = Color(0xFF43A047);
  static const Color unoBlue = Color(0xFF1E88E5);
  static const Color unoWild = Color(0xFF8E24AA);
}
