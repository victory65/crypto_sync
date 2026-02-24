import 'package:flutter/material.dart';

class AppColors {
  // Background layers
  static const Color background = Color(0xFF0B0F1A);
  static const Color surface = Color(0xFF111827);
  static const Color card = Color(0xFF1F2937);
  static const Color cardElevated = Color(0xFF253040);

  // Primary palette
  static const Color primary = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF2563EB);
  static const Color primaryLight = Color(0xFF60A5FA);

  // Status
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF6366F1);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color textDisabled = Color(0xFF374151);

  // Dividers / borders
  static const Color divider = Color(0xFF1F2937);
  static const Color border = Color(0xFF374151);
  static const Color borderActive = Color(0xFF3B82F6);

  // Sync status
  static const Color syncActive = Color(0xFF10B981);
  static const Color syncDelayed = Color(0xFFF59E0B);
  static const Color syncPaused = Color(0xFF6B7280);

  // Chart
  static const Color chartLine = Color(0xFF3B82F6);
  static const Color chartFill = Color(0x263B82F6);
  static const Color chartGreen = Color(0xFF10B981);
  static const Color chartRed = Color(0xFFEF4444);

  // Light Mode Palette (Premium Milky Green)
  static const Color lightBackground = Color(0xFFF5F7F2); // Soft Milky with hint of Sage
  static const Color lightSurface = Colors.white;
  static const Color lightCard = Colors.white;
  static const Color lightTextPrimary = Color(0xFF1A1C18); // Charcoal with green undertone
  static const Color lightTextSecondary = Color(0xFF43493E); // Muted Olive Slate
  static const Color lightTextMuted = Color(0xFF74796D); // Muted Sage
  static const Color lightDivider = Color(0xFFE1E4DC); // Soft Greenish Divider
  static const Color lightBorder = Color(0xFFDDE1D7); // Subtle Greenish Border

  // Gradients
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0B0F1A), Color(0xFF0F1629)],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF10B981), Color(0xFF059669)],
  );
}
