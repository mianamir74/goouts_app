import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'money.dart';
import 'stay_enums.dart';

// ─────────────────────────────────────────────────────────────────────────────
// A property listing.  Collection: stay_listings/{listingId}
//
// TWO RULES ABOUT THIS MODEL
//
// 1. Every field read is null safe with a sensible fallback. A missing field
//    must render an empty state, never crash. Firestore documents written by
//    an older app version, or edited by hand in the console, WILL be missing
//    fields eventually.
//
// 2. `locationContext` is written ONLY by the enrichListingLocation Cloud
//    Function. There is no toMap for it here, deliberately, so no client code
//    can accidentally write it. A host who could write it would claim every
//    property is five minutes from the centre.
// ─────────────────────────────────────────────────────────────────────────────

class StayListing {
  final String id;
  final String hostUid;
  final ListingStatus status;
  final String title;
  final String description;

  final StayAddress address;
  final double? lat;
  final double? lng;

  final String propertyType;
  final int bedrooms;
  final int beds;
  final int bathrooms;
  final int maxGuests;
  final List<String> amenities;

  final Pence nightlyRate;
  final Pence cleaningFee;
  final CancellationPolicy cancellationPolicy;
  final BookingMode bookingMode;

  // ── House rules, check-in and check-out. Added 27 August 2026. ─────────────
  //
  // Reported as "there is no rules shows to consumer check in and check out".
  //
  // The Stitch guest screens showed all of this — trip detail draws "Check in
  // 15:00 / Check out 11:00" and a House rules row — and nothing collected it.
  // Not this model, not createStayListing, not the host wizard.
  // 15_trip_detail_screen.dart recorded the gap in its own header on 17 August
  // and correctly left the section out rather than invent a check-in time for
  // somebody's holiday. The host now supplies it on wizard step 7.
  //
  // ⚠ "HH:MM" WALL CLOCK, NEVER A DateTime. A check-in time is a fact about the
  // property, not an instant. A DateTime forces a date onto it and goes wrong
  // when the clocks change.
  //
  // ⚠ DEFAULTED, NOT NULLABLE. Every listing created before today has no such
  // field. A null check-in time on a confirmed booking is worse for the guest
  // than the conventional one, and 15:00 / 11:00 is the UK short-let norm and
  // exactly what the server writes when the host leaves the step alone.
  final String checkInTime;
  final String checkOutTime;

  final StayHouseRules houseRules;

  /// ⚠ PRIVATE. Door codes and key safe locations. Shown ONLY once a booking is
  /// confirmed, never on the public listing screen. Kept as its own field
  /// rather than inside houseRules so that distinction is visible here.
  final String arrivalInstructions;

  /// Who the guest is staying with.
  ///
  /// ── ⚠ WHY THIS IS ON THE LISTING AND NOT READ FROM /stay_hosts ────────────
  ///
  /// Added 27 August 2026, reported as "host profile is missing completely".
  ///
  /// Stitch draws "Hosted by Sarah, host since 2021" near the top of the
  /// listing. 05_listing_detail_screen recorded on 3 August that the row was
  /// removed because "the guest cannot read /stay_hosts under the security
  /// rules", and that is still true and still correct:
  ///
  ///     match /stay_hosts/{hostId} {
  ///       allow read: if ownsDoc(hostId) || isAdmin();
  ///     }
  ///
  /// A host record carries KYC evidence, payout details and booking history.
  /// Opening it up so a browsing guest can read a first name would be a
  /// serious mistake, so the answer is to copy the two harmless public fields
  /// onto the listing at the moment it is created, on the server, where a
  /// client cannot forge them.
  ///
  /// ⚠ THE SEED WAS ALREADY DOING HALF OF THIS AND NOBODY READ IT.
  /// stay_demo_seed.js has written `hostDisplayName: "GoOuts Demo Host"` onto
  /// every demo listing since the beginning. It was never on the model, so no
  /// screen ever showed it. That is the same one fact two names failure as
  /// idFrontUrl / kycIdFrontUrl and isSeed / isDemo, so the parser below reads
  /// the new `host` map AND falls back to the old flat field rather than
  /// leaving a third spelling behind.
  final StayHostSummary host;

