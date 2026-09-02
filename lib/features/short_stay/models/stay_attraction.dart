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
    this.source = 'wikimedia',
  });

  final String url;
  final String licence;
  final String licenceUrl;
  final String author;
  final String sourceUrl;

  /// Where the image came from. 'goouts' for the curated set, 'wikimedia' for
  /// anything left over from the old pipeline.
  ///
  /// ⚠ ADDED 29 August 2026 BECAUSE creditLine USED TO END IN "Wikimedia
  /// Commons" UNCONDITIONALLY. Once we started serving our own photographs
  /// that line would have credited Wikimedia for an image they had nothing to
  /// do with — a false attribution, on the one string whose entire job is to
  /// say truthfully where a picture came from.
  final String source;

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
      // Anything written before 29 August 2026 came from Commons and has no
      // source field, so that is the honest default for a legacy document.
      source: (m['source'] as String?)?.trim() ?? 'wikimedia',
    );
  }

  bool get isOurs => source == 'goouts';

  /// Where the picture came from, written the way that archive asks for.
  ///
  /// ⚠ A LOOKUP, NOT A HARDCODED STRING, AND THE SECOND TIME THIS HAS BITTEN.
  /// The line read '$author · $licence · Wikimedia Commons' unconditionally,
  /// which was true while Commons was the only source. When we started serving
  /// our own photographs it began crediting Wikimedia for images they had
  /// nothing to do with, so a `source` field was added and this line taught
  /// about exactly one new value.
  ///
  /// It would do it again the moment a Geograph or an Unsplash picture
  /// arrived. A credit line naming the wrong archive is worse than none,
  /// because it looks like diligence.
  static const Map<String, String> _sourceLabels = <String, String>{
    'wikimedia': 'Wikimedia Commons',
    'geograph': 'Geograph Britain and Ireland',
    'unsplash': 'Unsplash',
    'pexels': 'Pexels',
    'press': 'supplied by the attraction',
    'host': 'photographed by a GoOuts host',
    'guest': 'photographed by a GoOuts guest',
  };

  /// One line, ready to render under an image.
  ///
  /// Ours reads simply the author, with no licence and no archive, because
  /// there is no third party to credit and "Owned" is bookkeeping rather than
  /// something to print under a photograph.
  ///
  /// ⚠ AN UNKNOWN SOURCE FALLS BACK TO AUTHOR AND LICENCE ONLY. Naming no
  /// archive is honest. Naming the wrong one is not, and guessing is how the
  /// original fault happened.
  String get creditLine {
    if (isOurs) return author;
    final String archive = _sourceLabels[source] ?? '';
    return archive.isEmpty
        ? '$author · $licence'
        : '$author · $licence · $archive';
  }
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
    this.about = '',
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

  /// What this day out is, in two or three sentences.
  ///
  /// ⚠ WRITTEN BY A PERSON IN THE ADMIN PANEL, and empty until somebody does.
  /// There is no automatic source: OSM has no usable description field and the
  /// one thing that did have descriptions was Wikipedia, which was taken out
  /// of this pipeline on 29 August 2026.
  ///
  /// Empty renders as nothing rather than as a gap, for the same reason the
  /// photograph does — a plainer card is fine, a card with a hole in it is not.
  final String about;

  bool get hasAbout => about.trim().isNotEmpty;

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
      about: (m['about'] as String?)?.trim() ?? '',
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
        // ⚠ `cell` IS THE FIELD THE GRID WRITES, `city` THE OLD PER TOWN BUILD.
        //
        // Reading only `city` would leave this empty for every grid document
        // and empty is not obviously wrong on a screen, so it would have gone
        // unnoticed. Both are read while the two live side by side; see
        // stay_grid.js for why the town keyed build is going away.
        city: (m['city'] as String?)?.trim() ??
            (m['cell'] as String?)?.trim() ??
            '',
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
