import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/stay_listing.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Availability search.
//
// THE PROBLEM
// Firestore cannot answer "which listings are free between 12 and 15 August".
// There is no range containment query. The usual workarounds do not work:
//   * an array of booked dates with array-contains-any caps at 30 values, and
//     it finds listings that ARE booked, which is the wrong direction
//   * a nextAvailable field is meaningless for a range
//   * filtering everything client side is fine at 50 listings and fatal at 5000
//
// THE PLAN, three stages behind ONE method signature
//   Stage 1, now, under about 500 listings
//       Filter in Firestore on what it is good at, then check availability in
//       a Cloud Function over that bounded set, reading one blocked_dates
//       month document per listing.
//   Stage 2, a few thousand listings
//       An inverted index, stay_availability/{yyyy_mm_dd}, holding the ids
//       free that night. Intersect across the range.
//   Stage 3
//       A real search service.
//
// Because every caller goes through `search` below, stages 2 and 3 are an
// implementation swap inside the Cloud Function and NOT a rewrite of the app.
// Do not add a second entry point.
// ─────────────────────────────────────────────────────────────────────────────

enum StaySort {
  journeyTime('journey_time'),
  priceLowHigh('price_asc'),
  priceHighLow('price_desc'),
  partnersNearby('partners_desc'),
  rating('rating_desc');

  final String wire;
  const StaySort(this.wire);

  /// Journey time is first deliberately. In a city, miles mislead: two places
  /// can be the same distance away and be a completely different day out.
  String get label => switch (this) {
        StaySort.journeyTime => 'Journey time to centre',
        StaySort.priceLowHigh => 'Price, lowest first',
        StaySort.priceHighLow => 'Price, highest first',
        StaySort.partnersNearby => 'Most GoOuts partners nearby',
        StaySort.rating => 'Rating',
      };
}

class StaySearchCriteria {
  final String? town;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final int guests;
  final int? minPricePence;
  final int? maxPricePence;
  final int? minBedrooms;
  final int minPartnersHalfMile;
  final List<String> amenities;
  final String? propertyType;
  final StaySort sort;

  const StaySearchCriteria({
    this.town,
    this.checkIn,
    this.checkOut,
    this.guests = 1,
    this.minPricePence,
    this.maxPricePence,
    this.minBedrooms,
    this.minPartnersHalfMile = 0,
    this.amenities = const [],
    this.propertyType,
    this.sort = StaySort.journeyTime,
  });

  StaySearchCriteria copyWith({
    String? town,
    DateTime? checkIn,
    DateTime? checkOut,
    int? guests,
    int? minPricePence,
    int? maxPricePence,
    int? minBedrooms,
    int? minPartnersHalfMile,
    List<String>? amenities,
    String? propertyType,
    StaySort? sort,
  }) =>
      StaySearchCriteria(
        town: town ?? this.town,
        checkIn: checkIn ?? this.checkIn,
        checkOut: checkOut ?? this.checkOut,
        guests: guests ?? this.guests,
        minPricePence: minPricePence ?? this.minPricePence,
        maxPricePence: maxPricePence ?? this.maxPricePence,
        minBedrooms: minBedrooms ?? this.minBedrooms,
        minPartnersHalfMile: minPartnersHalfMile ?? this.minPartnersHalfMile,
        amenities: amenities ?? this.amenities,
        propertyType: propertyType ?? this.propertyType,
        sort: sort ?? this.sort,
      );

  Map<String, dynamic> toWire() => {
        if (town != null) 'town': town,
        if (checkIn != null) 'checkIn': checkIn!.toIso8601String(),
        if (checkOut != null) 'checkOut': checkOut!.toIso8601String(),
        'guests': guests,
        if (minPricePence != null) 'minPrice': minPricePence,
        if (maxPricePence != null) 'maxPrice': maxPricePence,
        if (minBedrooms != null) 'minBedrooms': minBedrooms,
        if (minPartnersHalfMile > 0) 'minPartners': minPartnersHalfMile,
        if (amenities.isNotEmpty) 'amenities': amenities,
        if (propertyType != null) 'propertyType': propertyType,
        'sort': sort.wire,
      };

  bool get hasDates => checkIn != null && checkOut != null;
}

class StaySearchPage {
  final List<StayListing> listings;
  final String? nextCursor;
  final int totalApprox;

  /// Whether the check in and check out dates were actually applied.
  ///
  /// FALSE in stage 1, because Firestore cannot answer "free between these two
  /// dates" — see StayAvailabilityService.search. The results screen must SAY
  /// SO when this is false. Showing a guest a property that is not free on
  /// their dates, without telling them the dates were ignored, is worse than
  /// showing nothing.
  final bool datesApplied;

  const StaySearchPage({
    required this.listings,
    required this.nextCursor,
    required this.totalApprox,
    this.datesApplied = false,
  });

  bool get hasMore => nextCursor != null;
  static const empty = StaySearchPage(
      listings: [], nextCursor: null, totalApprox: 0, datesApplied: false);
}

class StayAvailabilityService {
  StayAvailabilityService._();
  static final instance = StayAvailabilityService._();

  // europe-west1, matching every deployed function. This said 'us-central1',
  // which would have failed at runtime with NOT_FOUND rather than at compile
  // time — the kind of mistake that only shows up on a device.
  final _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

