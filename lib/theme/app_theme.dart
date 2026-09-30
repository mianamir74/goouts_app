import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        secondaryContainer: AppColors.secondaryContainer,
        tertiary: AppColors.tertiary,
        onTertiary: AppColors.onTertiary,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        error: AppColors.error,
        onError: AppColors.onError,
        outline: AppColors.outline,
        // ColorScheme.background / onBackground are deprecated — Material 3
        // merged them into surface / onSurface (both already set above).
        // scaffoldBackgroundColor below still applies AppColors.background,
        // so the app's actual page colour is unchanged.
      ),
      textTheme: GoogleFonts.interTextTheme(),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.onSurface,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      // ⚠ READ THIS BEFORE ADDING A NEW TextField/InputDecoration ANYWHERE
      // IN THE APP, found + fixed 9 September 2026. This theme applies a
      // 2px blue `focusedBorder` to every text field app-wide — good for a
      // real form field (login, signup, amounts), but a genuine bug for a
      // custom-styled field embedded in its OWN container (a search pill,
      // a chat input, an inline "write a review" box): those fields set
      // `border: InputBorder.none` expecting NO border ever, but
      // `focusedBorder` is a SEPARATE field in InputDecoration — Flutter
      // does not infer "focusedBorder: none" from "border: none". Left
      // unset, it falls back to THIS theme's blue border, which then
      // renders on top of the field's own container the moment it's
      // tapped, looking like a second box had appeared out of nowhere.
      //
      // 21 fields across 15 files had exactly this bug (reported as e.g.
      // "when I input text it shows another box"). Fixed by giving each of
      // them enabledBorder/focusedBorder/errorBorder/disabledBorder/
      // focusedErrorBorder: InputBorder.none alongside their `border:
      // InputBorder.none` — not by changing this theme, since real form
      // fields elsewhere DO want this blue focus ring and have no border
      // of their own to lose it against.
      //
      // ⚠ IF YOU ADD A NEW TextField inside its own custom-decorated
      // Container (search bar, chat box, anything not a plain form field):
      // set ALL FIVE border properties to InputBorder.none, not just
      // `border`. One is not enough.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
