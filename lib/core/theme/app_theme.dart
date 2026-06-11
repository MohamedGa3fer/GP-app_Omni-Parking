import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_translations.dart';

class AppTheme {
  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.backgroundDark,
    cardColor: AppColors.surfaceDark,
    primaryColor: AppColors.primary,
    // Disable the Material tap "ink" (ripple + highlight) app-wide. It was
    // leaking past rounded containers as a gray sliver on press.
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    // Floating so a SnackBar doesn't shove the center-docked Car-Entry button up.
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    // Dialogs & sheets follow the theme's surface so they're not stuck dark.
    dialogTheme: const DialogThemeData(backgroundColor: AppColors.surfaceDark),
    bottomSheetTheme:
        const BottomSheetThemeData(backgroundColor: AppColors.surfaceDark),
    // Dropdown / popup menus follow the app surface + rounded card style
    // (transparent tint so M3 elevation doesn't shift the surface colour).
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surfaceDark,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 15),
    ),
    textTheme: GoogleFonts.plusJakartaSansTextTheme(
      ThemeData.dark().textTheme,
    ).apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        minimumSize: const Size(double.infinity, 56),
      ),
    ),
  );

  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.backgroundLight,
    cardColor: AppColors.surfaceLight,
    primaryColor: AppColors.primary,
    // Disable the Material tap "ink" (ripple + highlight) app-wide. It was
    // leaking past rounded containers as a gray sliver on press.
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    // Floating so a SnackBar doesn't shove the center-docked Car-Entry button up.
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    // Dialogs & sheets follow the theme's surface so they're not stuck dark.
    dialogTheme: const DialogThemeData(backgroundColor: AppColors.surfaceLight),
    bottomSheetTheme:
        const BottomSheetThemeData(backgroundColor: AppColors.surfaceLight),
    // Dropdown / popup menus follow the app surface + rounded card style
    // (transparent tint so M3 elevation doesn't shift the surface colour).
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surfaceLight,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: GoogleFonts.plusJakartaSans(
        color: AppColors.textPrimaryLight,
        fontSize: 15,
      ),
    ),
    textTheme: GoogleFonts.plusJakartaSansTextTheme(
      ThemeData.light().textTheme,
    ).apply(
      bodyColor: AppColors.textPrimaryLight,
      displayColor: AppColors.textPrimaryLight,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryPink,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        minimumSize: const Size(double.infinity, 56),
      ),
    ),
  );
}