  /// Generated from bedrooms and bathrooms by the server. This is exactly what
  /// the guest is asked to photograph, so it must not be guessed client side.
  final List<String> captureRooms;

  final List<StayPhoto> photos;
  final StayLocationContext? locationContext;

  final double ratingAvg;
  final int ratingCount;

  /// The six sub scores, each with its OWN average and its OWN count.
  ///
  /// Written by submitStayReview in functions/stay_reviews.js as
  /// `{cleanliness: {avg: 4.8, count: 11}, ...}`.
  ///
  /// ⚠ SEPARATE COUNTS, NOT ONE SHARED DENOMINATOR. The scores are optional
  /// and a guest may answer four of the six. A shared count would drag any
  /// category people skip towards zero, and "Location 2.1" on a property
  /// nobody complained about is worse than showing no figure at all — which
  /// is why a category with a count of zero renders as nothing here.
  final Map<String, StayCategoryRating> ratingCategories;

  const StayListing({
    required this.id,
    required this.hostUid,
    required this.status,
    required this.title,
    required this.description,
    required this.address,
    required this.lat,
    required this.lng,
    required this.propertyType,
    required this.bedrooms,
    required this.beds,
    required this.bathrooms,
    required this.maxGuests,
    required this.amenities,
    required this.nightlyRate,
    required this.cleaningFee,
    required this.cancellationPolicy,
    required this.bookingMode,
    required this.checkInTime,
    required this.checkOutTime,
    required this.houseRules,
    required this.arrivalInstructions,
    required this.host,
    required this.captureRooms,
    required this.photos,
    required this.locationContext,
    required this.ratingAvg,
    required this.ratingCount,
    this.ratingCategories = const <String, StayCategoryRating>{},
  });

  factory StayListing.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      StayListing.fromMap(doc.id, doc.data() ?? const {});

  /// Parses a whole query result, DROPPING any document that will not parse.
  ///
  /// ── WHY THIS IS NOT `docs.map(fromDoc)` ──────────────────────────────────
  ///
  /// 18 August 2026, reported as "I cannot see listings any more" with 46 live
  /// listings sitting in the database.
  ///
  /// fromMap is defensive about MISSING fields — every read has a default. It
  /// is not defensive about fields of the WRONG TYPE. `m['amenities'] as List?`
  /// returns null for absent and throws for a Map. Same for photos, and for
  /// title or hostUid stored as a number.
  ///
  /// Eight of those 46 are our demo seed and are perfectly shaped. The other
  /// 38 came from elsewhere. `docs.map(fromDoc)` is all-or-nothing across the
  /// batch, so ONE malformed document anywhere in the window threw, and the
  /// guest saw an empty Short Stay with no properties and no explanation.
  ///
  /// A listing we cannot read is a listing we cannot show. It is not a reason
  /// to hide the other forty-five.
  ///
  /// The failure is not silent — it is counted and logged, so a listing that
  /// vanishes from the app is findable rather than merely absent.
  static List<StayListing> parseAll(
      Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final out = <StayListing>[];
    final skipped = <String>[];
    for (final d in docs) {
      try {
        out.add(StayListing.fromDoc(d));
      } catch (e) {
        skipped.add('${d.id}: $e');
      }
    }
    if (skipped.isNotEmpty) {
      debugPrint('StayListing.parseAll dropped ${skipped.length} of '
          '${out.length + skipped.length}: ${skipped.join(" | ")}');
    }
    return List<StayListing>.unmodifiable(out);
  }

