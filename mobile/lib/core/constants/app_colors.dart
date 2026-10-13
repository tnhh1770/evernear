import 'package:flutter/material.dart';

class AppColors {
  // Brand colors - calming, gentle, trustworthy
  static const Color primary = Color(0xFF2E7D32); // Calming forest green
  static const Color primaryLight = Color(0xFFE8F5E9);
  static const Color primaryDark = Color(0xFF1B5E20);
  
  static const Color secondary = Color(0xFF00796B); // Teal
  static const Color secondaryLight = Color(0xFFE0F2F1);

  // Neutral State Colors (Never alarming)
  static const Color stateActive = Color(0xFF2E7D32); // Green
  static const Color stateCheckInRequired = Color(0xFFE65100); // Gentle Amber/Orange
  static const Color stateGracePeriod = Color(0xFFD84315); // Deep Orange
  static const Color stateAlertTriggered = Color(0xFFC62828); // Muted Crimson
  static const Color stateAcknowledged = Color(0xFF1565C0); // Blue
  static const Color statePaused = Color(0xFF757575); // Neutral Grey

  // Surfaces & Backgrounds
  static const Color background = Color(0xFFF7FAF8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFE2EBE5);
  static const Color chipBackground = Color(0xFFEDF4F0);
  
  // Text
  static const Color textPrimary = Color(0xFF1A2E22);
  static const Color textSecondary = Color(0xFF52665A);
  static const Color textMuted = Color(0xFF8B9E93);
  static const Color divider = Color(0xFFE5EDE8);

  // Promotional Accents & Trust
  static const Color accentGold = Color(0xFFFFB300);
  static const Color trustBadgeBg = Color(0xFFE8F5E9);
  static const Color trustBadgeText = Color(0xFF2E7D32);

  // Glows & Shadows
  static const Color glowActive = Color(0x402E7D32);
  static const Color glowWarning = Color(0x40E65100);
  static const Color glowAlert = Color(0x40C62828);

  // Modern Gradients
  static const LinearGradient calmGreenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF00796B)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFE8F5E9), Color(0xFFF7FAF8)],
  );

  static const LinearGradient warmCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFF9FDFB)],
  );

  static const LinearGradient alertGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFC62828), Color(0xFFD84315)],
  );
}

