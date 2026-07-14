import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReferralService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── Generate a unique invite code ─────────────────────────────────────────
  /// Format: GO + 6 alphanumeric chars (uppercase). e.g. GOAX72KP
  static String generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O/1/I confusion
    final rng = Random.secure();
    final suffix = List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
    return 'GO$suffix';
  }

  // ── Save invite code on user document (called once at registration) ───────
  Future<void> saveInviteCode(String uid) async {
    // Check if already set (avoid overwriting)
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.data()?['inviteCode'] != null) return;

    String code;
    bool unique = false;

    // Retry until unique (collision extremely unlikely but guard anyway)
    do {
      code = generateInviteCode();
      final existing = await _db
          .collection('users')
          .where('inviteCode', isEqualTo: code)
          .limit(1)
          .get();
      unique = existing.docs.isEmpty;
    } while (!unique);

    await _db.collection('users').doc(uid).update({'inviteCode': code});
  }

  // ── Look up a referrer by their invite code ───────────────────────────────
  Future<String?> getReferrerUid(String inviteCode) async {
    final code = inviteCode.trim().toUpperCase();
    if (code.isEmpty) return null;
    try {
      final snap = await _db
          .collection('users')
          .where('inviteCode', isEqualTo: code)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      final referrerUid = snap.docs.first.id;
      // Cannot refer yourself
      final currentUid = _auth.currentUser?.uid;
      if (referrerUid == currentUid) return null;
      return referrerUid;
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
  Future<String?> getMyInviteCode() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data()?['inviteCode'] as String?;
  }

  // ── Fetch referral stats for current user ────────────────────────────────
  Future<Map<String, dynamic>> getReferralStats() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return {'count': 0, 'earned': 0.0, 'referrals': []};

    try {
      // All users who were referred by current user
      final snap = await _db
          .collection('users')
          .where('referredByUid', isEqualTo: uid)
          .get();

      final referrals = snap.docs.map((doc) {
        final data = doc.data();
        return {
          'name': data['fullName'] as String? ?? 'GoOuts User',
          'rewarded': data['referralRewarded'] as bool? ?? false,
          'joinedAt': data['createdAt'],
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
