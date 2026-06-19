import 'package:flutter/material.dart';
import 'package:musee/features/settings/presentation/cubit/settings_state.dart';

class AppColors {
  // Private constructor to prevent instantiation.
  AppColors._();

  /// Light Theme Color Scheme
  /// Generated based on the primary color Color(0xFFFF7643).
  static const ColorScheme lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFFFF7643),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFFFDCCF),
    onPrimaryContainer: Color(0xFF3E0A00),
    secondary: Color(0xFF765A51),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFFFDCCF),
    onSecondaryContainer: Color(0xFF2B1811),
    tertiary: Color(0xFF666031),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFEEE5AB),
    onTertiaryContainer: Color(0xFF201C00),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: Color(0xFFFFF8F6),
    onSurface: Color(0xFF201A18),
    surfaceContainerHighest: Color(0xFFF4DED7),
    onSurfaceVariant: Color(0xFF52433F),
    outline: Color(0xFF84736E),
    shadow: Color(0xFF000000),
    inverseSurface: Color(0xFF362F2D),
    onInverseSurface: Color(0xFFFBEEEA),
    inversePrimary: Color(0xFFFFB799),
  );

  /// Dark Theme Color Scheme
  /// Generated based on the primary color Color(0xFFFF7643).
  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFFF7643),
    onPrimary: Color(0xFF631900),
    primaryContainer: Color(0xFF8D2800),
    onPrimaryContainer: Color(0xFFFFDCCF),
    secondary: Color(0xFFE5BFAF),
    onSecondary: Color(0xFF432C25),
    secondaryContainer: Color(0xFF5C423A),
    onSecondaryContainer: Color(0xFFFFDCCF),
    tertiary: Color(0xFFD1C991),
    onTertiary: Color(0xFF363107),
    tertiaryContainer: Color(0xFF4E481C),
    onTertiaryContainer: Color(0xFFEEE5AB),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF121212),
    onSurface: Color(0xFFECE0DD),
    surfaceContainerHighest: Color(0xFF52433F),
    onSurfaceVariant: Color(0xFFD6C2BD),
    outline: Color(0xFF9F8C87),
    shadow: Color(0xFF000000),
    inverseSurface: Color(0xFFECE0DD),
    onInverseSurface: Color(0xFF362F2D),
    inversePrimary: Color(0xFFB33B00),
  );

  static ColorScheme getLightScheme(AppThemeProfile profile) {
    if (profile == AppThemeProfile.sunsetGlow) {
      return lightColorScheme;
    }
    return ColorScheme.fromSeed(
      seedColor: profile.seedColor,
      brightness: Brightness.light,
    );
  }

  static ColorScheme getDarkScheme(AppThemeProfile profile) {
    if (profile == AppThemeProfile.sunsetGlow) {
      return darkColorScheme;
    }
    return ColorScheme.fromSeed(
      seedColor: profile.seedColor,
      brightness: Brightness.dark,
    ).copyWith(
      surface: const Color(0xFF121212),
    );
  }
}

extension AppThemeProfileExtension on AppThemeProfile {
  String get label {
    switch (this) {
      case AppThemeProfile.sunsetGlow:
        return 'Sunset Glow';
      case AppThemeProfile.oceanBreeze:
        return 'Ocean Breeze';
      case AppThemeProfile.forestEmerald:
        return 'Forest Emerald';
      case AppThemeProfile.royalAmethyst:
        return 'Royal Amethyst';
      case AppThemeProfile.roseVelvet:
        return 'Rose Velvet';
      case AppThemeProfile.midnightGold:
        return 'Midnight Gold';
    }
  }

  Color get seedColor {
    switch (this) {
      case AppThemeProfile.sunsetGlow:
        return const Color(0xFFFF7643);
      case AppThemeProfile.oceanBreeze:
        return const Color(0xFF0F60FF);
      case AppThemeProfile.forestEmerald:
        return const Color(0xFF0A9B5D);
      case AppThemeProfile.royalAmethyst:
        return const Color(0xFF7C3AED);
      case AppThemeProfile.roseVelvet:
        return const Color(0xFFE11D48);
      case AppThemeProfile.midnightGold:
        return const Color(0xFFC5A85C);
    }
  }
}
