import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:urbangreen/constants.dart';

class AppTheme {
  // Private constructor
  AppTheme._();

  static final ThemeData lightTheme = ThemeData(
    primaryColor: kPrimaryColor,
    scaffoldBackgroundColor: const Color(0xFFF9F8FD),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimaryColor,
        padding: const EdgeInsets.all(kDefaultPadding),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kPrimaryColor,
      ),
    ),
    appBarTheme: const AppBarTheme(
        backgroundColor: kPrimaryColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white)),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Color(0xFF3C4046)),
      bodyMedium: TextStyle(color: Color(0xFF3C4046)),
      headlineSmall: TextStyle(color: Color(0xFF3C4046), fontSize: 24),
    ).apply(
      fontFamily: GoogleFonts.poppins().fontFamily,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(
          color: Colors.grey,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(
          color: kPrimaryColor,
        ),
      ),
      labelStyle: GoogleFonts.poppins(
        color: Colors.grey[600],
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kPrimaryColor,
      foregroundColor: Colors.white,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: kPrimaryColor,
      unselectedItemColor: Colors.grey,
      elevation: 20,
      showUnselectedLabels: true,
    ),
    useMaterial3: true,
  );
}
