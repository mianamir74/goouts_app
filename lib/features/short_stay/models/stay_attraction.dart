// ─────────────────────────────────────────────────────────────────────────────
//  Days out, as the app reads them.
//
//  Written 28 August 2026. Mirrors stay_attractions.js, which is the writer.
//
//  ── ⚠ EVERY FIELD HERE IS SOMETHING SOMEBODY MEASURED ───────────────────────
//
//  Names and coordinates come from OpenStreetMap. Partner counts are computed
//  from our own partners collection. Distance is calculated. Nothing on this
//  model is an estimate, and nothing should be added that is.
//
//  In particular there is NO travel time. The Stitch design says "About 35
//  minutes from your door" and we have no routing API; a straight line is not a
//  journey. The screens show miles, which is what locationContext already uses
//  everywhere else in the product.
// ─────────────────────────────────────────────────────────────────────────────

/// Where a photograph came from and what we owe for showing it.
///
/// ── ⚠ THIS IS NOT DECORATION. ───────────────────────────────────────────────
///
/// Wikimedia licences differ per image. CC0 asks nothing; CC BY and CC BY-SA
/// require crediting the photographer by name. The credit travels on the same
/// document as the URL so the two can never be separated, and the card renders
/// it.
///
/// If a screen shows [url] it MUST show [author] and [licence]. Dropping the
/// credit to tidy up a card is the one change nobody is allowed to make here.
class StayPhotoCredit {
  const StayPhotoCredit({
    required this.url,
    required this.licence,
    required this.licenceUrl,
    required this.author,
    required this.sourceUrl,
  });

  final String url;
  final String licence;
  final String licenceUrl;
  final String author;
  final String sourceUrl;

  static StayPhotoCredit? fromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    final String url = (m['url'] as String?)?.trim() ?? '';
    final String licence = (m['licence'] as String?)?.trim() ?? '';
    // ⚠ BOTH OR NEITHER. A URL with no licence is a photograph we cannot prove
    // we may use, so it is treated as absent rather than shown uncredited.
    if (url.isEmpty || licence.isEmpty) return null;
    return StayPhotoCredit(
      url: url,
      licence: licence,
      licenceUrl: (m['licenceUrl'] as String?)?.trim() ?? '',
      author: (m['author'] as String?)?.trim() ?? 'Unknown',
      sourceUrl: (m['sourceUrl'] as String?)?.trim() ?? '',
    );
  }

  /// One line, ready to render under an image.
  String get creditLine => '$author · $licence · Wikimedia Commons';
}

/// One place inside a day out.
class StayPlace {
  const StayPlace({
    required this.name,
    required this.category,
    required this.lat,
    required this.lng,
  });

  final String name;
  final String category;
  final double lat;
  final double lng;

  factory StayPlace.fromMap(Map<String, dynamic> m) => StayPlace(
        name: (m['name'] as String?)?.trim() ?? '',
        category: (m['category'] as String?)?.trim() ?? 'Attraction',
        lat: (m['lat'] as num?)?.toDouble() ?? 0,
        lng: (m['lng'] as num?)?.toDouble() ?? 0,
      );

  bool get isUsable => name.isNotEmpty && lat != 0 && lng != 0;
}

/// A group of places close enough to visit in one outing.
class StayCluster {
  const StayCluster({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.places,
    required this.placeCount,
    required this.partnerCount,
    required this.partnerCategories,
    required this.photo,
  });

  final String id;
  final String name;
  final double lat;
  final double lng;
  final List<StayPlace> places;

  /// How many places the cluster really holds. [places] is capped at 12 by the
  /// builder, so this can be larger, and the screen says "and N more" rather
  /// than pretending the list is complete.
  final int placeCount;

  /// GoOuts partners within half a mile of the cluster centre.
  ///
  /// ⚠ THE ONE FIGURE ON THIS SCREEN NO OTHER TRAVEL APP CAN SHOW. It leads the
  /// card for that reason.
  final int partnerCount;
  final Map<String, int> partnerCategories;

  final StayPhotoCredit? photo;

  factory StayCluster.fromMap(Map<String, dynamic> m) {
    final List<StayPlace> places = ((m['places'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => StayPlace.fromMap(e.cast<String, dynamic>()))
        .where((p) => p.isUsable)
        .toList(growable: false);

    final Map<String, int> cats = <String, int>{};
    final Map? raw = m['partnerCategories'] as Map?;
    if (raw != null) {
      raw.forEach((k, v) {
        final int n = (v as num?)?.toInt() ?? 0;
        if (n > 0) cats['$k'] = n;
      });
    }

    return StayCluster(
      id: (m['id'] as String?)?.trim() ?? '',
      name: (m['name'] as String?)?.trim() ?? '',
      lat: (m['lat'] as num?)?.toDouble() ?? 0,
      lng: (m['lng'] as num?)?.toDouble() ?? 0,
      places: places,
      placeCount: (m['placeCount'] as num?)?.toInt() ?? places.length,
      partnerCount: (m['partnerCount'] as num?)?.toInt() ?? 0,
      partnerCategories: cats,
      photo: StayPhotoCredit.fromMap(
          (m['photo'] as Map?)?.cast<String, dynamic>()),
    );
  }

  bool get isUsable => name.isNotEmpty && places.isNotEmpty;

  /// "3 restaurants, 2 pubs, 1 cafe", or empty when nothing is near.
  ///
  /// Built from the real breakdown rather than a sentence chosen by the screen,
  /// so it cannot describe a mix the count does not support.
  String get partnerSummary {
    if (partnerCategories.isEmpty) return '';
    final List<MapEntry<String, int>> e = partnerCategories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return e.take(3).map((x) {
      final String label = x.key.toLowerCase();
      return '${x.value} ${x.value == 1 ? label : '${label}s'}';
    }).join(', ');
  }
}

/// Everything known about one city's days out.
class StayAttractions {
  const StayAttractions({
    required this.city,
    required this.cityName,
    required this.clusters,
    required this.attribution,
    required this.attributionUrl,
  });

  final String city;
  final String cityName;
  final List<StayCluster> clusters;

  /// ⚠ REQUIRED BY ODbL AND RENDERED BY THE SCREENS. Read from the document
  /// rather than hardcoded in the app, so the obligation travels with the data
  /// and cannot be dropped by someone tidying a widget.
  final String attribution;
  final String attributionUrl;

  factory StayAttractions.fromMap(Map<String, dynamic> m) => StayAttractions(
        city: (m['city'] as String?)?.trim() ?? '',
        cityName: (m['cityName'] as String?)?.trim() ?? '',
        clusters: ((m['clusters'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => StayCluster.fromMap(e.cast<String, dynamic>()))
            .where((c) => c.isUsable)
            .toList(growable: false),
        attribution: (m['attribution'] as String?)?.trim() ??
            '© OpenStreetMap contributors',
        attributionUrl: (m['attributionUrl'] as String?)?.trim() ??
            'https://www.openstreetmap.org/copyright',
      );

  bool get isEmpty => clusters.isEmpty;
}
