import 'package:flutter/material.dart';

/// GoDine Theme — matches web dashboard CSS variables exactly
class AppColors {
  static const Color bg = Color(0xFF050505);
  static const Color surface1 = Color(0xFF0E0E0E);
  static const Color surface2 = Color(0xFF151515);
  static const Color surface3 = Color(0xFF1C1C1C);

  static const Color lime = Color(0xFFB6FF2A);
  static const Color limeAlpha08 = Color(0x14B6FF2A);
  static const Color limeAlpha18 = Color(0x2EB6FF2A);
  static const Color limeAlpha30 = Color(0x4DB6FF2A);

  static const Color white = Color(0xFFF0F0EC);
  static const Color muted = Color(0xFF6B6B67);
  static const Color border = Color(0x12FFFFFF);
  static const Color borderLight = Color(0x26FFFFFF);

  static const Color red = Color(0xFFFF4444);
  static const Color redAlpha = Color(0x1AFF4444);
  static const Color redBorder = Color(0x33FF4444);

  static const Color green = Color(0xFF4ADE80);
  static const Color greenAlpha = Color(0x1F4ADE80);

  static const Color amber = Color(0xFFFBBF24);
  static const Color amberAlpha = Color(0x1FFBBF24);
}

class AppRadius {
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 24;
  static const double full = 100;
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
  static const double xxl = 40;
}

ThemeData buildAppTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      surface: AppColors.bg,
      primary: AppColors.lime,
      secondary: AppColors.lime,
      onPrimary: AppColors.bg,
      onSurface: AppColors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface1,
      foregroundColor: AppColors.white,
      elevation: 0,
    ),
    cardColor: AppColors.surface1,
    dividerColor: AppColors.border,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.white),
      headlineMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.white),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.white),
      bodyLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.white),
      bodyMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.muted),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.muted),
      labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.muted, letterSpacing: 1.5),
    ),
  );
}
