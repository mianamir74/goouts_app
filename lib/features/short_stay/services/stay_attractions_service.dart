import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/stay_attraction.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Reading days out.
//
//  Written 28 August 2026.
//
//  ── ⚠ ONE DOCUMENT PER CITY, AND IT IS CACHED FOR THE SESSION ───────────────
//
//  stay_attractions/{citySlug} holds every day out for a city. Two hundred
//  listings in Birmingham read the same document, which is the whole reason the
//  data is built per city rather than per property.
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

  /// citySlug -> the city's days out. Null value means "asked, nothing there",
  /// which is cached too so a city with no data is not re-read all session.
  final Map<String, StayAttractions?> _cache = <String, StayAttractions?>{};

  /// Same slug rule as the server: lowercase, letters only.
  ///
  /// ⚠ MUST MATCH slugify() IN short_stay.js. "Newcastle upon Tyne" has to
  /// become "newcastleupontyne" on both sides or the lookup silently misses and
  /// the screen shows an empty state for a city we have data for.
  static String slugFor(String town) =>
      town.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

  /// The days out for a town, or null when we have not built that city.
  ///
  /// Never throws. A failed read shows the empty state, which is the same thing
  /// the guest sees for a city we have not built, and neither is worth an error
  /// dialog on a browsing screen.
  Future<StayAttractions?> forTown(String town) async {
    final String slug = slugFor(town);
    if (slug.isEmpty) return null;
    if (_cache.containsKey(slug)) return _cache[slug];

    try {
      final DocumentSnapshot<Map<String, dynamic>> doc =
          await _db.collection('stay_attractions').doc(slug).get();
      final Map<String, dynamic>? data = doc.data();
      final StayAttractions? out =
          (doc.exists && data != null) ? StayAttractions.fromMap(data) : null;
      _cache[slug] = out;
      return out;
    } catch (_) {
      // Deliberately not cached. A network failure should be retried on the
      // next open; a missing city should not.
      return null;
    }
  }

  /// One cluster by id, for the detail screen.
  ///
  /// Takes the town as well as the id because clusters live inside a city
  /// document. Passing only an id would mean scanning every city.
  Future<StayCluster?> cluster(String town, String clusterId) async {
    final StayAttractions? a = await forTown(town);
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
