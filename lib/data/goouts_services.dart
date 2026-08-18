// The one list of what GoOuts offers.
//
// ── WHY THIS FILE EXISTS ─────────────────────────────────────────────────
//
// 17 August 2026, reported as "Explore has no Short Stay or Food Delivery
// icon, they only show in Services".
//
// The cause was three hardcoded lists, each with its own idea of what the
// product is:
//
//   home_screen._services        7 items. No Short Stay. No Food Delivery.
//   services_screen._allServices 9 items. Food Delivery yes, Short Stay no
//                                (it had a separate hero card instead).
//   explore_screen._categories   built from partner `category` fields, so
//                                neither could ever appear.
//
// Three answers to "what does GoOuts sell", and the two things GoOuts sells
// that a competitor does not were missing from most of them. Adding the icons
// to Explore alone would have made it four.
//
// This is the same shape as kycStatus/status and the amenity slugs, one level
// up: one fact, several copies, only some maintained.
//
// ── THE RULE ─────────────────────────────────────────────────────────────
//
// A screen that lists what GoOuts offers reads THIS. It does not keep its own
// list. Adding a service means editing this file and nothing else.
library;

import 'package:flutter/material.dart';

import '../features/short_stay/stay_routes.dart';

/// One thing a guest can tap on any "what we offer" strip.
class GoOutsService {
  final IconData icon;
  final String label;

  /// Where it goes.
  ///
  /// A GoOuts SERVICE has its own screen and carries [nav] — Short Stay and
  /// Food Delivery are products we run, not types of venue.
  ///
  /// A partner CATEGORY carries [category] instead and opens /nearby filtered
  /// to it. Exactly one of the two is set.
  final String? nav;
  final String? category;

  final bool isNew;
  final Color color;

  const GoOutsService({
    required this.icon,
    required this.label,
    required this.color,
    this.nav,
    this.category,
    this.isNew = false,
  });

  /// True for the things GoOuts runs itself, as opposed to venue types.
  bool get isOwnService => nav != null;
}

/// The two products GoOuts runs. Shown FIRST everywhere.
///
/// Deliberately ahead of the venue categories: these are the reasons someone
/// picks GoOuts over a map app, and burying them behind Cafes and Pubs is the
/// wrong way round.
///
/// Routes match what services_screen has always used, so there is one answer
/// to "where does Short Stay live" rather than two that drift.
const List<GoOutsService> gooutsOwnServices = <GoOutsService>[
  GoOutsService(
    icon: Icons.night_shelter_rounded,
    label: 'Short Stay',
    nav: StayRoutes.home,
    color: Color(0xFF3B1D5E),
    isNew: true,
  ),
  GoOutsService(
    icon: Icons.delivery_dining_rounded,
    label: 'Food Delivery',
    nav: '/food-delivery',
    color: Color(0xFF7A2E12),
    isNew: true,
  ),
];

/// Partner venue types. These open /nearby filtered to the category.
///
/// The category strings must match the `category` field on partner documents
/// — they are a query value, not a label. Change the display name freely;
/// changing the category orphans every partner filed under the old one.
const List<GoOutsService> gooutsPartnerCategories = <GoOutsService>[
  GoOutsService(
    icon: Icons.coffee_rounded,
    label: 'Cafes',
    category: 'Cafes',
    color: Color(0xFF5C3D1E),
  ),
  GoOutsService(
    icon: Icons.restaurant_rounded,
    label: 'Restaurants',
    category: 'Restaurants',
    color: Color(0xFF3B1F0A),
  ),
  GoOutsService(
    icon: Icons.sports_bar_rounded,
    label: 'Pubs',
    category: 'Pubs',
    color: Color(0xFF1A3A1A),
  ),
  GoOutsService(
    icon: Icons.nightlife_rounded,
    label: 'Clubs',
    category: 'Clubs',
    color: Color(0xFF1A0533),
  ),
  GoOutsService(
    icon: Icons.fastfood_rounded,
    label: 'Fast Food',
    category: 'Fast Food',
    color: Color(0xFF0A2A4A),
  ),
  GoOutsService(
    icon: Icons.music_note_rounded,
    label: 'Music',
    category: 'Music',
    color: Color(0xFF0D3B2E),
  ),
  GoOutsService(
    icon: Icons.theater_comedy_rounded,
    label: 'Comedy',
    category: 'Comedy',
    color: Color(0xFF2C1A08),
  ),
  GoOutsService(
    icon: Icons.local_bar_rounded,
    label: 'Bars',
    category: 'Bars',
    color: Color(0xFF0A3A4A),
  ),
];

/// Everything, services first. What most strips want.
const List<GoOutsService> gooutsAllServices = <GoOutsService>[
  ...gooutsOwnServices,
  ...gooutsPartnerCategories,
];

/// Pushes a service, whichever kind it is.
///
/// Kept here so no screen has to remember that a category needs an argument
/// and a service does not. Getting that wrong sends a guest to an empty
/// /nearby instead of Short Stay.
void openGoOutsService(BuildContext context, GoOutsService s) {
  if (s.nav != null) {
    Navigator.pushNamed(context, s.nav!);
    return;
  }
  Navigator.pushNamed(
    context,
    '/nearby',
    arguments: <String, dynamic>{'category': s.category},
  );
}