  factory StayListing.fromMap(String id, Map<String, dynamic> m) {
    final geo = (m['geo'] as Map?)?.cast<String, dynamic>();
    return StayListing(
      id: id,
      hostUid: (m['hostUid'] ?? '') as String,
      status: ListingStatus.from(m['status'] as String?),
      title: (m['title'] ?? '') as String,
      description: (m['description'] ?? '') as String,
      address: StayAddress.fromMap((m['address'] as Map?)?.cast<String, dynamic>()),
      lat: (geo?['lat'] as num?)?.toDouble(),
      lng: (geo?['lng'] as num?)?.toDouble(),
      propertyType: (m['propertyType'] ?? '') as String,
      bedrooms: (m['bedrooms'] as num?)?.toInt() ?? 0,
      beds: (m['beds'] as num?)?.toInt() ?? 0,
      bathrooms: (m['bathrooms'] as num?)?.toInt() ?? 0,
      maxGuests: (m['maxGuests'] as num?)?.toInt() ?? 1,
      amenities: ((m['amenities'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      nightlyRate: Pence.fromFirestore(m['nightlyRate']),
      cleaningFee: Pence.fromFirestore(m['cleaningFee']),
      cancellationPolicy:
          CancellationPolicy.from(m['cancellationPolicy'] as String?),
      bookingMode: BookingMode.from(m['bookingMode'] as String?),
      // Defaults matter here: every listing written before 27 August 2026 has
      // none of these keys. See the field declarations above.
      checkInTime: _hhmm(m['checkInTime'], '15:00'),
      checkOutTime: _hhmm(m['checkOutTime'], '11:00'),
      houseRules: StayHouseRules.fromMap(
          (m['houseRules'] as Map?)?.cast<String, dynamic>()),
      arrivalInstructions: (m['arrivalInstructions'] as String?)?.trim() ?? '',
      host: StayHostSummary.fromListing(m),
      captureRooms: ((m['captureRooms'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      photos: ((m['photos'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => StayPhoto.fromMap(e.cast<String, dynamic>()))
          .toList(growable: false),
      locationContext: m['locationContext'] == null
          ? null
          : StayLocationContext.fromMap(
              (m['locationContext'] as Map).cast<String, dynamic>()),
      ratingAvg: (m['ratingAvg'] as num?)?.toDouble() ?? 0,
      ratingCount: (m['ratingCount'] as num?)?.toInt() ?? 0,
      ratingCategories:
          StayCategoryRating.parseAll(m['ratingCategories'] as Map?),
    );
  }

  /// Accepts only a real 24-hour "HH:MM", otherwise returns [dflt].
  ///
  /// ⚠ VALIDATES RATHER THAN TRUSTS. The server writes this format, but older
  /// documents, the demo seed and anything written by hand do not go through
  /// createStayListing. A malformed string rendered straight onto a booking
  /// screen reads as a real check-in time, which is the worst failure mode:
  /// wrong and confident. Falling back to the norm is honest and safe.
  static String _hhmm(Object? raw, String dflt) {
    final String s = (raw is String ? raw : '').trim();
    return RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(s) ? s : dflt;
  }

  String? get coverPhotoUrl => photos.isEmpty ? null : photos.first.url;
  bool get isLive => status == ListingStatus.live;

  /// Never write locationContext, status or ratings from a client.
  Map<String, dynamic> toHostEditableMap() => {
        'title': title,
        'description': description,
        'propertyType': propertyType,
        'bedrooms': bedrooms,
        'beds': beds,
        'bathrooms': bathrooms,
        'maxGuests': maxGuests,
        'amenities': amenities,
        'nightlyRate': nightlyRate.value,
        'cleaningFee': cleaningFee.value,
        'cancellationPolicy': cancellationPolicy.wire,
        'bookingMode': bookingMode.wire,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

/// The small, public, harmless part of a host, copied onto the listing by the
/// server so a guest never needs to read /stay_hosts.
///
/// A first name and a joining year. Nothing here identifies a home, a bank
/// account or a document. See the note on StayListing.host for why it is copied
/// rather than looked up.
/// One of the six category scores on a listing: its average and how many
/// guests actually answered it.
///
/// ⚠ THE COUNT IS PART OF THE FACT, not bookkeeping. "Cleanliness 5.0" from
/// one guest and from forty are different claims, and a screen that shows only
/// the number cannot tell them apart. Anything with a count of zero is not
/// rendered at all — see hasEnough.
class StayCategoryRating {
  const StayCategoryRating({required this.avg, required this.count});

  final double avg;
  final int count;

  /// Below this a figure is noise dressed as a measurement. One person who
  /// disliked the parking should not put "Location 2.0" under a property
  /// nobody else complained about.
  static const int minToShow = 2;

  bool get hasEnough => count >= minToShow;

  static Map<String, StayCategoryRating> parseAll(Map? raw) {
    if (raw == null) return const <String, StayCategoryRating>{};
    final Map<String, StayCategoryRating> out = <String, StayCategoryRating>{};
    raw.forEach((Object? k, Object? v) {
      if (k is! String || v is! Map) return;
      final double a = (v['avg'] as num?)?.toDouble() ?? 0;
      final int c = (v['count'] as num?)?.toInt() ?? 0;
      if (c <= 0) return;
      out[k] = StayCategoryRating(avg: a, count: c);
    });
    return out;
  }
}

class StayHostSummary {
  const StayHostSummary({
    required this.name,
    required this.photoUrl,
    required this.since,
  });

  /// First name only. Full names are not shown on a public listing.
  final String name;

  final String photoUrl;

  /// The year they joined, or 0 when it is not known. Never guessed.
  final int since;

  static const StayHostSummary unknown =
      StayHostSummary(name: '', photoUrl: '', since: 0);

  /// Reads whichever shape the document happens to carry.
  ///
  /// ⚠ TWO SHAPES EXIST AND BOTH ARE LIVE:
  ///
  ///   host: {name, photoUrl, since}   written by createStayListing and by the
  ///                                   demo seed from 27 August 2026
  ///   hostDisplayName: "..."          written by the demo seed since day one
  ///
  /// The flat field is read as a fallback so listings seeded before today keep
  /// working. Do not delete that branch to tidy up; it silently blanks the host
  /// on every listing already in the database.
  factory StayHostSummary.fromListing(Map<String, dynamic> m) {
    final Map<String, dynamic>? h =
        (m['host'] as Map?)?.cast<String, dynamic>();

    if (h != null) {
      final Object? raw = h['since'];
      return StayHostSummary(
        name: (h['name'] as String?)?.trim() ?? '',
        photoUrl: (h['photoUrl'] as String?)?.trim() ?? '',
        // Only a plausible year counts. A stray 0, a timestamp in milliseconds
        // or a typo would otherwise render as "host since 1754297".
        since: raw is num && raw >= 2000 && raw <= 2100 ? raw.toInt() : 0,
      );
    }

    final String legacy = (m['hostDisplayName'] as String?)?.trim() ?? '';
    if (legacy.isNotEmpty) {
      return StayHostSummary(name: legacy, photoUrl: '', since: 0);
    }
    return unknown;
  }

  bool get hasName => name.isNotEmpty;
  bool get hasSince => since >= 2000;

  /// The first letter, for the fallback avatar when there is no photograph.
  String get initial => hasName ? name.substring(0, 1).toUpperCase() : '?';
}

/// What the host permits, and anything else they wrote.
///
/// ── ⚠ EVERY PERMISSION DEFAULTS TO FALSE, MEANING NOT ALLOWED ───────────────
///
/// A listing created before these fields existed, or a host who never opened
/// the step, produces "not allowed" for all three. That is the safe direction:
/// silence must not grant a guest permission to smoke in, bring a dog to, or
/// hold a party in somebody's home. The reverse default would quietly permit
/// all three on every legacy listing in the database.
class StayHouseRules {
  const StayHouseRules({
    required this.smokingAllowed,
    required this.petsAllowed,
    required this.partiesAllowed,
    required this.quietHoursFrom,
    required this.quietHoursTo,
    required this.additional,
  });

  final bool smokingAllowed;
  final bool petsAllowed;
  final bool partiesAllowed;

  /// Empty when the host set no quiet hours. NOT "00:00", which is midnight and
  /// a completely different statement.
  final String quietHoursFrom;
  final String quietHoursTo;

  /// Free text. Shoes off, bins on Tuesday, no parking on the drive.
  final String additional;

  static const StayHouseRules none = StayHouseRules(
    smokingAllowed: false,
    petsAllowed: false,
    partiesAllowed: false,
    quietHoursFrom: '',
    quietHoursTo: '',
    additional: '',
  );

  factory StayHouseRules.fromMap(Map<String, dynamic>? m) {
    if (m == null) return none;
    String time(Object? v) {
      final String s = (v is String ? v : '').trim();
      return RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(s) ? s : '';
    }

    return StayHouseRules(
      // `== true` and not a cast: a missing key, a null, or a string "false"
      // must all read as not allowed.
      smokingAllowed: m['smokingAllowed'] == true,
      petsAllowed: m['petsAllowed'] == true,
      partiesAllowed: m['partiesAllowed'] == true,
      quietHoursFrom: time(m['quietHoursFrom']),
      quietHoursTo: time(m['quietHoursTo']),
      additional: (m['additional'] as String?)?.trim() ?? '',
    );
  }

  bool get hasQuietHours =>
      quietHoursFrom.isNotEmpty && quietHoursTo.isNotEmpty;

  /// True when the host has said nothing beyond the three defaults, so a screen
  /// can hide the section entirely rather than print three "Not allowed" lines
  /// the host never actually chose.
  bool get isUnset =>
      !smokingAllowed &&
      !petsAllowed &&
      !partiesAllowed &&
      !hasQuietHours &&
      additional.isEmpty;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'smokingAllowed': smokingAllowed,
        'petsAllowed': petsAllowed,
        'partiesAllowed': partiesAllowed,
        'quietHoursFrom': quietHoursFrom,
        'quietHoursTo': quietHoursTo,
        'additional': additional,
      };
}

class StayAddress {
  final String line1;
  final String town;
  final String postcode;
  final String country;
  const StayAddress({
    required this.line1,
    required this.town,
    required this.postcode,
    required this.country,
  });

  factory StayAddress.fromMap(Map<String, dynamic>? m) => StayAddress(
        line1: (m?['line1'] ?? '') as String,
        town: (m?['town'] ?? '') as String,
        postcode: (m?['postcode'] ?? '') as String,
        country: (m?['country'] ?? 'United Kingdom') as String,
      );

  /// What a guest sees before booking. Never the full address.
  String get publicLabel => town.isEmpty ? country : town;
}

class StayPhoto {
  final String url;
  final String storagePath;
  final int order;
  const StayPhoto(
      {required this.url, required this.storagePath, required this.order});

  factory StayPhoto.fromMap(Map<String, dynamic> m) => StayPhoto(
        url: (m['url'] ?? '') as String,
        storagePath: (m['storagePath'] ?? '') as String,
        order: (m['order'] as num?)?.toInt() ?? 0,
      );
}

// ── Server written. Read only on the client. ─────────────────────────────────
class StayLocationContext {
  final DateTime? computedAt;
  final String source;
  final String centreName;
  final double distanceToCentreMi;
  final List<StayStation> stations;
  final StayPartnerCounts partnerCounts;
  final List<StayNearbyPartner> nearestPartners;
  final List<String> clusterIds;

  /// Which auto filled fields the host overrode. Shown in admin so a listing
  /// claiming an implausible distance can be checked.
  final List<String> hostEdited;

  const StayLocationContext({
    required this.computedAt,
    required this.source,
    required this.centreName,
    required this.distanceToCentreMi,
    required this.stations,
    required this.partnerCounts,
    required this.nearestPartners,
    required this.clusterIds,
    required this.hostEdited,
  });

  factory StayLocationContext.fromMap(Map<String, dynamic> m) =>
      StayLocationContext(
        computedAt: (m['computedAt'] as Timestamp?)?.toDate(),
        source: (m['source'] ?? '') as String,
        centreName: (m['centreName'] ?? '') as String,
        distanceToCentreMi:
            (m['distanceToCentreMi'] as num?)?.toDouble() ?? 0,
        stations: ((m['stations'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => StayStation.fromMap(e.cast<String, dynamic>()))
            .toList(growable: false),
        partnerCounts: StayPartnerCounts.fromMap(
            (m['partnerCounts'] as Map?)?.cast<String, dynamic>()),
        nearestPartners: ((m['nearestPartners'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => StayNearbyPartner.fromMap(e.cast<String, dynamic>()))
            .toList(growable: false),
        clusterIds: ((m['clusterIds'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(growable: false),
        hostEdited: ((m['hostEdited'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(growable: false),
      );

  /// "7.9 miles from Central London". One decimal, because two implies a
  /// precision a straight line distance does not have.
  String get centreLabel =>
      '${distanceToCentreMi.toStringAsFixed(1)} miles from $centreName';

  bool get isStale =>
      computedAt == null ||
      DateTime.now().difference(computedAt!).inDays > 45;
}

class StayStation {
  final String name;
  final List<String> lines;
  final double walkMi;
  const StayStation(
      {required this.name, required this.lines, required this.walkMi});

  factory StayStation.fromMap(Map<String, dynamic> m) => StayStation(
        name: (m['name'] ?? '') as String,
        lines: ((m['lines'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(growable: false),
        walkMi: (m['walkMi'] as num?)?.toDouble() ?? 0,
      );

  String get linesLabel => lines.join(' and ');
  String get walkLabel => '${walkMi.toStringAsFixed(1)} miles walking';
}

class StayPartnerCounts {
  final int halfMile;
  final int oneMile;
  final Map<String, int> byCategory;
  const StayPartnerCounts({
    required this.halfMile,
    required this.oneMile,
    required this.byCategory,
  });

  factory StayPartnerCounts.fromMap(Map<String, dynamic>? m) =>
      StayPartnerCounts(
        halfMile: (m?['halfMile'] as num?)?.toInt() ?? 0,
        oneMile: (m?['oneMile'] as num?)?.toInt() ?? 0,
        byCategory: ((m?['byCategory'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0)),
      );

  /// The headline on every listing card. This is the differentiator, so it has
  /// exactly one definition.
  /// Rewritten 4 August 2026 after the first real test against live data.
  ///
  /// The original was:
  ///
  ///     halfMile == 1 ? '1 GoOuts partner within half a mile'
  ///                   : '$halfMile GoOuts partners within half a mile'
  ///
  /// which for the HA9 9PT test listing rendered
  /// "0 GoOuts partners within half a mile" on the listing card. That is a
  /// sentence that actively sells against the property, and it would have
  /// appeared on the majority of listings outside zone 1 — the whole partner
  /// estate is currently central London.
  ///
  /// So it now widens the radius before it gives up, and returns null rather
  /// than announcing a zero. A null headline renders as nothing, which is the
  /// honest outcome when there is genuinely nothing nearby to boast about.
  String? get headline {
    if (halfMile == 1) return '1 GoOuts partner within half a mile';
    if (halfMile > 1) return '$halfMile GoOuts partners within half a mile';
    if (oneMile == 1) return '1 GoOuts partner within a mile';
    if (oneMile > 1) return '$oneMile GoOuts partners within a mile';
    return null;
  }

  /// "6 restaurants, 3 pubs, 2 cafes"
  String get breakdown {
    final parts = byCategory.entries
        .where((e) => e.value > 0)
        .map((e) => '${e.value} ${e.key}')
        .toList();
    return parts.join(', ');
  }

  bool get hasAny => halfMile > 0 || oneMile > 0;
}

class StayNearbyPartner {
  final String id;
  final String name;
  final String category;
  final double walkMi;
  final double cashbackRate;
  const StayNearbyPartner({
    required this.id,
    required this.name,
    required this.category,
    required this.walkMi,
    required this.cashbackRate,
  });

  factory StayNearbyPartner.fromMap(Map<String, dynamic> m) =>
      StayNearbyPartner(
        id: (m['id'] ?? '') as String,
        name: (m['name'] ?? '') as String,
        category: (m['category'] ?? '') as String,
        walkMi: (m['walkMi'] as num?)?.toDouble() ?? 0,
        cashbackRate: (m['cashbackRate'] as num?)?.toDouble() ?? 0,
      );

  String get cashbackLabel => '${cashbackRate.toStringAsFixed(0)}% cashback';
}
