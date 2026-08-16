// The one property-type catalogue.
//
// ── WHY THIS FILE EXISTS ─────────────────────────────────────────────────
//
// 16 August 2026, found in the same sweep as models/stay_amenities.dart and
// caused by the same thing: two halves of one feature, each holding its own
// private idea of what a value is called.
//
// The host wizard stores SLUGS:
//
//     flat, house, annexe, room, cottage, other
//
// The consumer search filter offered LABELS, and queried Firestore with them:
//
//     q.where('propertyType', isEqualTo: 'Apartment')
//
// That is a server-side equality filter, so the result was a hard zero. Every
// property type in the filter returned nothing:
//
//     'Apartment'  no such value — hosts store 'flat'
//     'House'      case mismatch — hosts store 'house'
//     'Room'       case mismatch — hosts store 'room'
//     'Hotel'      no such value — the host wizard cannot produce it
//
// Two of the four could never have matched even with the case corrected,
// because nothing in the product creates them. Meanwhile 'annexe' and
// 'cottage' — which hosts DO create — could not be filtered for at all.
//
// ── THE SLUGS ARE NOT NEGOTIABLE ─────────────────────────────────────────
//
// They mirror host_04_create_listing_property_details_screen.dart in
// goouts_host, which is the WRITER, and live listings already hold them.
// Labels are display only. Slugs are data.
library;

/// Stored slug -> what a guest reads. Order is the order shown in filters.
///
/// Kept identical to the host wizard, including 'other', which a filter needs
/// as much as the wizard does — a property stored as 'other' would otherwise
/// be unreachable by anyone filtering at all.
const Map<String, String> stayPropertyTypes = <String, String>{
  'flat': 'Flat or apartment',
  'house': 'House',
  'annexe': 'Annexe or outbuilding',
  'room': 'Private room',
  'cottage': 'Cottage',
  'other': 'Something else',
};

/// Label for a stored slug.
///
/// Falls back to the slug itself rather than an empty string, so a type added
/// host-side before a consumer release shows as unstyled-but-present instead
/// of a blank line on the listing page.
String stayPropertyTypeLabel(String slug) {
  if (slug.isEmpty) return 'Property';
  final String? known = stayPropertyTypes[slug];
  if (known != null) return known;
  return slug[0].toUpperCase() + slug.substring(1).replaceAll('_', ' ');
}
