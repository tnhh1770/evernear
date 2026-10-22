import 'package:flutter/material.dart';

class AppColors {
  // Brand colors - Material 3 • Flutter Forest & Sage Green Palette
  static const Color primary = Color(0xFF2D6A4F); // Deep Forest Green
  static const Color primaryLight = Color(0xFFE6F2EC); // Soft Sage/Mint Tint
  static const Color primaryDark = Color(0xFF1E4D38); // Darker Forest Green
  static const Color forestGreenDark = Color(0xFF1E5A46); // Forest Green Dark Variant (#1E5A46)

  static const Color secondary = Color(0xFF68A67D); // Soft Sage Leaf Green
  static const Color secondaryLight = Color(0xFFEDF5F0); // Pale Sage Tint
  static const Color accentMint = Color(0xFF52B788); // Mint Accent Green
  static const Color accent = Color(0xFF52B788); // Alias for Mint Accent Green
  static const Color warmSand = Color(0xFFD8D6CE); // Warm Sand / Beige Neutral
  static const Color neutralStone = Color(0xFFD5D6D0); // Neutral Stone (#D5D6D0 / #D8D6CE)

  // Neutral State Colors (Calm, nature-inspired)
  static const Color stateActive = Color(0xFF52B788); // Mint / Sage Green (Safe/Protected)
  static const Color stateCheckInRequired = Color(0xFFD97706); // Warm Amber
  static const Color stateGracePeriod = Color(0xFFE07A5F); // Terracotta Orange
  static const Color stateAlertTriggered = Color(0xFFD9534F); // Soft Coral Red Alert
  static const Color danger = Color(0xFFD9534F); // Alias for Soft Coral Red Alert
  static const Color stateAcknowledged = Color(0xFF2D6A4F); // Deep Forest Green
  static const Color statePaused = Color(0xFF7A8B82); // Muted Sage Grey

  // Alert Backgrounds
  static const Color alertSoftBg = Color(0xFFFDECEA); // Soft Coral Red Tint for Incident Cards
  static const Color alertSurface = Color(0xFFFDECEA); // Alias for Alert Surface (#FDECEA)
  static const Color dangerBg = Color(0xFFFDECEA); // Alias for Soft Coral Red Tint
  static const Color alertSoftBorder = Color(0xFFF5C6CB);

  // Surfaces & Backgrounds
  static const Color background = Color(0xFFF4F6F3); // Soft Sage-Cream Canvas
  static const Color surface = Color(0xFFFFFFFF); // Pure White Card Surface
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFE6E8E4); // Clean subtle sage-sand border
  static const Color chipBackground = Color(0xFFE6F2EC); // Soft mint chip background
  static const Color inputFill = Color(0xFFFFFFFF); // Clean white input fill

  // Text
  static const Color textPrimary = Color(0xFF1B2A22); // Deep Forest Charcoal
  static const Color textSecondary = Color(0xFF5C6B62); // Muted Sage Slate
  static const Color textMuted = Color(0xFF8C9A92); // Placeholder / subtle grey-green
  static const Color divider = Color(0xFFE6E8E4); // Hairline sage-sand divider

  // Promotional Accents & Trust
  static const Color accentGold = Color(0xFFE9C46A); // Warm sun gold accent
  static const Color trustBadgeBg = Color(0xFFE6F2EC);
  static const Color trustBadgeText = Color(0xFF2D6A4F);

  // Glows & Shadows
  static const Color glowActive = Color(0x3352B788); // Soft mint glow
  static const Color glowWarning = Color(0x40D97706);
  static const Color glowAlert = Color(0x40D9534F);

  // Modern Gradients
  static const LinearGradient calmGreenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E4D38), Color(0xFF2D6A4F), Color(0xFF52B788)],
  );

  // Backward compatibility alias
  static const LinearGradient coralGradient = calmGreenGradient;

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFE6F2EC), Color(0xFFF4F6F3)],
  );

  static const LinearGradient warmCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFF9FBF9)],
  );

  static const LinearGradient alertGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD9534F), Color(0xFFE07A5F)],
  );
}


