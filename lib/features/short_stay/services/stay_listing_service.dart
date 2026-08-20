import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/stay_listing.dart';

/// Reads listings. Writes are host side and live in GoOuts Business, not here.
///
/// EVERY QUERY HAS A LIMIT. An unbounded snapshots() on listings will read the
/// whole collection on every change, which is slow, expensive, and on a large
/// collection is a way to run the app out of memory.
class StayListingService {
  StayListingService._();
  static final instance = StayListingService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('stay_listings');

  Future<StayListing?> byId(String id) async {
    if (id.isEmpty) return null;
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return StayListing.fromDoc(doc);
  }

  Stream<StayListing?> watch(String id) => _col.doc(id).snapshots().map(
      (d) => d.exists ? StayListing.fromDoc(d) : null);

  /// The "most GoOuts partners nearby" rail on the home screen. This is the
  /// differentiator, and it is a plain field read because the counts are
  /// precomputed by enrichListingLocation. No geo query at runtime.
  /// Live listings, best first by how many GoOuts partners are within half a
  /// mile. Drives the Short Stay home screen.
  ///
  /// ── TWO WAYS THIS SILENTLY RETURNED NOTHING ────────────────────────────
  ///
  /// Found 16 August 2026, when screen 01 was finally wired to it. This method
  /// was written on 4 August and never called by anything, so neither fault
  /// had ever been observed.
  ///
  /// 1. NO INDEX. An equality filter on `status` plus an orderBy on a
  ///    different field needs a composite index, and no stay_listings index
  ///    existed in firestore.indexes.json at all. Every call would have thrown
  ///    FAILED_PRECONDITION. One is added now, but a newly deployed index
  ///    takes minutes to build and the screen must work meanwhile.
  ///
  /// 2. orderBy EXCLUDES DOCUMENTS MISSING THE FIELD. locationContext is
  ///    written by enrichListingLocation after a listing goes live, so a
  ///    property whose location has not been computed yet is not merely last
  ///    in this list — it is absent from it. A freshly seeded set could return
  ///    an empty home screen while every property sat there live and
  ///    bookable.
  ///
  /// So the ordered query is attempted, and ANY shortfall — an error, or fewer
  /// results than asked for — falls back to plain live listings. Ordering is a
  /// nicety; showing the properties at all is not.
  Future<List<StayListing>> mostPartnersNearby({int limit = 10}) async {
    List<StayListing> ranked = const [];
    try {
      final q = await _col
          .where('status', isEqualTo: 'live')
          .orderBy('locationContext.partnerCounts.halfMile', descending: true)
          .limit(limit)
          .get();
      ranked = StayListing.parseAll(q.docs);
      if (ranked.length >= limit) return ranked;
    } catch (_) {
      // Index missing or still building. Fall through.
    }

    final plain = await _col
        .where('status', isEqualTo: 'live')
        .limit(limit)
        .get();
    final all = StayListing.parseAll(plain.docs).toList();

    // Keep the ranked ones in front, then append anything the ordered query
    // could not see, without repeating a listing that appears in both.
    final seen = ranked.map((l) => l.id).toSet();
    return <StayListing>[
      ...ranked,
      ...all.where((l) => !seen.contains(l.id)),
    ].take(limit).toList(growable: false);
  }

  Future<List<StayListing>> byIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    // whereIn caps at 30. Chunk rather than silently truncating.
    final out = <StayListing>[];
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final q = await _col.where(FieldPath.documentId, whereIn: chunk).get();
      out.addAll(StayListing.parseAll(q.docs));
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> reviews(String listingId,
      {int limit = 3}) async {
    final q = await _col
        .doc(listingId)
        .collection('reviews')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return q.docs.map((d) => {'id': d.id, ...d.data()}).toList(growable: false);
  }

  // ── Saved listings. The only listing related write a guest may make. ──────
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<void> setSaved(String listingId, bool saved) async {
    final uid = _uid;
    if (uid == null || listingId.isEmpty) return;
    final ref = _db
        .collection('users')
        .doc(uid)
        .collection('saved_stays')
        .doc(listingId);
    if (saved) {
      await ref.set({'savedAt': FieldValue.serverTimestamp()});
    } else {
      await ref.delete();
    }
  }

  Stream<bool> watchSaved(String listingId) {
    final uid = _uid;
    if (uid == null || listingId.isEmpty) return Stream.value(false);
    return _db
        .collection('users')
        .doc(uid)
        .collection('saved_stays')
        .doc(listingId)
        .snapshots()
        .map((d) => d.exists);
  }
}
