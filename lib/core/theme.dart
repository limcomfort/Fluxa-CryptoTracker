import 'package:flutter/material.dart';

/// Design tokens extracted from the Figma mockups.
class AppColors {
  AppColors._();

  static const Color bg = Color(0xFF0B0C0E);
  static const Color surface = Color(0xFF121316);
  static const Color card = Color(0xFF17181C);
  static const Color elevated = Color(0xFF1E2024);
  static const Color border = Color(0xFF26272C);

  static const Color accent = Color(0xFFF6B60D);
  static const Color green = Color(0xFF2FC55C);
  static const Color red = Color(0xFFF65164);

  static const Color text = Color(0xFFF2F3F5);
  static const Color textDim = Color(0xFF98A1A9);
  static const Color textFaint = Color(0xFF62686F);

  static Color gain(bool isUp) => isUp ? green : red;
}

class AppText {
  AppText._();

  static const TextStyle display = TextStyle(
    fontSize: 34,
    height: 1.15,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
    letterSpacing: -0.8,
  );

  static const TextStyle priceLg = TextStyle(
    fontSize: 32,
    height: 1.1,
    fontWeight: FontWeight.w800,
    color: AppColors.text,
    letterSpacing: -0.6,
  );

  static const TextStyle priceMd = TextStyle(
    fontSize: 17,
    height: 1.2,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );

  static const TextStyle title = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textDim,
    height: 1.45,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textDim,
  );

  static const TextStyle micro = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textFaint,
  );
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: Colors.black,
      surface: AppColors.bg,
      error: AppColors.red,
    ),
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 16.5,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
      ),
      iconTheme: IconThemeData(color: AppColors.text),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.bg,
      selectedItemColor: AppColors.accent,
      unselectedItemColor: AppColors.textFaint,
      selectedFontSize: 12,
      unselectedFontSize: 12,
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.elevated,
      contentTextStyle: const TextStyle(color: AppColors.text),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.bg,
      modalBackgroundColor: AppColors.bg,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
    ),
  );
}
