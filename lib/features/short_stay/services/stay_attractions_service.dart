import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/stay_attraction.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Reading days out.
//
//  Written 28 August 2026. Moved from town names to a geographic grid on
//  30 August 2026 — see the block above cellIdFor for why.
//
//  ── ⚠ ONE DOCUMENT PER GRID CELL, AND IT IS CACHED FOR THE SESSION ──────────
//
//  stay_attractions_grid/{cellId} holds every day out around one cell of about
//  28km by 32km. Every listing in that square reads the same document, which is
//  the whole reason the data is built per area rather than per property.
//
//  Museums do not move, so re-reading on every screen open would be a Firestore
//  read for a document that changed months ago. The in-memory cache below holds
//  it for the life of the app process.
//
//  ⚠ NOT PERSISTED TO DISK. A stale city on a device for weeks is worse than
//  one extra read after a restart, and Firestore's own offline cache already
//  covers the reconnect case.
// ─────────────────────────────────────────────────────────────────────────────

class StayAttractionsService {
  StayAttractionsService._();
  static final StayAttractionsService instance = StayAttractionsService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Cache key -> days out. A null VALUE means "asked, nothing there", which is
  /// cached too so an unbuilt area is not re-read all session.
  final Map<String, StayAttractions?> _cache = <String, StayAttractions?>{};

  // ───────────────────────────────────────────────────────────────────────────
  //  THE GRID
  //
  //  ⚠ EVERY CONSTANT AND BOTH LINES OF ARITHMETIC BELOW ARE COPIED FROM
  //  stay_grid.js AND MUST MATCH IT EXACTLY. A cell computed one way on the
  //  server and another here is a guest reading a document that does not
  //  describe where they are — or, far more likely, reading nothing at all and
  //  being told the area is unmapped.
  //
  //  ⚠ WHY THIS REPLACED THE TOWN NAME LOOKUP. The old rule slugified the town
  //  written on the listing and fetched that document id, an exact match with
  //  no fallback. It missed for "Newcastle upon Tyne", then for all thirty two
  //  London boroughs, and it would have gone on missing for every village and
  //  suburb in the country — silently each time, because an unmapped area
  //  renders as a tidy empty state that looks like an answer.
  //
  //  Coordinates cannot miss. Every listing already carries them.
  // ───────────────────────────────────────────────────────────────────────────

  /// South west origin. 49.0 rather than 49.75 so the Channel Islands are in.
  static const double _gridLat0 = 49.0;
  static const double _gridLng0 = -8.75;

  /// North east limit. Out Stack, the top of Shetland, is 60.86 N.
  static const double _gridLat1 = 61.0;
  static const double _gridLng1 = 2.0;

  /// Cell size in degrees: about 27.8km by 31.8km at 55 N.
  static const double _gridDLat = 0.25;
  static const double _gridDLng = 0.5;

  /// Which cell a coordinate is in, or null outside the UK box.
  ///
  /// ⚠ MUST MATCH cellIdFor() IN stay_grid.js, including returning null rather
  /// than clamping. A coordinate off the grid has no document, and inventing
  /// the nearest one would show a guest in Dublin the days out for Anglesey.
  static String? cellIdFor(double? lat, double? lng) {
    if (lat == null || lng == null) return null;
    if (!lat.isFinite || !lng.isFinite) return null;
    if (lat < _gridLat0 || lat >= _gridLat1) return null;
    if (lng < _gridLng0 || lng >= _gridLng1) return null;
    final int row = ((lat - _gridLat0) / _gridDLat).floor();
    final int col = ((lng - _gridLng0) / _gridDLng).floor();
    return 'g${row}_$col';
  }

