import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTextStyles {
  static const String _fontFamily = 'Poppins';
  
  // Headline styles
  static TextStyle get headline1 => GoogleFonts.getFont(
    _fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.bold,
    letterSpacing: -1.5,
  );
  
  static TextStyle get headline2 => GoogleFonts.getFont(
    _fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );
  
  static TextStyle get headline3 => GoogleFonts.getFont(
    _fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );
  
  static TextStyle get headline4 => GoogleFonts.getFont(
    _fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.25,
  );
  
  // Body styles
  static TextStyle get bodyLarge => GoogleFonts.getFont(
    _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
  );
  
  static TextStyle get bodyMedium => GoogleFonts.getFont(
    _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
  );
  
  static TextStyle get bodySmall => GoogleFonts.getFont(
    _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
  );
  
  // Button styles
  static TextStyle get button => GoogleFonts.getFont(
    _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.25,
  );
  
  // Caption and overline
  static TextStyle get caption => GoogleFonts.getFont(
    _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
  );
  
  static TextStyle get overline => GoogleFonts.getFont(
    _fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w400,
    letterSpacing: 1.5,
  );
}