import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/pin_hasher.dart';
import 'transaction_service.dart';
// referral_service import removed 3 August 2026: the only use was
// ReferralService.generateInviteCode() at registration, which allocated an
// invite code with no uniqueness check. Codes now come from ensureInviteCode.

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // europe-west1 to match every other function in this project.
  final FirebaseFunctions _fn =
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  /// Delete all documents in a sub-collection for the current user.
  /// Firestore .set() on a parent doc does NOT clear sub-collections,
  /// so we must do this manually before re-registering a phone number.
  Future<void> _clearSubCollection(String uid, String subCollection) async {
    const int batchSize = 400;
    QuerySnapshot snap;
    do {
      snap = await _db
          .collection('users')
          .doc(uid)
          .collection(subCollection)
          .limit(batchSize)
          .get();
      if (snap.docs.isEmpty) break;
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } while (snap.docs.length == batchSize);
  }

  /// Save a new GoOuts user to the `users` collection.
  /// Document ID = Firebase Auth UID (no overlap with drivers/businesses).
  Future<void> createUser({
    required String prefix,
    required String fullName,
    required String email,
    required String dob,
    required String pin,
    required String postcode,
    required String houseNo,
    required String streetName,
    required String town,
    required String city,
    required String country,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found.');

    // Clear any leftover sub-collections from a previous registration
    // on this phone number (same UID reused by Firebase phone auth).
    await _clearSubCollection(user.uid, 'transactions');
    await _clearSubCollection(user.uid, 'reviews');
    await _clearSubCollection(user.uid, 'messages');

    final hashedPin = PinHasher.hash(pin, user.uid);

    // Preserve photoUrl set by create_profile_screen before this call.
    // createUser() does a full .set() which would wipe it otherwise.
    String? existingPhotoUrl;
    try {
      final existing = await _db.collection('users').doc(user.uid).get();
      if (existing.exists) {
        existingPhotoUrl = existing.data()?['photoUrl'] as String?;
      }
    } catch (_) {}

    await _db.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'phone': user.phoneNumber ?? '',
      'prefix': prefix,
      'fullName': fullName,
      'email': email,
      'dob': dob,
      'pin': hashedPin, // SHA-256 hashed with uid as salt
      'postcode': postcode,
      'houseNo': houseNo,
      'streetName': streetName,
      'town': town,
      'city': city,
      'country': country,
      'role': 'customer',
      'kycStatus': 'not_started',
      'walletBalance': 2.0,   // £2 welcome bonus credited on registration
      'cashbackBalance': 0.0,
      'cashbackPoints': 0,
      // ── Family & GoOuts Plus fields ──
      'familyGroupId': null,
      'familyRole': null,
      'totalCashbackEarned': 0.0,
      'firstCashbackEarned': false,
      'gooutsPlusMember': false,
      'gooutsPlusActivatedAt': null,
      'gooutsPlusRenewalDate': null,
      'firstYearEnd': DateTime.now().add(const Duration(days: 365)),
      'onboardingComplete': false,
      // inviteCode is deliberately NOT set here any more.
      //
      // This line used to call ReferralService.generateInviteCode(), which
      // picked six random characters with NO uniqueness check of any kind.
      // (ReferralService.saveInviteCode did check, but nothing ever called it,
      // so the check was dead code and this was the real path.) Two people
      // registering could be issued the same code, and the referral lookup
      // would then credit whichever account the query happened to return.
      //
      // The code is now allocated by ensureInviteCode, which reserves it as a
      // document ID under /invite_codes so uniqueness is atomic.
      // ReferralService.getMyInviteCode allocates on first read, so a user who
      // never opens the refer screen never needs one.
      'referredByUid': null,
      'referralRewarded': false,
      'photoUrl': existingPhotoUrl ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Credit £2 welcome bonus transaction to history
    await TransactionService().addTransaction(
      title: '£2 Welcome Bonus',
      amount: 2.0,
      amountFormatted: '+£2.00',
      type: 'Welcome Bonus',
      iconKey: 'gift',
      positive: true,
      status: 'Completed',
    );
  }

  /// Fetch current user's Firestore data
  Future<Map<String, dynamic>?> getCurrentUser() async {
    final User? user = _auth.currentUser;
    if (user == null) return null;
    final doc = await _db.collection('users').doc(user.uid).get();
    return doc.exists ? doc.data() : null;
  }

  /// Check if current user already has a profile saved
  Future<bool> userProfileExists() async {
    final User? user = _auth.currentUser;
    if (user == null) return false;
    final doc = await _db.collection('users').doc(user.uid).get();
    return doc.exists;
  }

  /// Update specific fields on the user document
  Future<void> updateUser(Map<String, dynamic> fields) async {
    final User? user = _auth.currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).update(fields);
  }

  /// Called every time cashback is earned.
  /// Updates totalCashbackEarned, flips firstCashbackEarned on first earn,
  /// and updates the family group combined total if user is in a group.
  /// Returns true if the £100 GoOuts Plus milestone was JUST triggered
  /// by this transaction — so the caller can show the celebration screen.
  Future<bool> recordCashbackEarned(double amount) async {
    final User? user = _auth.currentUser;
    if (user == null) return false;

    final doc = await _db.collection('users').doc(user.uid).get();
    final data = doc.data();
    if (data == null) return false;

    final double currentTotal =
        (data['totalCashbackEarned'] as num?)?.toDouble() ?? 0.0;
    final bool alreadyEarned = data['firstCashbackEarned'] as bool? ?? false;
    final String? groupId = data['familyGroupId'] as String?;

    // Update user's own totals
    await _db.collection('users').doc(user.uid).update({
      'totalCashbackEarned': currentTotal + amount,
      if (!alreadyEarned) 'firstCashbackEarned': true,
    });

    // If user is NOT in a family group, check their solo total
    if (groupId == null) {
      final newSoloTotal = currentTotal + amount;
      final bool soloAlreadyReached =
          data['soloMilestoneReached'] as bool? ?? false;
      if (!soloAlreadyReached && newSoloTotal >= 100.0) {
        await _db.collection('users').doc(user.uid).update({
          'soloMilestoneReached': true,
        });
        return true; // milestone just triggered
      }
      return false;
    }

    // If user IS in a family group, update combined total
    final groupDoc =
        await _db.collection('familyGroups').doc(groupId).get();
    final groupData = groupDoc.data();
    if (groupData == null) return false;

    final double combinedTotal =
        (groupData['combinedCashbackEarned'] as num?)?.toDouble() ?? 0.0;
    final bool milestoneAlreadyReached =
        groupData['milestoneReached'] as bool? ?? false;
    final double newCombined = combinedTotal + amount;

    final bool justTriggered =
        !milestoneAlreadyReached && newCombined >= 100.0;

    await _db.collection('familyGroups').doc(groupId).update({
      'combinedCashbackEarned': newCombined,
      if (justTriggered) 'milestoneReached': true,
      if (justTriggered) 'milestoneReachedAt': FieldValue.serverTimestamp(),
    });

    return justTriggered;
  }

  /// Returns true if the current user has earned their first cashback.
  /// Used to conditionally show the Family Plan in Profile.
  Future<bool> hasEarnedFirstCashback() async {
    final data = await getCurrentUser();
    return data?['firstCashbackEarned'] as bool? ?? false;
  }

  /// Returns true if GoOuts Plus is active for the current user.
  Future<bool> isGoOutsPlusMember() async {
    final data = await getCurrentUser();
    return data?['gooutsPlusMember'] as bool? ?? false;
  }

  /// Activate GoOuts Plus.
  ///
  /// Kept only so nothing that called it breaks. The charge and the activation
  /// are now ONE server side transaction, so activating without paying is no
  /// longer a separate thing a caller can do. Use [chargeGoOutsPlus].
  @Deprecated('Use chargeGoOutsPlus. Activation is part of the payment now.')
  Future<void> activateGoOutsPlus() async {
    await chargeGoOutsPlus();
  }

  /// Charge £10 for GoOuts Plus and activate it. ONE server side transaction.
  ///
  /// This used to do three things from the client, back to back: read the
  /// wallet balance and subtract the fee, set gooutsPlusMember, then activate
  /// for the family group. Four problems, all now fixed server side.
  ///
  /// ⚠ A SHORT WALLET USED TO GIVE PLUS AWAY FREE. If the balance was under
  ///   £10 the old code set walletBalance to 0, wrote a transaction line
  ///   saying "Bank: £X", activated Plus and returned success: true. The bank
  ///   charge was a TODO that never ran, so a user with £0 got a year of
  ///   GoOuts Plus for nothing.
  ///
  ///   IT NOW FAILS with a "top up first" message. That is a deliberate
  ///   behaviour change, and the only honest one available until the Open
  ///   Banking charge exists.
  ///
  /// `walletBalance - fee` was also read-modify-write, so a cashback credit
  /// landing at the same moment was erased. And the dates came from the DEVICE
  /// clock, so a phone with its clock moved forward set its own renewal date.
  ///
  /// Same return shape as before:
  /// { 'success': bool, 'chargedFromWallet': double,
  ///   'chargedFromBank': double, 'error': String? }
  Future<Map<String, dynamic>> chargeGoOutsPlus() async {
    if (_auth.currentUser == null) {
      return {'success': false, 'error': 'Not logged in.'};
    }
    try {
      final res = await _fn
          .httpsCallable('purchaseGoOutsPlus')
          .call<Map<String, dynamic>>(<String, dynamic>{});

      return {
        'success': true,
        'chargedFromWallet':
            (res.data['chargedFromWallet'] as num?)?.toDouble() ?? 0.0,
        'chargedFromBank':
            (res.data['chargedFromBank'] as num?)?.toDouble() ?? 0.0,
        'alreadyMember': res.data['alreadyMember'] == true,
        // The family group is activated inside the same call now. The caller
        // no longer needs to follow up with activatePlusForGroup.
        'familyMembers': res.data['familyMembers'] ?? 0,
        'error': null,
      };
    } on FirebaseFunctionsException catch (e) {
      // failed-precondition carries the "top up first" message, which is
      // worth showing to the user verbatim rather than replacing with
      // something generic.
      return {'success': false, 'error': e.message ?? 'Could not start GoOuts Plus.'};
    } catch (_) {
      return {
        'success': false,
        'error': 'Could not start GoOuts Plus. Check your connection.'
      };
    }
  }
}
