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
  Future<List<StayListing>> mostPartnersNearby({int limit = 10}) async {
    final q = await _col
        .where('status', isEqualTo: 'live')
        .orderBy('locationContext.partnerCounts.halfMile', descending: true)
        .limit(limit)
        .get();
    return q.docs.map(StayListing.fromDoc).toList(growable: false);
  }

  Future<List<StayListing>> byIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    // whereIn caps at 30. Chunk rather than silently truncating.
    final out = <StayListing>[];
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final q = await _col.where(FieldPath.documentId, whereIn: chunk).get();
      out.addAll(q.docs.map(StayListing.fromDoc));
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