  final _db = FirebaseFirestore.instance;

  /// THE ONLY WAY TO SEARCH. Do not add a second one.
  ///
  /// ── STAGE 1: a direct Firestore query ──────────────────────────────────
  ///
  /// This called a `searchStayListings` Cloud Function that does not exist,
  /// so every search failed. Stage 1 reads Firestore directly, which is enough
  /// for the volume of listings that exist and needs no server work.
  ///
  /// WHAT FIRESTORE CAN DO HERE
  ///   status == live, an inequality on ONE field, and equality filters.
  ///
  /// WHAT IT CANNOT, AND WHY THIS IS STAGED
  ///   "free between 3 and 7 March" is a range CONTAINMENT question. Firestore
  ///   cannot answer it: the blocked nights live in a subcollection, and there
  ///   is no query that says "no document in this subcollection overlaps this
  ///   range". Stage 2 denormalises availability; stage 3 moves the whole
  ///   thing server side.
  ///
  ///   So dates are accepted and IGNORED here, and `datesApplied` on the page
  ///   says so. A screen that quietly dropped the date filter would show a
  ///   guest properties that are not free, which is worse than saying nothing.
  ///
  /// Filtering that Firestore cannot express is done in Dart AFTER the fetch.
  /// That is honest at this size and would need rethinking at thousands of
  /// listings — noted rather than pre-solved.
  Future<StaySearchPage> search(
    StaySearchCriteria criteria, {
    String? cursor,
    int limit = 20,
  }) async {
    Query<Map<String, dynamic>> q = _db
        .collection('stay_listings')
        .where('status', isEqualTo: 'live');

    // Equality filters are free to combine.
    if (criteria.town != null && criteria.town!.trim().isNotEmpty) {
      q = q.where('address.town', isEqualTo: criteria.town!.trim());
    }
    if (criteria.propertyType != null) {
      q = q.where('propertyType', isEqualTo: criteria.propertyType);
    }

    // Over-fetch, because the Dart-side filters below will remove some.
    final snap = await q.limit(limit * 4).get();

    // parseAll, not map(fromDoc): one malformed document must not empty the
    // whole result set. See the note on StayListing.parseAll.
    var results = StayListing.parseAll(snap.docs)
        .where((l) => l.maxGuests >= criteria.guests)
        .where((l) => criteria.minBedrooms == null ||
            l.bedrooms >= criteria.minBedrooms!)
        .where((l) => criteria.minPricePence == null ||
            l.nightlyRate.value >= criteria.minPricePence!)
        .where((l) => criteria.maxPricePence == null ||
            l.nightlyRate.value <= criteria.maxPricePence!)
        .where((l) => criteria.minPartnersHalfMile == 0 ||
            (l.locationContext?.partnerCounts.halfMile ?? 0) >=
                criteria.minPartnersHalfMile)
        .where((l) => criteria.amenities.isEmpty ||
            criteria.amenities.every(l.amenities.contains))
        .toList();

    results.sort((a, b) => switch (criteria.sort) {
          // "Journey time" is the default and the differentiator, but what is
          // actually stored is a STRAIGHT LINE distance. Sorting by it is
          // defensible; labelling it as a journey time would not be. See
          // enrichListingLocation for the HA9 9PT case where two places 9.8
          // miles away are completely different journeys.
          StaySort.journeyTime => (a.locationContext?.distanceToCentreMi ?? 999)
              .compareTo(b.locationContext?.distanceToCentreMi ?? 999),
          StaySort.priceLowHigh =>
            a.nightlyRate.value.compareTo(b.nightlyRate.value),
          StaySort.priceHighLow =>
            b.nightlyRate.value.compareTo(a.nightlyRate.value),
          StaySort.partnersNearby =>
            (b.locationContext?.partnerCounts.halfMile ?? 0)
                .compareTo(a.locationContext?.partnerCounts.halfMile ?? 0),
          StaySort.rating => b.ratingAvg.compareTo(a.ratingAvg),
        });

    final page = results.take(limit).toList(growable: false);

    return StaySearchPage(
      listings: page,
      // No cursor in stage 1. Pretending to paginate while re-running the
      // same query would silently repeat results.
      nextCursor: null,
      totalApprox: results.length,
      datesApplied: false,
    );
  }

  /// Which nights are already taken, for the date picker on one listing.
  ///
  /// listBlockedNights was built on 4 August 2026. Until then this called a
  /// function that did not exist, so every date picker failed with NOT_FOUND
  /// on a device — never in the analyzer.
  ///
  /// Dates go as YYYY-MM-DD, not as a full ISO datetime. A night is a calendar
  /// date, and `2026-08-12T23:00+01:00` is the 11th in UTC — the guest would
  /// see the wrong night marked as taken.
  Future<Set<DateTime>> blockedNights({
    required String listingId,
    required DateTime from,
    required DateTime to,
  }) async {
    String day(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    final callable = _functions.httpsCallable('listBlockedNights');
    final res = await callable.call<Map<String, dynamic>>({
      'listingId': listingId,
      'from': day(from),
      'to': day(to),
    });
    return ((res.data['nights'] as List?) ?? const [])
        .map((e) => DateTime.parse(e.toString()))
        .toSet();
  }
}
