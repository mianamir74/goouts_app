import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  The Food Delivery bottom navigation. ONE definition.
//
//  Written 31 August 2026, reported as "none of the food delivery screens have
//  bottom buttons". They did not — not a broken one, not a decorative one. All
//  five had no bar at all.
//
//  ── ⚠ THIS IS THE SAME REPORT AS SHORT STAY, THREE DAYS LATER ───────────────
//
//  On 28 August the same thing was reported about Short Stay, and the cause
//  there was that Stitch drew a bar on nineteen screens, four of them had it
//  with zero handlers, three had deleted it as dead decoration, and one had a
//  real one nothing else shared. StayBottomNav fixed it by having one.
//
//  Food Delivery never got that pass. So a customer browsing restaurants had
//  no way to reach their orders except the back arrow, and after placing an
//  order the only route back to the restaurant list was backing out through
//  the tracking screen.
//
//  ⚠ THIS FILE IS DELIBERATELY A SIBLING OF StayBottomNav, NOT A SHARED ONE.
//  The two verticals have different destinations — Search and Trips against
//  Restaurants and Orders — and a single widget taking a list of tabs would be
//  a configuration object pretending to be a component. If a third vertical
//  needs one, that is the point to extract the common shape, not before.
//
//  ── ⚠ WHY A PUSHED SCREEN CANNOT JUST pushNamed ─────────────────────────────
//
//  This bar appears on screens three or four deep: menu, checkout, tracking. A
//  plain push would stack ANOTHER restaurant list on top of the order you were
//  watching, and back would walk you down through every copy.
//
//  Tabs do not stack. Restaurants and Orders therefore reset to the app root
//  and push once, which is what a tab bar does everywhere else on a phone.
//
//  ⚠ AND TAPPING THE TAB YOU ARE ALREADY ON DOES NOTHING. Without that guard a
//  customer on Orders who taps Orders gets a second copy pushed over the
//  first, which looks exactly like the app freezing.
// ─────────────────────────────────────────────────────────────────────────────

enum FoodTab { restaurants, orders, rewards, profile }

class FoodBottomNav extends StatelessWidget {
  const FoodBottomNav({super.key, required this.current});

  /// Which tab this screen belongs to.
  ///
  /// ⚠ SCREENS THAT ARE NOT ANY OF THEM SHOULD NOT SHOW THIS BAR. Checkout is
  /// the case that matters: somebody paying should be finishing or backing
  /// out deliberately, not wandering off to a restaurant list with a full
  /// basket behind them.
  final FoodTab current;

  static const Color _muted = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: <Widget>[
              _item(context, FoodTab.restaurants,
                  Icons.restaurant_menu_rounded, 'Restaurants'),
              _item(context, FoodTab.orders, Icons.receipt_long_outlined,
                  'Orders'),
              _item(context, FoodTab.rewards,
                  Icons.workspace_premium_outlined, 'Rewards'),
              _item(context, FoodTab.profile, Icons.person_outline, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(
      BuildContext context, FoodTab tab, IconData icon, String label) {
    final bool active = tab == current;
    final Color c = active ? AppColors.primary : _muted;

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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11,
                height: 14 / 11,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: c,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _go(BuildContext context, FoodTab tab) {
    final NavigatorState nav = Navigator.of(context);

    switch (tab) {
      // ⚠ removeUntil isFirst, NOT pushNamed. See the header. This drops every
      // food screen above the app root and puts one destination on top, so the
      // stack cannot grow every time somebody taps a tab.
      case FoodTab.restaurants:
        nav.pushNamedAndRemoveUntil('/food-delivery', (r) => r.isFirst);
      case FoodTab.orders:
        nav.pushNamedAndRemoveUntil('/food-order-history', (r) => r.isFirst);

      // These two live in the main app rather than in Food Delivery, so they
      // are pushed normally and the customer can come back to where they were.
      case FoodTab.rewards:
        nav.pushNamed('/wallet');
      case FoodTab.profile:
        nav.pushNamed('/profile');
    }
  }
}
