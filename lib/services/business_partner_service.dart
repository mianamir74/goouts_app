import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  "Become a Partner" application service.
//
//  Added 11 September 2026 alongside become_a_partner_screen.dart, per
//  design/PARTNER_ECOSYSTEM_ARCHITECTURE.md §2 and §7 step 3.
//
//  Writes to /businesses — the collection for REAL operating businesses
//  (restaurants, venues, shops, short-stay hosts). This is NOT the same
//  thing as /lead_partners, which is the unrelated driver referral role;
//  that name collision is exactly what the 11 September 2026 rename fixed,
//  which is why /businesses was free for this.
//
//  Every application is born 'pending'. firestore.rules enforces this
//  server-side (a create() must carry status == 'pending' and the caller's
//  own uid as ownerUid) so this is a real constraint, not just client
//  discipline — a modified client cannot self-approve.
//
//  ⚠ PAYOUT IS A DELIBERATE EMPTY PLACEHOLDER. No payout/bank-detail logic
//  is built here, or anywhere in this pass — that is a standing GoOuts rule
//  (see design doc §5: GoOuts never holds or moves funds itself, and never
//  stores bank details in an app). firestore.rules also blocks a client
//  from ever writing into 'payout' on a later update, so this is not just
//  "not built yet" — it is actively fenced off.
// ─────────────────────────────────────────────────────────────────────────────
class BusinessPartnerService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _businesses =>
      _db.collection('businesses');

  /// Submits a new business application for the signed-in consumer.
  ///
  /// [lines] must be a non-empty subset of `['food', 'stay', 'instore']` —
  /// which line-specific detail map (food/stay/instore) actually gets
  /// written mirrors [lines] exactly, per the design doc's "only present if
  /// X in lines" shape. Returns the new document's id.
  ///
  /// Throws a [StateError] if nobody is signed in. become_a_partner_screen
  /// is only reachable from inside the already-signed-in consumer app, so
  /// this should never actually happen — but a clear exception here beats a
  /// silent write with a null owner that nobody would understand later.
  Future<String> submitApplication({
    required String legalName,
    String? tradingName,
    required List<String> lines,
    required Map<String, dynamic> address,
    Map<String, dynamic>? geo,
    Map<String, dynamic>? food,
    Map<String, dynamic>? stay,
    Map<String, dynamic>? instore,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw StateError(
          'No signed-in user — cannot submit a business application.');
    }
    if (lines.isEmpty) {
      throw ArgumentError('Select at least one business type.');
    }

    final Map<String, dynamic> data = <String, dynamic>{
      'ownerUid': user.uid,
      'legalName': legalName,
      'tradingName': tradingName ?? '',
      'address': address,
      'geo': geo ?? <String, dynamic>{},
      'lines': lines,
      // Never anything but 'pending' from the client. firestore.rules
      // enforces this too — belt and braces, not decoration.
      'status': 'pending',
      if (lines.contains('food')) 'food': food ?? <String, dynamic>{},
      if (lines.contains('stay')) 'stay': stay ?? <String, dynamic>{},
      if (lines.contains('instore')) 'instore': instore ?? <String, dynamic>{},
      // Placeholders, deliberately empty — see the file header above.
      'compliance': <String, dynamic>{},
      'payout': <String, dynamic>{},
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final DocumentReference<Map<String, dynamic>> ref =
        await _businesses.add(data);
    return ref.id;
  }

  /// Returns the current user's existing business application, if any is
  /// 'pending' or 'verified', so the screen can show a status state instead
  /// of the form again. Returns null if the user has never applied, or if
  /// every past application of theirs is 'suspended' — a suspension is not
  /// "still under review", so it does not block a fresh application.
  ///
  /// Note: this query (ownerUid == caller AND status in [...]) may need a
  /// Firestore composite index in production; Firestore's own error message
  /// links directly to creating it the first time this runs against a real
  /// project.
  Future<Map<String, dynamic>?> getExistingApplication() async {
    final User? user = _auth.currentUser;
    if (user == null) return null;

    // ⚠ Any failure here (most likely the composite index above not existing
    // yet in a given Firestore project, but also just network failure) must
    // be treated the same as "no existing application found" rather than
    // propagating — become_a_partner_screen's caller would otherwise be left
    // with an uncaught exception and an infinite loading spinner instead of
    // the form. Logged for debugging, never shown to the user.
    try {
      final QuerySnapshot<Map<String, dynamic>> snap = await _businesses
          .where('ownerUid', isEqualTo: user.uid)
          .where('status', whereIn: <String>['pending', 'verified'])
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return null;
      final QueryDocumentSnapshot<Map<String, dynamic>> doc = snap.docs.first;
      return <String, dynamic>{'id': doc.id, ...doc.data()};
    } catch (e) {
      debugPrint('BusinessPartnerService getExistingApplication error: $e');
      return null;
    }
  }

  /// Convenience boolean form of [getExistingApplication], for call sites
  /// that only need to know whether to show the form or not.
  Future<bool> hasExistingApplication() async {
    final result = await getExistingApplication();
    return result != null;
  }
}
