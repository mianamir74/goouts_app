import 'package:cloud_firestore/cloud_firestore.dart';
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

  /// Generated from bedrooms and bathrooms by the server. This is exactly what
  /// the guest is asked to photograph, so it must not be guessed client side.
  final List<String> captureRooms;

  final List<StayPhoto> photos;
  final StayLocationContext? locationContext;

  final double ratingAvg;
  final int ratingCount;

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
    required this.captureRooms,
    required this.photos,
    required this.locationContext,
    required this.ratingAvg,
    required this.ratingCount,
  });

  factory StayListing.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      StayListing.fromMap(doc.id, doc.data() ?? const {});

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
    );
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
