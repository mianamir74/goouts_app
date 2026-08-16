// What the guest has chosen, before a booking exists.
//
// ── WHY THIS IS AN OBJECT AND NOT SIX ROUTE ARGUMENTS ────────────────────
//
// Screens 11, 12 and 13 have to carry a listing id, two dates and three guest
// counts between them. Passed as six loose keys in a route arguments map,
// every one of them is a string lookup that fails silently — `id('checkIn')`
// on a missing key returns '' and the screen renders as though the guest
// chose nothing.
//
// stay_routes.dart already makes this distinction for search: StaySearchCriteria
// is passed as a real object because "search criteria are a value, not a
// database row, so there is nothing to look up". A pending selection is the
// same kind of thing. It has no id because it is not saved anywhere — it
// becomes a row only when createStayBooking succeeds, and from that point the
// screens carry a bookingId instead.
//
// ── NIGHTS, NOT DAYS ─────────────────────────────────────────────────────
//
// [nights] is checkOut minus checkIn. A guest arriving on the 12th and leaving
// on the 14th sleeps two nights, not three, and is charged for two. The
// checkout date is NOT a night and must never be counted or blocked as one —
// getting this wrong is how a calendar ends up refusing a booking that starts
// on the day another one ends.
library;

class StayBookingRequest {
  final String listingId;
  final DateTime checkIn;
  final DateTime checkOut;
  final int adults;
  final int children;
  final int infants;

  const StayBookingRequest({
    required this.listingId,
    required this.checkIn,
    required this.checkOut,
    this.adults = 2,
    this.children = 0,
    this.infants = 0,
  });

  int get nights => checkOut.difference(checkIn).inDays;

  /// Infants are deliberately excluded, matching the occupancy limit a host
  /// sets on the listing. A cot does not use a bed.
  int get countedGuests => adults + children;

  bool get isValid =>
      listingId.isNotEmpty && nights > 0 && adults >= 1;

  StayBookingRequest copyWith({
    DateTime? checkIn,
    DateTime? checkOut,
    int? adults,
    int? children,
    int? infants,
  }) =>
      StayBookingRequest(
        listingId: listingId,
        checkIn: checkIn ?? this.checkIn,
        checkOut: checkOut ?? this.checkOut,
        adults: adults ?? this.adults,
        children: children ?? this.children,
        infants: infants ?? this.infants,
      );

  /// "2 adults, 1 child" — the phrasing used on checkout and confirmation.
  String get guestSummary {
    final List<String> parts = <String>[
      '$adults ${adults == 1 ? 'adult' : 'adults'}',
      if (children > 0) '$children ${children == 1 ? 'child' : 'children'}',
      if (infants > 0) '$infants ${infants == 1 ? 'infant' : 'infants'}',
    ];
    return parts.join(', ');
  }
}
