import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FamilyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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

  /// Returns full user profiles for all members in the group.
  Future<List<Map<String, dynamic>>> getFamilyMembers(
      List<String> memberUids) async {
    if (memberUids.isEmpty) return [];
    final List<Map<String, dynamic>> members = [];
    for (final uid in memberUids) {
      try {
        final doc = await _db.collection('users').doc(uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          members.add({
            'uid': uid,
            'fullName': data['fullName'] ?? 'Family Member',
            'phone': data['phone'] ?? '',
            'totalCashbackEarned':
                (data['totalCashbackEarned'] as num?)?.toDouble() ?? 0.0,
            'familyRole': data['familyRole'] ?? 'member',
            'gooutsPlusMember': data['gooutsPlusMember'] ?? false,
          });
        }
      } catch (_) {}
    }
    return members;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PHONE NUMBER SEARCH
  // ─────────────────────────────────────────────────────────────────────────

  /// Search for a GoOuts user by phone number.
  /// Returns their basic profile or null if not found.
  Future<Map<String, dynamic>?> findUserByPhone(String phone) async {
    // Normalise: ensure it starts with +44 for UK numbers
    final normalised = _normalisePhone(phone);
    try {
      final snap = await _db
          .collection('users')
          .where('phone', isEqualTo: normalised)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return null;

      final doc = snap.docs.first;
      final data = doc.data();

      // Do not return your own profile
      if (doc.id == _uid) return null;

      return {
        'uid': doc.id,
        'fullName': data['fullName'] ?? 'GoOuts User',
        'phone': data['phone'] ?? '',
        'familyGroupId': data['familyGroupId'],
      };
    } catch (_) {
      return null;
    }
  }

  String _normalisePhone(String phone) {
    String p = phone.trim().replaceAll(' ', '');
    if (p.startsWith('07')) return '+44${p.substring(1)}';
    if (p.startsWith('7') && p.length == 10) return '+44$p';
    return p;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LINK REQUESTS — SEND
  // ─────────────────────────────────────────────────────────────────────────

  /// Send a family link request to another GoOuts user.
  /// Returns an error message string, or null on success.
  Future<String?> sendLinkRequest({
    required String toUid,
    required String toPhone,
  }) async {
    if (_uid == null) return 'You are not logged in.';

    // Check sender is not already in a group
    final senderDoc = await _db.collection('users').doc(_uid).get();
    final senderData = senderDoc.data()!;

    if (senderData['familyGroupId'] != null) {
      // Sender already has a group — check if there is space
      final groupId = senderData['familyGroupId'] as String;
      final groupDoc =
          await _db.collection('familyGroups').doc(groupId).get();
      final memberUids = List<String>.from(
          groupDoc.data()?['memberUids'] as List? ?? []);
      if (memberUids.length >= 3) {
        return 'Your family group is already full. You can have up to 3 members.';
      }
    }

    // Check recipient is not already in a group
    final recipientDoc = await _db.collection('users').doc(toUid).get();
    final recipientData = recipientDoc.data();
    if (recipientData?['familyGroupId'] != null) {
      return 'This person is already in a GoOuts family group.';
    }

    // Check no pending request already exists
    final existing = await _db
        .collection('familyLinkRequests')
        .where('fromUid', isEqualTo: _uid)
        .where('toUid', isEqualTo: toUid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return 'You already have a pending request to this person.';
    }

    // Send the request
    await _db.collection('familyLinkRequests').add({
      'fromUid': _uid,
      'fromName': senderData['fullName'] ?? 'A GoOuts User',
      'fromPhone': senderData['phone'] ?? '',
      'toUid': toUid,
      'toPhone': toPhone,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return null; // success
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

  /// Accept a family link request.
  /// Creates or joins the family group and links both users.
  Future<String?> acceptLinkRequest(String requestId) async {
    if (_uid == null) return 'Not logged in.';

    final requestDoc =
        await _db.collection('familyLinkRequests').doc(requestId).get();
    final requestData = requestDoc.data();
    if (requestData == null) return 'Request not found.';

    final String fromUid = requestData['fromUid'];
    final fromDoc = await _db.collection('users').doc(fromUid).get();
    final fromData = fromDoc.data()!;

    final String? existingGroupId =
        fromData['familyGroupId'] as String?;

    String groupId;

    if (existingGroupId != null) {
      // Join the existing group
      groupId = existingGroupId;
      await _db.collection('familyGroups').doc(groupId).update({
        'memberUids': FieldValue.arrayUnion([_uid]),
      });
    } else {
      // Create a new group with both users
      final meDoc = await _db.collection('users').doc(_uid).get();
      final myTotal =
          (meDoc.data()?['totalCashbackEarned'] as num?)?.toDouble() ?? 0.0;
      final theirTotal =
          (fromData['totalCashbackEarned'] as num?)?.toDouble() ?? 0.0;

      final newGroupRef = _db.collection('familyGroups').doc();
      groupId = newGroupRef.id;

      await newGroupRef.set({
        'primaryUid': fromUid,
        'memberUids': [fromUid, _uid],
        'combinedCashbackEarned': myTotal + theirTotal,
        'milestoneReached': (myTotal + theirTotal) >= 100.0,
        'milestoneReachedAt':
            (myTotal + theirTotal) >= 100.0 ? FieldValue.serverTimestamp() : null,
        'plusActivated': false,
        'plusActivatedAt': null,
        'plusRenewalDate': null,
        'maxMembers': 3,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update the sender (primary) with the new group ID
      await _db.collection('users').doc(fromUid).update({
        'familyGroupId': groupId,
        'familyRole': 'primary',
      });
    }

    // Update the accepting user (member)
    await _db.collection('users').doc(_uid).update({
      'familyGroupId': groupId,
      'familyRole': 'member',
    });

    // Mark request as accepted
    await _db
        .collection('familyLinkRequests')
        .doc(requestId)
        .update({'status': 'accepted'});

    return null; // success
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

  /// Activate GoOuts Plus for the whole family group.
  /// Updates the familyGroups document and all member user documents.
  Future<void> activatePlusForGroup(String groupId) async {
    final now = DateTime.now();
    final renewal = DateTime(now.year + 1, now.month, now.day);

    // Update group document
    await _db.collection('familyGroups').doc(groupId).update({
      'plusActivated': true,
      'plusActivatedAt': now,
      'plusRenewalDate': renewal,
    });

    // Update all members
    final groupDoc =
        await _db.collection('familyGroups').doc(groupId).get();
    final memberUids =
        List<String>.from(groupDoc.data()?['memberUids'] as List? ?? []);

    for (final uid in memberUids) {
      await _db.collection('users').doc(uid).update({
        'gooutsPlusMember': true,
        'gooutsPlusActivatedAt': now,
        'gooutsPlusRenewalDate': renewal,
      });
    }
  }
}
