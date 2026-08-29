import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  THE STITCH TYPE SCALE AND SPACING SCALE. ONE DEFINITION.
//
//  Written 27 August 2026, after: "there is lot of big fonts sizes used as
//  headings and some ui is changed".
//
//  ── ⚠ WHY THE SCREENS STOPPED LOOKING LIKE THE DESIGN ───────────────────────
//
//  Stitch did not hand us loose font sizes. It handed us a NAMED SCALE, declared
//  identically in the Tailwind config of 28 of the 29 screens:
//
//      screen-title     20px / 700 / 28  line-height
//      section-header   15px / 700 / 20  (+0.02em letter-spacing)
//      card-title       14px / 600 / 20
//      body           13.5px / 400 / 20
//      caption          12px / 500 / 16
//      button-text      16px / 600 / 24
//
//  SIX styles. The largest is 20px. THE HEAVIEST WEIGHT IN THE ENTIRE DESIGN
//  SYSTEM IS 700 — font-extrabold appears nowhere, on any of the 29 screens.
//
//  What we actually built, measured across the same 29 screens:
//
//      23 DIFFERENT FONT SIZES, from 10px to 32px
//      FontWeight.w800 used 19 times — a weight the design does not contain
//      headings at 17, 18, 19, 22, 24, 25, 28, 30 and 32px, where the design's
//        largest text of any kind is 20px
//
//  That is the whole complaint. Nothing is broken and no colour is wrong; the
//  type is simply louder and larger than it was drawn, and a scale with 23 sizes
//  in it is not a scale. Screens drift apart because each one picks its own
//  "slightly bigger" heading, and the set stops looking designed.
//
//  ── ⚠ USE THESE. DO NOT PASS fontSize: TO GoogleFonts.inter IN THIS FEATURE. ─
//
//  If a screen needs a size that is not one of the six, the answer is almost
//  always that it needs one of the six. The exceptions that genuinely exist —
//  a price, a countdown, an empty-state icon caption — are named below so they
//  are decisions rather than accidents.
//
//  Colour is deliberately NOT baked in. The palette stayed GoOuts (#0392CA and
//  #F2F4F7) by decision on 27 August: "design of UI we need to use Stitch one
//  but built in color is fine". So every style here takes its colour from the
//  call site via .on(...), and this file never contradicts stay_colors.dart.
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class StayType {
  const StayType._();

  /// 20 / 700. App bar titles and the one true heading on a screen.
  ///
  /// ⚠ THIS IS THE LARGEST TEXT IN THE PRODUCT. If something needs to be bigger
  /// than this, it wants more weight, more space around it, or colour — not
  /// more points. That is the rule the Stitch screens follow throughout.
  static TextStyle get screenTitle => GoogleFonts.inter(
        fontSize: 20,
        height: 28 / 20,
        fontWeight: FontWeight.w700,
      );

  /// 15 / 700 / +0.02em. "Most GoOuts partners nearby", "Weekend breaks".
  ///
  /// Deliberately only 1px larger than card-title. Stitch separates a section
  /// header from the cards under it with WEIGHT, LETTER-SPACING AND THE 20px
  /// section gap — not with size. Ours were 17px w800, which is why the page
  /// read as a stack of shouted headings.
  static TextStyle get sectionHeader => GoogleFonts.inter(
        fontSize: 15,
        height: 20 / 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3, // 0.02em at 15px
      );

  /// 14 / 600. The title inside any card.
  static TextStyle get cardTitle => GoogleFonts.inter(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w600,
      );

  /// 13.5 / 400. Ordinary running text. The default for anything unlabelled.
  static TextStyle get body => GoogleFonts.inter(
        fontSize: 13.5,
        height: 20 / 13.5,
        fontWeight: FontWeight.w400,
      );

  /// 12 / 500. Chips, badges, timestamps, helper lines under a field.
  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w500,
      );

  /// 16 / 600. Text inside a button, at StaySpacing.buttonHeight.
  static TextStyle get buttonText => GoogleFonts.inter(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w600,
      );

  // ── The two named exceptions. ───────────────────────────────────────────────
  //
  // Both are card-title's size and line-height, so they sit on the same
  // baseline grid as everything else. Neither introduces a new size.

  /// A price. card-title at 700 so "£85" out-weighs the words beside it without
  /// out-SIZING them. Pair with [priceUnit] for the "/ night" part.
  static TextStyle get price => GoogleFonts.inter(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w700,
      );

  /// The unit after a price — "nightly", "/ night", "total". Body weight at
  /// card-title size so the two align on one line.
  static TextStyle get priceUnit => GoogleFonts.inter(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w400,
      );
}

/// Colour is applied at the call site, never baked into the scale.
///
///     Text('Weekend breaks', style: StayType.sectionHeader.on(GoOutsColors.deepNavy))
extension StayTypeColour on TextStyle {
  TextStyle on(Color c) => copyWith(color: c);

  /// For the rare case where a single word inside a styled run needs a
  /// different weight — a bold number in a body sentence, for example.
  TextStyle get semibold => copyWith(fontWeight: FontWeight.w600);
  TextStyle get bold => copyWith(fontWeight: FontWeight.w700);
}

/// ─────────────────────────────────────────────────────────────────────────────
///  THE STITCH SPACING SCALE. Five values, declared in 28 of the 29 screens.
///
///  ⚠ THESE ARE NOT SUGGESTIONS. The reason the Stitch screens feel even and
///  ours do not is that ours use 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 28 and 32
///  interchangeably, chosen per widget. Five values, used consistently, is what
///  produces a rhythm.
/// ─────────────────────────────────────────────────────────────────────────────
@immutable
class StaySpacing {
  const StaySpacing._();

  /// 16. The left and right margin of every screen, without exception.
  static const double page = 16;

  /// 20. Vertical gap BETWEEN sections.
  static const double section = 20;

  /// 8. Gap between sibling cards in a row or list.
  static const double card = 8;

  /// 12. Padding INSIDE a card, chip or field.
  static const double inline = 12;

  /// 52. Every primary button. Not 48, not 50.
  static const double buttonHeight = 52;

  // Convenience so screens do not hand-roll EdgeInsets and drift again.
  static const EdgeInsets pageH = EdgeInsets.symmetric(horizontal: page);
  static const EdgeInsets cardPad = EdgeInsets.all(inline);
  static const SizedBox gapCard = SizedBox(height: card, width: card);
  static const SizedBox gapSection = SizedBox(height: section);
}
