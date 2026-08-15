import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GoOuts Short Stay palette. ONE definition.
//
// Consolidated 3 August 2026. Stitch declared a separate `GoOutsColors` class
// inside 25 of the 29 generated screens, using 43 distinct names, and SIX of
// those names carried different values in different files.
//
// THE DRIFT THAT MATTERED MOST
//   primaryBlue     0xFF0392CA in 15 files, 0xFF00628A in 10.  The brand blue
//                   itself was wrong on a third of the screens.
//   deepNavy        0xFF0D1B3E in 7 files, 0xFF0D1C2E in 18.
//   bodyText        0xFF475569 in 15 files, 0xFF3E484F in 8.
//   pageBackground  0xFFF2F4F7 in 6 files, 0xFFF8F9FF in 1.
//
// In every case THE SPECIFIED VALUE WINS, even where the drifted one was more
// common, because the specified palette is what the rest of goouts_app uses.
// A Short Stay screen must not be a slightly different blue from the wallet.
//
// Aliases below exist so the generated screens still compile. They point at the
// canonical value rather than reintroducing a second shade.
// ─────────────────────────────────────────────────────────────────────────────
class GoOutsColors {
  GoOutsColors._();

  // ── The specified palette. These are the source of truth. ─────────────────
  static const Color primaryBlue    = Color(0xFF0392CA);
  static const Color deepNavy       = Color(0xFF0D1B3E);
  static const Color tealSecondary  = Color(0xFF0A6E8A);
  static const Color pageBackground = Color(0xFFF2F4F7);
  static const Color cardSurface    = Color(0xFFFFFFFF);
  static const Color paleBlueTint   = Color(0xFFE0F3FB);
  static const Color bodyText       = Color(0xFF475569);
  static const Color success        = Color(0xFF16A34A);
  static const Color warning        = Color(0xFFF59E0B);
  static const Color error          = Color(0xFFEF4444);

  // ── Aliases. Normalised to the canonical values above. ────────────────────
  static const Color background     = pageBackground;   // was 0xFFF8F9FF
  static const Color surface        = cardSurface;      // was 0xFFF8F9FF in 3
  static const Color onPrimary      = cardSurface;
  static const Color successGreen   = success;
  static const Color pendingOrange  = warning;
  static const Color iconBlue       = primaryBlue;
  static const Color infoBlue       = primaryBlue;
  static const Color tickTeal       = tealSecondary;
  static const Color cashbackBlue   = paleBlueTint;
  static const Color textVariant    = bodyText;         // was 0xFF3E484F

  // ── Genuinely distinct shades Stitch introduced. Kept, and named. ─────────
  static const Color brandDark        = Color(0xFF00628A);
  static const Color contestBlue      = brandDark;
  static const Color partnerTeal      = Color(0xFF006782);
  static const Color acceptBlue       = Color(0xFFA5E1FF);
  static const Color choiceBlue       = Color(0xFF92DFFF);
  static const Color lightBlueBg      = Color(0xFFBAE7FF);
  static const Color surfaceBlue      = Color(0xFFE6EEFF);
  static const Color surfaceContainer = surfaceBlue;
  static const Color infoBlueBg       = Color(0xFFEFF6FF);
  static const Color dividerGray      = Color(0xFFF2F4F7);
  static const Color outlineVariant   = Color(0xFFBEC8D0);
  static const Color starGray         = Color(0xFFCBD5E1);
  static const Color cardShadow       = Color(0x0A000000);

  // Event category chips, screen 10
  static const Color musicBlue      = Color(0xFFE0F2FE);
  static const Color musicText      = Color(0xFF0369A1);
  static const Color sportsGreen    = Color(0xFFDCFCE7);
  static const Color sportsText     = Color(0xFF15803D);
  static const Color businessPurple = Color(0xFFF3E8FF);
  static const Color businessText   = Color(0xFF7E22CE);

  // Claim countdown, screen 23
  static const Color timerPurpleBg   = Color(0xFFEEF2FF);
  static const Color timerPurpleText = Color(0xFF4F46E5);

  // Destructive states, screen 28
  static const Color errorRed        = Color(0xFFBA1A1A);
  static const Color errorContainer  = Color(0xFFFFDAD6);
  static const Color onErrorContainer= Color(0xFF410002);
}
