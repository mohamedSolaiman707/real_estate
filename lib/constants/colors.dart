import 'package:flutter/material.dart';

class AppColors {
  // Brand & Slate Palette
  static const Color slateDark = Color(0xFF0F172A); // Rich Executive Dark
  static const Color slateCard = Color(0xFF1E293B); // Slate Surface Dark
  static const Color primary = Color(0xFF4F46E5);   // Premium Indigo Accent
  static const Color primaryLight = Color(0xFFEEF2FF);
  static const Color secondary = Color(0xFF0EA5E9); // Sky Accent

  // Status Colors (Vibrant & Soft Pairs)
  static const Color success = Color(0xFF10B981);   // Emerald
  static const Color successBg = Color(0xFFECFDF5);

  static const Color warning = Color(0xFFF59E0B);   // Amber
  static const Color warningBg = Color(0xFFFFFBEB);

  static const Color danger = Color(0xFFEF4444);    // Rose / Red
  static const Color dangerBg = Color(0xFFFEF2F2);

  static const Color info = Color(0xFF6366F1);      // Indigo Soft
  static const Color infoBg = Color(0xFFEEF2FF);

  // Background & Surface
  static const Color background = Color(0xFFF8FAFC); // Very Soft Slate White Canvas
  static const Color surface = Colors.white;
  static const Color surfaceSubtle = Color(0xFFF1F5F9);

  // Borders & Dividers
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF8FAFC);

  // Text Hierarchy
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textLight = Colors.white;

  // Custom Modern Shadow Definitions
  static List<BoxShadow> get cardShadow => [
        const BoxShadow(
          color: Color(0x08000000),
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get hoverShadow => [
        const BoxShadow(
          color: Color(0x12000000),
          blurRadius: 24,
          offset: Offset(0, 8),
        ),
      ];
}

