import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../stay_routes.dart';
import '../theme/stay_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  The Short Stay bottom navigation. ONE definition.
//
//  Written 28 August 2026, reported as "there is no bottom bars in the short
//  stay pages these are missing".
//
//  ── ⚠ IT WAS THERE, AND IT DID NOTHING ──────────────────────────────────────
//
//  Stitch draws this bar on 19 of the 29 guest screens. Before today the app
//  was in three different states at once:
//
//    · screens 09, 10, 17 and 25 had a bar with ZERO handlers. Four labels
//      painted on the screen that could not be pressed.
//    · screens 14, 15 and 26 had theirs DELETED, with comments explaining it
//      was "four dead labels on a pushed screen". That was the correct call
//      against a fake bar, and it left those screens without one at all.
//    · screen 01 had a real one, written by hand, that nothing else shared.
//
//  So the honest summary is not that the bar was missing. It is that it was
//  decoration nearly everywhere it appeared, and the two screens that noticed
//  removed it instead of fixing it.
//
//  ── ⚠ WHY A PUSHED SCREEN CANNOT JUST pushNamed ─────────────────────────────
//
//  This bar appears on screens that are four or five deep in the stack. A
//  plain push would stack ANOTHER Short Stay home on top of the trip you were
//  looking at, and the back button would walk you down through every copy.
//
//  Tabs do not stack. Search and Trips therefore reset to the app root and push
//  once, which is what a tab bar does everywhere else on a phone.
//
//  ⚠ AND TAPPING THE TAB YOU ARE ALREADY ON DOES NOTHING. Without that guard,
//  a guest on My Bookings who taps Trips gets a second My Bookings pushed over
//  the first, which looks like the app froze.
// ─────────────────────────────────────────────────────────────────────────────

enum StayTab { search, trips, rewards, profile }

class StayBottomNav extends StatelessWidget {
  const StayBottomNav({super.key, required this.current});

  /// Which tab this screen belongs to. Screens that are not any of them, such
  /// as the capture flow, should not show this bar at all.
  final StayTab current;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: GoOutsColors.cardSurface,
        border: Border(
          top: BorderSide(color: GoOutsColors.outlineVariant, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: <Widget>[
              _item(context, StayTab.search, Icons.search, 'Search'),
              _item(context, StayTab.trips, Icons.luggage_outlined, 'Trips'),
              _item(context, StayTab.rewards,
                  Icons.workspace_premium_outlined, 'Rewards'),
              _item(context, StayTab.profile, Icons.person_outline, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(
      BuildContext context, StayTab tab, IconData icon, String label) {
    final bool active = tab == current;
    final Color c = active ? GoOutsColors.primaryBlue : GoOutsColors.bodyText;

    return Expanded(
      child: InkWell(
        // Already here. Doing nothing is the correct response.
        onTap: active ? null : () => _go(context, tab),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 22, color: c),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 16 / 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: c,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _go(BuildContext context, StayTab tab) {
    final NavigatorState nav = Navigator.of(context);

    switch (tab) {
      // ⚠ removeUntil isFirst, NOT pushNamed. See the header. This drops every
      // Short Stay screen above the app root and puts one destination on top,
      // so the stack cannot grow every time somebody taps a tab.
      case StayTab.search:
        nav.pushNamedAndRemoveUntil(StayRoutes.home, (r) => r.isFirst);
      case StayTab.trips:
        nav.pushNamedAndRemoveUntil(StayRoutes.myBookings, (r) => r.isFirst);

      // These two live in the main app rather than in Short Stay, so they are
      // pushed normally and the guest can come back to where they were.
      case StayTab.rewards:
        nav.pushNamed('/wallet');
      case StayTab.profile:
        nav.pushNamed('/profile');
    }
  }
}
