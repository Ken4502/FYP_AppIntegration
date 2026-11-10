import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:urbangreen/constants.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: kPrimaryColor,
      scaffoldBackgroundColor: kBackgroundColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: kPrimaryColor,
        brightness: Brightness.light,
        primary: kPrimaryColor,
        onPrimary: Colors.white,
        secondary: kSecondaryColor,
        onSecondary: Colors.white,
        surface: kSurfaceColor,
        onSurface: kTextPrimary,
        error: kStatusDanger,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: kSurfaceColor,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        toolbarHeight: 66,
        iconTheme: const IconThemeData(color: kTextPrimary, size: 22),
        actionsIconTheme: const IconThemeData(color: kTextPrimary, size: 22),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: kTextPrimary,
          fontSize: 19,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.3,
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorColor: Colors.transparent,
      ),
      cardTheme: const CardThemeData(
        color: kSurfaceColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(kBorderRadius)),
          side: BorderSide(color: kBorderSubtle, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: kPrimaryColor.withValues(alpha: 0.25),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.0),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: kPrimaryColor,
          side: const BorderSide(color: kBorderSubtle, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.0),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            color: kPrimaryColor,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: kPrimaryColor,
          textStyle: GoogleFonts.plusJakartaSans(
            color: kPrimaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: kPrimaryDark,
        contentTextStyle: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: Colors.amberAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: kTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: GoogleFonts.plusJakartaSans(
          color: kTextSecondary,
          fontSize: 14,
          height: 1.4,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: kBackgroundColor,
        labelStyle: GoogleFonts.plusJakartaSans(
          color: kTextPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        secondarySelectedColor: kPrimaryColor,
        side: const BorderSide(color: kBorderSubtle),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(
          color: kTextPrimary,
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
        ),
        headlineLarge: GoogleFonts.plusJakartaSans(
          color: kTextPrimary,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          color: kTextPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.3,
        ),
        headlineSmall: GoogleFonts.plusJakartaSans(
          color: kTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          color: kTextPrimary,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          color: kTextPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: GoogleFonts.plusJakartaSans(
          color: kTextPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          color: kTextPrimary,
          fontSize: 15,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          color: kTextSecondary,
          fontSize: 13.5,
          height: 1.45,
        ),
        bodySmall: GoogleFonts.plusJakartaSans(
          color: kTextSecondary,
          fontSize: 12,
        ),
        labelLarge: GoogleFonts.plusJakartaSans(
          color: kTextPrimary,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        labelMedium: GoogleFonts.plusJakartaSans(
          color: kTextSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        labelSmall: GoogleFonts.plusJakartaSans(
          color: kTextSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.0),
          borderSide: const BorderSide(color: kBorderSubtle, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.0),
          borderSide: const BorderSide(color: kBorderSubtle, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.0),
          borderSide: const BorderSide(color: kPrimaryColor, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.0),
          borderSide: const BorderSide(color: kStatusDanger, width: 1.2),
        ),
        labelStyle: GoogleFonts.plusJakartaSans(
          color: kTextSecondary,
          fontSize: 14,
        ),
        hintStyle: GoogleFonts.plusJakartaSans(
          color: Colors.grey.shade400,
          fontSize: 14,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
        elevation: 6,
      ),
      dividerTheme: const DividerThemeData(
        color: kBorderSubtle,
        thickness: 1,
        space: 24,
      ),
    );
  }

  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: kPrimaryLight,
      scaffoldBackgroundColor: kDarkBackgroundColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: kPrimaryLight,
        brightness: Brightness.dark,
        primary: kPrimaryLight,
        onPrimary: Colors.white,
        secondary: kSecondaryColor,
        onSecondary: Colors.black,
        surface: kDarkSurfaceColor,
        onSurface: kDarkTextPrimary,
        error: kStatusDanger,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: kDarkSurfaceColor,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        toolbarHeight: 66,
        iconTheme: const IconThemeData(color: kDarkTextPrimary, size: 22),
        actionsIconTheme: const IconThemeData(color: kDarkTextPrimary, size: 22),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: kDarkTextPrimary,
          fontSize: 19,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.3,
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorColor: Colors.transparent,
      ),
      cardTheme: const CardThemeData(
        color: kDarkCardColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(kBorderRadius)),
          side: BorderSide(color: kDarkBorderSubtle, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryLight,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.0),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: kSecondaryColor,
          side: const BorderSide(color: kDarkBorderSubtle, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.0),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            color: kSecondaryColor,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: kSecondaryColor,
          textStyle: GoogleFonts.plusJakartaSans(
            color: kSecondaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: kDarkSurfaceColor,
        contentTextStyle: GoogleFonts.plusJakartaSans(
          color: kDarkTextPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: kAccentGold,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: kDarkSurfaceColor,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: kDarkTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: GoogleFonts.plusJakartaSans(
          color: kDarkTextSecondary,
          fontSize: 14,
          height: 1.4,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: kDarkSurfaceColor,
        surfaceTintColor: Colors.transparent,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: kDarkBackgroundColor,
        labelStyle: GoogleFonts.plusJakartaSans(
          color: kDarkTextPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        secondarySelectedColor: kPrimaryLight,
        side: const BorderSide(color: kDarkBorderSubtle),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(
          color: kDarkTextPrimary,
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
        ),
        headlineLarge: GoogleFonts.plusJakartaSans(
          color: kDarkTextPrimary,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          color: kDarkTextPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.3,
        ),
        headlineSmall: GoogleFonts.plusJakartaSans(
          color: kDarkTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          color: kDarkTextPrimary,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          color: kDarkTextPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: GoogleFonts.plusJakartaSans(
          color: kDarkTextPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          color: kDarkTextPrimary,
          fontSize: 15,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          color: kDarkTextSecondary,
          fontSize: 13.5,
          height: 1.45,
        ),
        bodySmall: GoogleFonts.plusJakartaSans(
          color: kDarkTextSecondary,
          fontSize: 12,
        ),
        labelLarge: GoogleFonts.plusJakartaSans(
          color: kDarkTextPrimary,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        labelMedium: GoogleFonts.plusJakartaSans(
          color: kDarkTextSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        labelSmall: GoogleFonts.plusJakartaSans(
          color: kDarkTextSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: kDarkSurfaceColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.0),
          borderSide: const BorderSide(color: kDarkBorderSubtle, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.0),
          borderSide: const BorderSide(color: kDarkBorderSubtle, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.0),
          borderSide: const BorderSide(color: kPrimaryLight, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.0),
          borderSide: const BorderSide(color: kStatusDanger, width: 1.2),
        ),
        labelStyle: GoogleFonts.plusJakartaSans(
          color: kDarkTextSecondary,
          fontSize: 14,
        ),
        hintStyle: GoogleFonts.plusJakartaSans(
          color: Colors.grey.shade600,
          fontSize: 14,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: kPrimaryLight,
        foregroundColor: Colors.white,
        elevation: 6,
      ),
      dividerTheme: const DividerThemeData(
        color: kDarkBorderSubtle,
        thickness: 1,
        space: 24,
      ),
    );
  }
}
