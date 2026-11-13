import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Tipografía oficial de SwipeFlick según Informe de Diseño:
/// Playfair Display (Títulos cinemáticos) + Inter (UI, Body y Metadatos)
class AppTextStyles {
  // Hero / Display cinematográfico (Playfair Display)
  static TextStyle get heroDisplay => GoogleFonts.playfairDisplay(
        fontSize: 34,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
        height: 1.15,
      );

  static TextStyle get movieTitle => GoogleFonts.playfairDisplay(
        fontSize: 26,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
        height: 1.2,
      );

  static TextStyle get h1 => GoogleFonts.playfairDisplay(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  static TextStyle get h2 => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  static TextStyle get sectionTitle => GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: 0.2,
      );

  // Body & UI (Inter)
  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.normal,
        color: AppColors.textPrimary,
        height: 1.5,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: AppColors.textPrimary,
        height: 1.45,
      );

  static TextStyle get bodySecondary => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.normal,
        color: AppColors.textSecondary,
        height: 1.4,
      );

  static TextStyle get metadata => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      );

  static TextStyle get button => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      );

  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.normal,
        color: AppColors.textSecondary,
      );

  static TextStyle get swipeBadge => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w900,
        letterSpacing: 2.0,
      );
}
