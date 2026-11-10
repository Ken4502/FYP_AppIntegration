import 'package:flutter/material.dart';

// --- Botanical Color Palette ---
const kPrimaryColor = Color(0xFF1E5A3E); // Deep Forest Evergreen
const kPrimaryLight = Color(0xFF2D8659); // Vibrant Emerald
const kPrimaryDark = Color(0xFF133E29);  // Midnight Moss
const kSecondaryColor = Color(0xFF52B788); // Soft Sage
const kAccentMint = Color(0xFFD8F3DC);   // Pale Mint Dew
const kAccentGold = Color(0xFFE9C46A);   // Warm Sunlight Gold

// Neutrals & Backgrounds (Light Mode)
const kBackgroundColor = Color(0xFFF7FAF7); // Organic Porcelain Off-white
const kSurfaceColor = Color(0xFFFFFFFF);    // Pure Crisp White
const kTextPrimary = Color(0xFF182B21);     // Deep Botanical Slate
const kTextSecondary = Color(0xFF5B7367);   // Muted Moss Gray
const kBorderSubtle = Color(0xFFE5EEE7);    // Leaf Vein Border

// Neutrals & Backgrounds (Dark / Botanical Night Mode)
const kDarkBackgroundColor = Color(0xFF0F1712); // Deep botanical obsidian
const kDarkSurfaceColor = Color(0xFF16231C);    // Deep moss container surface
const kDarkCardColor = Color(0xFF1B2C23);       // Elevated botanical card
const kDarkTextPrimary = Color(0xFFF0FDF4);     // Crisp mint-white text
const kDarkTextSecondary = Color(0xFF9AB2A3);   // Pale sage secondary text
const kDarkBorderSubtle = Color(0xFF24382D);    // Subtle leaf vein border

// Status & Alerts
const kStatusSuccess = Color(0xFF2E7D32);   // Healthy Green
const kStatusWarning = Color(0xFFF59E0B);   // Attention Amber
const kStatusDanger = Color(0xFFEF4444);    // Infected / Critical Red
const kStatusInfo = Color(0xFF3B82F6);      // Sensor Blue

// Layout Dimensions
const double kDefaultPadding = 20.0;
const double kDefaultPaddingSmall = 10.0;
const double kDefaultPaddingLarge = 30.0;
const double kDefaultPaddingExtraLarge = 40.0;
const double kBorderRadius = 18.0;

const Duration kDefaultDuration = Duration(milliseconds: 250);

/// Helper extension for convenient, reactive theme-aware color resolution
extension UrbanGreenThemeContext on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  Color get scaffoldBg => Theme.of(this).scaffoldBackgroundColor;
  Color get surfaceBg => isDarkMode ? kDarkSurfaceColor : kSurfaceColor;
  Color get cardBg => isDarkMode ? kDarkCardColor : kSurfaceColor;
  Color get textPrimaryColor => isDarkMode ? kDarkTextPrimary : kTextPrimary;
  Color get textSecondaryColor => isDarkMode ? kDarkTextSecondary : kTextSecondary;
  Color get borderSubtleColor => isDarkMode ? kDarkBorderSubtle : kBorderSubtle;
}
