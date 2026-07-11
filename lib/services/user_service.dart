import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/pin_hasher.dart';
import 'transaction_service.dart';
import 'referral_service.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
      'kycStatus': 'pending',
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
      'inviteCode': ReferralService.generateInviteCode(), // unique invite code
      'referredByUid': null,
      'referralRewarded': false,
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

  /// Activate GoOuts Plus — sets gooutsPlusMember to true and records dates.
  Future<void> activateGoOutsPlus() async {
    final User? user = _auth.currentUser;
    if (user == null) return;
    final now = DateTime.now();
    await _db.collection('users').doc(user.uid).update({
      'gooutsPlusMember': true,
      'gooutsPlusActivatedAt': now,
      'gooutsPlusRenewalDate': DateTime(now.year + 1, now.month, now.day),
    });
  }

  /// Charge £10 for GoOuts Plus activation.
  /// Deducts from wallet first. If wallet is insufficient,
  /// the remainder is flagged for Open Banking charge (backend phase).
  /// Records the transaction in Activity screen.
  /// Returns a result map: { 'success': bool, 'chargedFromWallet': double,
  /// 'chargedFromBank': double, 'error': String? }
  Future<Map<String, dynamic>> chargeGoOutsPlus() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return {'success': false, 'error': 'Not logged in.'};
    }

    try {
      const double fee = 10.0;
      final data = await getCurrentUser();
      if (data == null) {
        return {'success': false, 'error': 'Could not load account.'};
      }

      final double walletBalance =
          (data['walletBalance'] as num?)?.toDouble() ?? 0.0;

      double chargedFromWallet = 0.0;
      double chargedFromBank = 0.0;

      if (walletBalance >= fee) {
        // Full £10 from wallet
        chargedFromWallet = fee;
        await _db.collection('users').doc(user.uid).update({
          'walletBalance': walletBalance - fee,
        });
      } else {
        // Partial or full from bank
        chargedFromWallet = walletBalance;
        chargedFromBank = fee - walletBalance;
        await _db.collection('users').doc(user.uid).update({
          'walletBalance': 0.0,
        });
        // TODO: trigger Open Banking VRP charge of chargedFromBank
        // when Stripe/VRP integration is live
      }

      // Record transaction in Activity screen
      final DateTime dt = DateTime.now();
      const months = [
        'January','February','March','April','May','June',
        'July','August','September','October','November','December'
      ];
      final String month = '${months[dt.month - 1]} ${dt.year}';
      final int h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final String min = dt.minute.toString().padLeft(2, '0');
      final String ampm = dt.hour < 12 ? 'AM' : 'PM';
      final String dateFormatted = 'Today, $h:$min $ampm';

      await _db
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .add({
        'title': 'GoOuts Plus — Annual Membership',
        'amount': fee,
        'amountFormatted': '-£10.00',
        'dateFormatted': dateFormatted,
        'month': month,
        'type': 'Membership',
        'iconKey': 'star',
        'positive': false,
        'status': 'Completed',
        'note': chargedFromBank > 0
            ? 'Wallet: £${chargedFromWallet.toStringAsFixed(2)} + Bank: £${chargedFromBank.toStringAsFixed(2)}'
            : 'Charged from GoOuts Wallet',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Activate Plus on user document
      await activateGoOutsPlus();

      return {
        'success': true,
        'chargedFromWallet': chargedFromWallet,
        'chargedFromBank': chargedFromBank,
        'error': null,
      };
    } catch (e) {
      return {'success': false, 'error': 'Something went wrong. Please try again.'};
    }
  }
}
