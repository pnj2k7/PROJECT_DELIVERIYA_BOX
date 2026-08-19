import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central color palette — refined for a premium, industrial-logistics feel.
class AppColors {
  AppColors._();

  static const background = Color(0xFF0A0D14);
  static const surface = Color(0xFF141926);
  static const surfaceAlt = Color(0xFF1B2233);
  static const border = Color(0xFF262F44);

  static const textPrimary = Color(0xFFF5F7FB);
  static const textSecondary = Color(0xFF8C96AC);

  static const accentA = Color(0xFF5EEAD4); // teal
  static const accentB = Color(0xFF8B7CF6); // violet
  static const luxury = Color(0xFFD8B26A); // champagne gold — premium accent

  static const success = Color(0xFF34D399);
  static const danger = Color(0xFFF87171);
  static const warning = Color(0xFFFBBF24);

  static const accentGradient = LinearGradient(
    colors: [accentA, accentB],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const luxuryGradient = LinearGradient(
    colors: [luxury, Color(0xFFF3E3B8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Soft, out-of-focus "glow" blobs used behind hero screens for a
  // distinctive, non-boxy backdrop instead of a flat solid color.
  static const glowTeal = Color(0xFF5EEAD4);
  static const glowViolet = Color(0xFF8B7CF6);
}

class AppRadius {
  AppRadius._();

  static const card = 28.0;
  static const chip = 14.0;
  static const button = 18.0;
  static const sheet = 32.0;
}

ThemeData buildAppTheme() {
  final base = ThemeData.dark(useMaterial3: true);

  final textTheme = GoogleFonts.soraTextTheme(base.textTheme).apply(
    bodyColor: AppColors.textPrimary,
    displayColor: AppColors.textPrimary,
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    textTheme: textTheme.copyWith(
      headlineMedium: textTheme.headlineMedium?.copyWith(letterSpacing: -0.5),
      titleLarge: textTheme.titleLarge?.copyWith(letterSpacing: -0.3),
    ),
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.accentB,
      secondary: AppColors.accentA,
      surface: AppColors.surface,
      error: AppColors.danger,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: Color(0x2E5EEAD4),
      height: 68,
      elevation: 0,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: textTheme.titleLarge,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
        borderSide: const BorderSide(color: AppColors.accentA, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}