  /// The days out around a property, or null when we have nothing for it.
  ///
  /// [town] is a FALLBACK ONLY and will be removed. See [forTown].
  ///
  /// Never throws. A failed read shows the empty state, which is the same thing
  /// the guest sees for an area we have not built, and neither is worth an
  /// error dialog on a browsing screen.
  Future<StayAttractions?> forProperty({
    double? lat,
    double? lng,
    String town = '',
  }) async {
    final String? cell = cellIdFor(lat, lng);

    if (cell != null) {
      if (_cache.containsKey(cell)) {
        final StayAttractions? hit = _cache[cell];
        if (hit != null) return hit;
        // Cached as absent. Fall through to the town document rather than
        // returning null, so an area the sweep has not reached yet still shows
        // whatever the old per city build left behind.
      } else {
        try {
          final StayAttractions? out = await _readCell(cell, lat, lng);
          _cache[cell] = out;
          if (out != null) return out;
        } catch (_) {
          // Not cached: a network failure should be retried on the next open,
          // an unbuilt cell should not.
        }
      }
    }

    // ── ⚠ TEMPORARY, AND IT IS THE WHOLE MIGRATION PLAN ─────────────────────
    //
    //  The sweep takes a few days to cover the country. Deleting this fallback
    //  on the day the grid ships would black out the days out screen for every
    //  guest until their cell happened to be reached.
    //
    //  ⚠ REMOVE IT, ALONG WITH forTown, CITIES AND ALL 145 ALIASES, ONCE
    //  attractionGridStatus REPORTS done: true. Left in place it is a second
    //  source of truth for the same fact, which is the failure this codebase
    //  produces more than any other.
    if (town.isEmpty) return null;
    // ignore: deprecated_member_use_from_same_package
    return forTown(town);
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  ⚠ THIN CELLS READ THEIR NEIGHBOURS. Added 30 August 2026.
  //
  //  The grid shipped with a FIXED 15km reach, which treats the Highlands
  //  exactly like Zone 1. In central London 15km is generous. In mid Wales it
  //  is nothing, and the guest got the same tidy empty state this whole rewrite
  //  exists to abolish. One silent miss was replaced with a quieter one.
  //
  //  ⚠ THE FIX IS ON THE CLIENT, NOT THE SERVER, AND THAT IS THE POINT. Making
  //  the server search wider in the countryside means more load on Overpass,
  //  which is donated, and bigger documents for everyone. The data is ALREADY
  //  in the cells next door, because every cell is built with a 15km overlap.
  //  Reading them costs nothing but Firestore reads.
  //
  //  ⚠ AND THE COST LANDS WHERE THERE ARE FEWEST GUESTS. Nine reads instead of
  //  one, only in empty countryside. Density and cost scale in opposite
  //  directions, which is the right way round: nobody pays nine reads for a
  //  property in Manchester, because Manchester is never thin.
  //
  //  ⚠ AN UNBUILT CELL DOES NOT TRIGGER THIS. "The sweep has not reached here
  //  yet" and "here is genuinely quiet" are different facts, and only the
  //  second one is answered by looking next door. The first falls through to
  //  the old town document instead.
  // ───────────────────────────────────────────────────────────────────────────

  /// Below this many days out, a cell is treated as thin and widened.
  ///
  /// Six is roughly a screenful. Fewer than that and a guest is looking at a
  /// list short enough to make them wonder whether it loaded.
  static const int _thinThreshold = 6;

  /// Rows and columns in the grid.
  ///
  /// ⚠ DERIVED, NOT TYPED IN. Writing 48 and 22 here would be a fourth place
  /// the grid's shape is recorded, and the first to fall out of step the day
  /// anybody adjusts an origin. `static final` is computed once on first use.
  static final int _gridRows = ((_gridLat1 - _gridLat0) / _gridDLat).ceil();
  static final int _gridCols = ((_gridLng1 - _gridLng0) / _gridDLng).ceil();

  /// The most day outs a widened cell may end up holding.
  ///
  /// ── ⚠ THIS BOUNDS THE MERGE, NOT THE DOWNLOAD ───────────────────────────
  ///
  ///  Firestore has no partial document read, so the nine documents arrive
  ///  whole whatever we do with them afterwards. The case that costs is a thin
  ///  cell next to a dense one, say rural Kent beside London, where widening
  ///  pulls a couple of hundred day outs across mobile data.
  ///
  ///  ⚠ IT IS STILL WORTH DOING. A guest in that cell genuinely wants London's
  ///  list, and this happens once per session because the result is cached.
  ///  What is NOT worth doing is then holding and sorting eighteen hundred
  ///  clusters on a phone to render a screen nobody scrolls past the top of.
  ///
  ///  Sixty nearest is far more than anybody reads and small enough to be free.
  static const int _mergedCap = 60;

  /// Read one cell, widening to its neighbours when it comes back thin.
  ///
  /// [lat] and [lng] are the property's own position, used only to decide
  /// which of the merged day outs to keep. Without them the trim would be
  /// arbitrary, so it is skipped entirely rather than guessed at.
  Future<StayAttractions?> _readCell(
      String cell, double? lat, double? lng) async {
    final DocumentSnapshot<Map<String, dynamic>> doc =
        await _db.collection('stay_attractions_grid').doc(cell).get();
    final Map<String, dynamic>? data = doc.data();
    if (!doc.exists || data == null) return null;

    final StayAttractions home = StayAttractions.fromMap(data);
    if (home.clusters.length >= _thinThreshold) return home;

    final RegExpMatch? m = RegExp(r'^g(\d+)_(\d+)$').firstMatch(cell);
    if (m == null) return home;
    final int row = int.parse(m.group(1)!);
    final int col = int.parse(m.group(2)!);

    // All eight surrounding cells, not just the four cardinal ones. A property
    // in the corner of its cell has a diagonal neighbour closer than two of
    // its edge neighbours.
    final List<String> ids = <String>[];
    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final int r = row + dr;
        final int c = col + dc;
        if (r < 0 || c < 0 || r >= _gridRows || c >= _gridCols) continue;
        ids.add('g${r}_$c');
      }
    }
    if (ids.isEmpty) return home;

    List<DocumentSnapshot<Map<String, dynamic>>> snaps;
    try {
      snaps = await Future.wait(ids.map((String id) =>
          _db.collection('stay_attractions_grid').doc(id).get()));
    } catch (_) {
      // Widening is a bonus, never a requirement. If the neighbours cannot be
      // read the guest still gets their own cell rather than an error.
      return home;
    }

