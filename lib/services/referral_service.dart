// ─────────────────────────────────────────────────────────────────────────────
//  Reworked 3 August 2026 as Stage 1 of the /users hardening.
//
//  Three operations here used to query the WHOLE users collection: allocating
//  an invite code, resolving one, and listing who you referred. All three
//  needed firestore.rules to let any signed-in account read any user document,
//  which is what exposed every user's address, date of birth and hashed pin.
//
//  They are now a document read, a callable, and a subcollection under the
//  caller's own document. See admin_panel/functions/public_profiles.js.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReferralService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // europe-west1 to match every other function in this project.
  final FirebaseFunctions _fn =
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  // ── Save invite code on user document (called once at registration) ───────
  //
  // Now a Cloud Function, and it fixes a race that was live.
  //
  // The old version generated a code, queried the users collection to see if
  // anyone had it, and then wrote it. Read, then write, as two operations.
  // Two people registering in the same second generated the same code, both
  // saw it free, and both kept it. From then on that code resolved to
  // whichever document the query returned first, so one of them silently
  // stopped earning referrals and there was nothing on either account to
  // show why.
  //
  // ensureInviteCode uses the code as a document ID under /invite_codes and
  // calls create(), which fails if the ID is taken. Uniqueness and
  // reservation become one operation that cannot interleave.
  //
  // Note: nothing ever called saveInviteCode. The real allocation happened in
  // UserService at registration, with no uniqueness check at all, so duplicate
  // codes were possible and the check here was never reached. Kept as a thin
  // wrapper because it is public API, but getMyInviteCode is the live path.
  Future<void> saveInviteCode(String uid) => _ensure();

  /// Allocates the caller's invite code if they do not have one, and returns
  /// it. Safe to call repeatedly: the function returns the existing code
  /// rather than issuing a second one.
  Future<String?> _ensure() async {
    try {
      final res = await _fn
          .httpsCallable('ensureInviteCode')
          .call<Map<String, dynamic>>(<String, dynamic>{});
      return res.data['code'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ── Look up a referrer by their invite code ───────────────────────────────
  //
  // Was a query over every user document by inviteCode. Now one document read
  // inside a function, against the /invite_codes map.
  Future<String?> getReferrerUid(String inviteCode) async {
    final code = inviteCode.trim().toUpperCase();
    if (code.isEmpty) return null;
    try {
      final res = await _fn
          .httpsCallable('resolveInviteCode')
          .call<Map<String, dynamic>>({'code': code});
      if (res.data['found'] != true) return null;
      return res.data['referrerUid'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ── Save referredBy on the new user doc ───────────────────────────────────
  Future<void> saveReferredBy(String referrerUid) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).update({
      'referredByUid': referrerUid,
      'referralRewarded': false,
    });
  }

  // ── Fetch current user's invite code ─────────────────────────────────────
  //
  // Allocates one on first read. Registration no longer sets inviteCode, so a
  // user who never opens the refer screen never consumes a code, and everyone
  // who does gets one reserved atomically.
  //
  // This also self heals accounts created before ensureInviteCode existed
  // whose code was never mapped into /invite_codes.
  Future<String?> getMyInviteCode() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _db.collection('users').doc(uid).get();
    final existing = doc.data()?['inviteCode'] as String?;
    if (existing != null && existing.isNotEmpty) return existing;
    return _ensure();
  }

  // ── Fetch referral stats for current user ────────────────────────────────
  //
  // Reads the caller's OWN referrals subcollection, maintained by
  // syncReferralIndex. See admin_panel/functions/public_profiles.js.
  //
  // This used to run
  //     collection('users').where('referredByUid', isEqualTo: uid)
  // which is a query across EVERY user document in the platform. Two problems.
  //
  // It needed open read access on /users, and Firestore has no way to return
  // "only the fields I am allowed to see", so the device received each
  // referred user's entire document: address, phone, date of birth, wallet
  // balance, hashed pin. To draw a name and a tick.
  //
  // It also got slower and more expensive for everyone as the user base grew,
  // because the cost of that query scales with the number of users on GoOuts,
  // not the number of people this person actually referred.
  Future<Map<String, dynamic>> getReferralStats() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return {'count': 0, 'earned': 0.0, 'referrals': []};

    try {
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('referrals')
          .get();

      final referrals = snap.docs.map((doc) {
        final data = doc.data();
        return {
          'name': data['displayName'] as String? ?? 'GoOuts User',
          'rewarded': data['rewarded'] as bool? ?? false,
          'joinedAt': data['joinedAt'],
        };
      }).toList();

      final rewardedCount = referrals.where((r) => r['rewarded'] == true).length;
      final totalEarned = rewardedCount * 2.0;

      return {
        'count': referrals.length,
        'rewarded': rewardedCount,
        'earned': totalEarned,
        'referrals': referrals,
      };
    } catch (_) {
      return {'count': 0, 'rewarded': 0, 'earned': 0.0, 'referrals': []};
    }
  }
}
