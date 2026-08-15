// ─────────────────────────────────────────────────────────────────────────────
//  Reworked 3 August 2026 as Stage 1 of the /users hardening.
//
//  This file used to read and write OTHER people's user documents directly:
//  it searched the whole users collection by phone number, read each member's
//  document one by one, and wrote familyGroupId onto the person who sent an
//  invite. All of that only worked because firestore.rules let any signed-in
//  account read and write user documents, which also exposed every user's
//  address, date of birth and hashed pin to anyone who registered.
//
//  Everything touching another user now goes through a Cloud Function, and the
//  family screen reads ONE group document instead of one document per member.
//  See admin_panel/functions/public_profiles.js.
//
//  If you are about to add a call to collection('users').doc(someoneElse) in
//  this file, that is the thing this change removed. Add a function instead.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FamilyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // europe-west1 to match every other function in this project. A mismatch
  // here does not fail to compile, it fails at runtime with NOT_FOUND.
  final FirebaseFunctions _fn =
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  String? get _uid => _auth.currentUser?.uid;

  // ─────────────────────────────────────────────────────────────────────────
  // FAMILY GROUP — READ
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns the current user's family group data, or null if not in a group.
  Future<Map<String, dynamic>?> getMyFamilyGroup() async {
    if (_uid == null) return null;
    final userDoc = await _db.collection('users').doc(_uid).get();
    final groupId = userDoc.data()?['familyGroupId'] as String?;
    if (groupId == null) return null;

    final groupDoc = await _db.collection('familyGroups').doc(groupId).get();
    if (!groupDoc.exists) return null;
    return {'id': groupDoc.id, ...groupDoc.data()!};
  }

  /// Returns a live stream of the family group document.
  Stream<Map<String, dynamic>?> watchFamilyGroup(String groupId) {
    return _db
        .collection('familyGroups')
        .doc(groupId)
        .snapshots()
        .map((snap) => snap.exists ? {'id': snap.id, ...snap.data()!} : null);
  }

  /// Members of the group, taken from the group document itself.
  ///
  /// Pass the map returned by [getMyFamilyGroup] or [watchFamilyGroup].
  ///
  /// This used to fetch every member's FULL user document in a loop, which
  /// meant N reads and handed the caller each member's address, date of birth,
  /// kycStatus, wallet balance and hashed pin just to draw a name and a total.
  ///
  /// syncFamilyGroupMembers now maintains a `memberSummaries` map inside the
  /// group document holding only what this screen shows, so it is one read and
  /// nothing private travels.
  List<Map<String, dynamic>> getFamilyMembers(Map<String, dynamic>? group) {
    if (group == null) return const [];

    final summaries =
        (group['memberSummaries'] as Map?)?.cast<String, dynamic>() ?? {};
    final order = List<String>.from(group['memberUids'] as List? ?? []);

    final List<Map<String, dynamic>> members = [];
    for (final uid in order) {
      final s = (summaries[uid] as Map?)?.cast<String, dynamic>();

      // A member with no summary yet is normal for a few seconds after the
      // group changes, and permanent for groups created before this shipped
      // until the backfill runs. Show the row rather than dropping the person.
      members.add({
        'uid': uid,
        'fullName': s?['fullName'] ?? 'Family Member',
        'phone': s?['phone'] ?? '',
        'totalCashbackEarned':
            (s?['totalCashbackEarned'] as num?)?.toDouble() ?? 0.0,
        'familyRole': s?['familyRole'] ?? 'member',
        'gooutsPlusMember': s?['gooutsPlusMember'] ?? false,
        'photoUrl': s?['photoUrl'] ?? '',
      });
    }
    return members;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PHONE NUMBER SEARCH
  // ─────────────────────────────────────────────────────────────────────────

  /// Look up a GoOuts user by phone number, to invite them to a family group.
  ///
  /// This ran as a client side query over the whole users collection:
  ///     collection('users').where('phone', isEqualTo: normalised)
  ///
  /// Beyond needing open read access, that was a user enumeration hole. Anyone
  /// could work through a range of mobile numbers, learn which ones have a
  /// GoOuts account, and get the account holder's real name for each hit.
  ///
  /// findFamilyCandidateByPhone answers only what the invite screen needs:
  /// is there an account, and is that person already in a group.
  ///
  /// Note the normalisation moved server side too, so the client and the
  /// lookup can no longer disagree about what +44 7xxx means.
  Future<Map<String, dynamic>?> findUserByPhone(String phone) async {
    try {
      final res = await _fn
          .httpsCallable('findFamilyCandidateByPhone')
          .call<Map<String, dynamic>>({'phone': phone});

      final d = res.data;
      if (d['found'] != true) return null;

      return {
        'uid': d['uid'],
        'fullName': d['displayName'] ?? 'GoOuts User',
        // The phone is the one the caller typed. The server no longer returns
        // it, because echoing back a number confirms the account exists.
        'phone': phone,
        // A bool now, not the group id. Callers only ever tested it for null.
        'inFamilyGroup': d['inFamilyGroup'] == true,
      };
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LINK REQUESTS — SEND
  // ─────────────────────────────────────────────────────────────────────────

  /// Send a family link request to another GoOuts user.
  /// Returns an error message string, or null on success.
  /// Now a Cloud Function. Two reasons.
  ///
  /// It read the RECIPIENT's user document to check whether they were already
  /// in a group, which needs open read access on /users.
  ///
  /// And it stamped `fromName` and `fromPhone` from client held data, so the
  /// invite that appeared in someone's list carried whatever name the sender's
  /// device supplied. The server now takes both from its own copy of the
  /// sender, which is the only version that cannot be edited.
  ///
  /// Returns an error message, or null on success. Same contract as before.
  Future<String?> sendLinkRequest({
    required String toUid,
    required String toPhone,
  }) async {
    if (_uid == null) return 'You are not logged in.';
    try {
      final res = await _fn
          .httpsCallable('sendFamilyLinkRequest')
          .call<Map<String, dynamic>>({'toUid': toUid});

      if (res.data['ok'] == true) return null;
      return res.data['message'] as String? ?? 'Could not send that request.';
    } on FirebaseFunctionsException catch (e) {
      return e.message ?? 'Could not send that request.';
    } catch (_) {
      return 'Could not send that request. Check your connection.';
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LINK REQUESTS — RECEIVE
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns all pending link requests sent TO the current user.
  Future<List<Map<String, dynamic>>> getIncomingRequests() async {
    if (_uid == null) return [];
    try {
      final snap = await _db
          .collection('familyLinkRequests')
          .where('toUid', isEqualTo: _uid)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();

      return snap.docs.map((doc) {
        final data = doc.data();
        return {
          'requestId': doc.id,
          'fromUid': data['fromUid'] ?? '',
          'fromName': data['fromName'] ?? 'GoOuts User',
          'fromPhone': data['fromPhone'] ?? '',
          'createdAt': data['createdAt'],
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Stream of incoming pending requests — for real-time badge in Profile.
  Stream<int> watchIncomingRequestCount() {
    if (_uid == null) return Stream.value(0);
    return _db
        .collection('familyLinkRequests')
        .where('toUid', isEqualTo: _uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LINK REQUESTS — ACCEPT
  // ─────────────────────────────────────────────────────────────────────────

  /// Accept a family link request. Now a Cloud Function.
  ///
  /// The version this replaces wrote `familyGroupId` and `familyRole` onto the
  /// SENDER's user document. Once /users is owner-write-only that is denied, so
  /// this had to move server side no matter what.
  ///
  /// It also fixes a race that was live. The old code read the group, checked
  /// the member count, then wrote, as four separate operations. Two people
  /// accepting into the last seat at the same moment both passed the check and
  /// both got in, leaving a group of four with a maxMembers of three.
  /// acceptFamilyLinkRequest does the whole thing in one transaction.
  ///
  /// And the £100 milestone is now decided by the server. It used to be
  /// computed on the accepting device from two client read totals.
  ///
  /// Returns an error message, or null on success. Same contract as before.
  Future<String?> acceptLinkRequest(String requestId) async {
    if (_uid == null) return 'Not logged in.';
    try {
      await _fn
          .httpsCallable('acceptFamilyLinkRequest')
          .call<Map<String, dynamic>>({'requestId': requestId});
      return null;
    } on FirebaseFunctionsException catch (e) {
      return e.message ?? 'Could not accept that request.';
    } catch (_) {
      return 'Could not accept that request. Check your connection.';
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LINK REQUESTS — DECLINE
  // ─────────────────────────────────────────────────────────────────────────

  /// Decline a family link request.
  Future<void> declineLinkRequest(String requestId) async {
    await _db
        .collection('familyLinkRequests')
        .doc(requestId)
        .update({'status': 'declined'});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LEAVE GROUP
  // ─────────────────────────────────────────────────────────────────────────

  /// Leave the current family group.
  Future<void> leaveGroup() async {
    if (_uid == null) return;

    final userDoc = await _db.collection('users').doc(_uid).get();
    final groupId = userDoc.data()?['familyGroupId'] as String?;
    if (groupId == null) return;

    // Remove from group member list
    await _db.collection('familyGroups').doc(groupId).update({
      'memberUids': FieldValue.arrayRemove([_uid]),
    });

    // Clear user's group reference
    await _db.collection('users').doc(_uid).update({
      'familyGroupId': null,
      'familyRole': null,
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GOOUTS PLUS — ACTIVATE
  // ─────────────────────────────────────────────────────────────────────────

  /// Activate GoOuts Plus for the whole family group. Now a Cloud Function,
  /// because it writes `gooutsPlusMember` onto every OTHER member's document.
  ///
  /// It also used the DEVICE clock for the activation and renewal dates. A
  /// renewal date set from a phone whose clock is wrong, or has been set
  /// forward deliberately, is a paid subscription that expires whenever the
  /// holder likes. The server sets both now.
  ///
  /// ⚠ THIS STILL DOES NOT VERIFY PAYMENT, and neither did the code it
  ///   replaces. The purchase screen checks its own result and then calls
  ///   this. Moving the write server side stops one member's device granting
  ///   Plus to everyone else, but a direct call to the function is still
  ///   possible. Closing that means checking a server side purchase record,
  ///   which belongs with the Stripe work in task 99.
  ///
  /// The groupId argument is ignored: the server uses the caller's own group,
  /// so nobody can activate Plus for a group they are not in. It is kept in
  /// the signature so the existing call site did not need changing.
  Future<void> activatePlusForGroup(String groupId) async {
    await _fn
        .httpsCallable('activateFamilyPlus')
        .call<Map<String, dynamic>>(<String, dynamic>{});
  }
}