    // ⚠ DEDUPED BY CLUSTER ID. Every cell is built with a 15km overlap, so a
    // museum near a boundary is genuinely present in several documents under
    // the same id. Without this the guest sees it three times.
    final Map<String, StayCluster> merged = <String, StayCluster>{};
    for (final StayCluster c in home.clusters) {
      merged[c.id] = c;
    }
    for (final DocumentSnapshot<Map<String, dynamic>> s in snaps) {
      final Map<String, dynamic>? d = s.data();
      if (!s.exists || d == null) continue;
      for (final StayCluster c in StayAttractions.fromMap(d).clusters) {
        merged.putIfAbsent(c.id, () => c);
      }
    }

    List<StayCluster> out = merged.values.toList();

    // ⚠ TRIMMED TO THE NEAREST, NOT THE FIRST FOUND. Map order here is home
    // cell then neighbours in grid order, which has nothing to do with how
    // far anything is from the guest. Cutting without sorting would keep an
    // arbitrary sixty and could drop the closest one in the set.
    if (lat != null && lng != null && out.length > _mergedCap) {
      out = nearest(out, lat, lng).take(_mergedCap).toList();
    }

    return StayAttractions(
      // Keeps the home cell's identity. The guest is in this cell; the
      // neighbours are only where some of the answers came from.
      city: home.city,
      cityName: home.cityName,
      clusters: List<StayCluster>.unmodifiable(out),
      attribution: home.attribution,
      attributionUrl: home.attributionUrl,
    );
  }

  /// Same slug rule as the server: lowercase, letters only.
  ///
  /// ⚠ MUST MATCH slugify() IN short_stay.js. "Newcastle upon Tyne" has to
  /// become "newcastleupontyne" on both sides or the lookup silently misses and
  /// the screen shows an empty state for a city we have data for.
  @Deprecated('Superseded by cellIdFor. Removed once the grid sweep completes.')
  static String slugFor(String town) =>
      town.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

  /// The days out for a town, or null when we have not built that city.
  ///
  /// ⚠ THE OLD LOOKUP, KEPT ONLY UNTIL THE GRID SWEEP FINISHES. It cannot cover
  /// the country: see the block above [cellIdFor]. Nothing new should call it.
  @Deprecated('Use forProperty. Removed once the grid sweep completes.')
  Future<StayAttractions?> forTown(String town) async {
    // ignore: deprecated_member_use_from_same_package
    final String slug = slugFor(town);
    if (slug.isEmpty) return null;
    final String key = 'town:$slug';
    if (_cache.containsKey(key)) return _cache[key];

    try {
      final DocumentSnapshot<Map<String, dynamic>> doc =
          await _db.collection('stay_attractions').doc(slug).get();
      final Map<String, dynamic>? data = doc.data();
      final StayAttractions? out =
          (doc.exists && data != null) ? StayAttractions.fromMap(data) : null;
      _cache[key] = out;
      return out;
    } catch (_) {
      // Deliberately not cached. A network failure should be retried on the
      // next open; a missing city should not.
      return null;
    }
  }

  /// One cluster by id, for the detail screen.
  ///
  /// Takes the property's position as well as the id because clusters live
  /// inside a cell document. Passing only an id would mean scanning the country.
  Future<StayCluster?> cluster(
    String clusterId, {
    double? lat,
    double? lng,
    String town = '',
  }) async {
    final StayAttractions? a =
        await forProperty(lat: lat, lng: lng, town: town);
    if (a == null) return null;
    for (final StayCluster c in a.clusters) {
      if (c.id == clusterId) return c;
    }
    return null;
  }

  /// Straight line miles between two points.
  ///
  /// ⚠ THE SAME MATHS AS milesBetween() IN short_stay.js AND
  /// stay_attractions.js, and it must stay that way. A distance computed one
  /// way on the server and another on the client is a number that disagrees
  /// with itself depending on which screen you are looking at.
  ///
  /// ⚠ STRAIGHT LINE, NOT A ROUTE. The screens say miles and never minutes,
  /// because we have no routing API and a walk is not a straight line.
  static double milesBetween(
      double lat1, double lng1, double lat2, double lng2) {
    const double earthMi = 3958.7613;
    double rad(double d) => d * math.pi / 180;
    final double dLat = rad(lat2 - lat1);
    final double dLng = rad(lng2 - lng1);
    final double a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(lat1)) *
            math.cos(rad(lat2)) *
            math.pow(math.sin(dLng / 2), 2);
    return earthMi * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  /// Clusters ordered by how far they are from a property.
  ///
  /// Returns them unsorted when the property has no coordinates, rather than
  /// dropping them: a list in the builder's order is still useful, and a guest
  /// staying somewhere we failed to geocode should not lose the whole screen.
  static List<StayCluster> nearest(
      List<StayCluster> clusters, double? lat, double? lng) {
    if (lat == null || lng == null) return clusters;
    final List<StayCluster> out = List<StayCluster>.from(clusters);
    out.sort((a, b) => milesBetween(lat, lng, a.lat, a.lng)
        .compareTo(milesBetween(lat, lng, b.lat, b.lng)));
    return out;
  }
}
