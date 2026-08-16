// The one amenity catalogue.
//
// ── WHY THIS FILE EXISTS ─────────────────────────────────────────────────
//
// 16 August 2026, found while wiring the listing detail screen (task #116).
//
// A host picks amenities on host_05_create_listing_amenities_screen and the
// app stores SLUGS — 'kitchen', 'free_parking', 'hair_dryer'.
//
// The consumer search filter sheet had its own private list and stored
// LABELS — 'Kitchen', 'Free parking', 'Hair dryer' — then queried Firestore
// with arrayContainsAny against a field holding slugs.
//
//     stored:   ['kitchen', 'wifi', 'washer']
//     queried:  ['Kitchen', 'Fast WiFi']
//     matches:  none, ever
//
// Filtering by amenity could not return a single property and never could
// have. Nothing errored, so nothing said so — the results list simply came
// back empty and looked like "no properties match", which is a believable
// thing for a search to say.
//
// This is the same shape as kycStatus/status and unreadByUser/unreadByDriver:
// two halves of one feature, each with its own private copy of what a name is,
// written weeks apart by whoever was in that file at the time. The fix is not
// to correct the strings in the filter sheet — that leaves two lists that must
// be kept in step by memory. It is to have ONE list.
//
// ── THE SLUGS ARE NOT NEGOTIABLE ─────────────────────────────────────────
//
// They mirror host_05_create_listing_amenities_screen.dart in goouts_host,
// which is the WRITER. Live listings already hold these exact strings. Change
// a slug here and you silently orphan every property that used it — it will
// stop matching the filter and stop rendering its own icon.
//
// Labels and icons are display only and safe to change. Slugs are data.
//
// If an amenity is added host-side, add it here with the same slug. If one
// arrives that this file has never heard of, the screens fall back to the raw
// slug and a generic icon rather than dropping it, so an unknown amenity is
// visible rather than invisible.
library;

import 'package:flutter/material.dart';

/// One amenity as the app displays it. The [slug] is what Firestore holds.
class StayAmenity {
  final String slug;
  final String label;
  final IconData icon;
  const StayAmenity(this.slug, this.label, this.icon);
}

/// Group heading -> amenities, in display order.
///
/// Mirrors the host wizard exactly, including the order within each group and
/// Safety being kept as its own heading.
const Map<String, List<StayAmenity>> stayAmenityGroups =
    <String, List<StayAmenity>>{
  'Popular': <StayAmenity>[
    StayAmenity('wifi', 'Wifi', Icons.wifi),
    StayAmenity('heating', 'Heating', Icons.thermostat),
    StayAmenity('kitchen', 'Kitchen', Icons.kitchen),
    StayAmenity('washer', 'Washing machine', Icons.local_laundry_service),
    StayAmenity('free_parking', 'Free parking on premises', Icons.local_parking),
    StayAmenity('tv', 'TV', Icons.tv),
  ],
  'Kitchen and dining': <StayAmenity>[
    StayAmenity('cooking_basics', 'Cooking basics', Icons.soup_kitchen),
    StayAmenity('refrigerator', 'Refrigerator', Icons.kitchen_outlined),
    StayAmenity('microwave', 'Microwave', Icons.microwave),
    StayAmenity('dishwasher', 'Dishwasher', Icons.countertops),
    StayAmenity('oven', 'Oven', Icons.local_fire_department),
    StayAmenity('kettle', 'Kettle', Icons.coffee),
  ],
  'Bathroom and laundry': <StayAmenity>[
    StayAmenity('bathtub', 'Bath', Icons.bathtub),
    StayAmenity('shower', 'Shower', Icons.shower),
    StayAmenity('hair_dryer', 'Hair dryer', Icons.air),
    StayAmenity('shampoo', 'Shampoo', Icons.sanitizer),
    StayAmenity('towels', 'Towels provided', Icons.dry_cleaning),
    StayAmenity('iron', 'Iron', Icons.iron),
    StayAmenity('hangers', 'Hangers', Icons.checkroom),
  ],
  'Comfort and work': <StayAmenity>[
    StayAmenity('air_conditioning', 'Air conditioning', Icons.ac_unit),
    StayAmenity('workspace', 'Dedicated workspace', Icons.desktop_windows),
    StayAmenity('indoor_fireplace', 'Indoor fireplace', Icons.fireplace),
    StayAmenity('books', 'Books and reading material', Icons.menu_book),
  ],
  'Outdoor and access': <StayAmenity>[
    StayAmenity('garden', 'Garden or yard', Icons.grass),
    StayAmenity('patio_balcony', 'Patio or balcony', Icons.deck),
    StayAmenity('lift', 'Lift', Icons.elevator),
    StayAmenity('step_free', 'Step-free access', Icons.accessible),
  ],
  'Family': <StayAmenity>[
    StayAmenity('cot', 'Cot', Icons.crib),
    StayAmenity('high_chair', 'High chair', Icons.chair_alt),
    StayAmenity('travel_bed', 'Travel bed', Icons.bed),
  ],
  'Safety': <StayAmenity>[
    // Icons.sensors, NOT Icons.detector_smoke.
    //
    // detector_smoke exists in Material Symbols, Google's newer icon set, and
    // was never added to Flutter's Icons class. It reads as though it should
    // be there, which is exactly why it got used — and it is a compile error,
    // not a missing glyph, so the app would not build at all.
    StayAmenity('smoke_alarm', 'Smoke alarm', Icons.sensors),
    StayAmenity('carbon_monoxide_alarm', 'Carbon monoxide alarm', Icons.co2),
    StayAmenity('fire_extinguisher', 'Fire extinguisher', Icons.fire_extinguisher),
    StayAmenity('first_aid_kit', 'First aid kit', Icons.medical_services),
  ],
};

/// Flat list, group order preserved. Used for counts and lookups.
final List<StayAmenity> stayAmenitiesAll = <StayAmenity>[
  for (final group in stayAmenityGroups.values) ...group,
];

final Map<String, StayAmenity> _bySlug = <String, StayAmenity>{
  for (final a in stayAmenitiesAll) a.slug: a,
};

/// How many amenities the catalogue knows about. Drives "Show all N amenities"
/// so the number cannot drift from the list the button opens.
int get stayAmenityCount => stayAmenitiesAll.length;

/// Looks up an amenity by slug.
///
/// Returns a usable entry for a slug this build has never seen rather than
/// null: the slug is shown with underscores turned into spaces and a generic
/// icon. An amenity added host-side before a consumer release therefore
/// appears as unstyled-but-present instead of vanishing.
StayAmenity stayAmenityFor(String slug) =>
    _bySlug[slug] ??
    StayAmenity(slug, _humanise(slug), Icons.check_circle_outline);

String _humanise(String slug) {
  if (slug.isEmpty) return slug;
  final String spaced = slug.replaceAll('_', ' ');
  return spaced[0].toUpperCase() + spaced.substring(1);
}
