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
  static const Color syncPaused = Color(0xFFEF4444);

  // Chart
  static const Color chartLine = Color(0xFF3B82F6);
  static const Color chartFill = Color(0x263B82F6);
  static const Color chartGreen = Color(0xFF10B981);
  static const Color chartRed = Color(0xFFEF4444);

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
