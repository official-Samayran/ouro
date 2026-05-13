import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OuroTheme {
  static const Color oledBlack = Color(0xFF000000);
  static const Color cardGrey = Color(0xFF121212);
  static const Color accentRed = Color(0xFFFF0000);

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: oledBlack,
    primaryColor: oledBlack,
    hintColor: Colors.grey,
    textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
      headlineMedium: GoogleFonts.outfit(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    ),
    colorScheme: const ColorScheme.dark(
      primary: oledBlack,
      surface: cardGrey,
      onSurface: Colors.white,
      secondary: accentRed,
    ),
  );

  static BoxDecoration glassDecoration = BoxDecoration(
    color: Colors.white.withOpacity(0.05),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.white.withOpacity(0.1)),
  );
}
