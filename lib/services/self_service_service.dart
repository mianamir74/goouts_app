import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_service.dart';
import 'partner_seed_service.dart';

/// Fetches user-specific Firestore data based on support topic
/// so the app can show a self-service resolution before creating a ticket.
class SelfServiceService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// Extracts the real merchant name from any transaction title format.
  /// e.g. "Wallet Used at Dishoom" → "Dishoom"
  ///      "Cashback Redeemed at Dishoom" → "Dishoom"
  ///      "Dishoom — Cashback" → "Dishoom"
  ///      "Spent at Dishoom" → "Dishoom"
  static String extractMerchantName(String title) {
    const prefixes = [
      'Wallet Used at ',
      'Cashback Redeemed at ',
      'Cashback Used at ',
      'Spent at ',
    ];
    for (final p in prefixes) {
      if (title.startsWith(p)) return title.substring(p.length).trim();
    }
    if (title.contains(' — Cashback')) return title.split(' — Cashback')[0].trim();
    if (title.contains(' — ')) return title.split(' — ')[0].trim();
    return title.trim();
  }

  /// Checks whether a merchant is a confirmed GoOuts partner.
  /// Checks in priority order:
  ///   1. Global partners collection (most reliable)
  ///   2. User's transaction history (cashbackEarned on past visits)
  Future<bool> isKnownPartner(String rawTitle) async {
    if (rawTitle.isEmpty) return false;
    final merchantName = extractMerchantName(rawTitle);

    // 1. Check global partners collection first
    final partnerSvc = PartnerSeedService();
    final inPartnersList = await partnerSvc.isPartnerInFirestore(merchantName);
    if (inPartnersList) return true;

    // 2. Fall back to transaction history
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    try {
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .where('title', isEqualTo: merchantName)
          .where('positive', isEqualTo: false)
          .limit(10)
          .get();
      return snap.docs.any((d) => d.data()['cashbackEarned'] != null);
    } catch (_) {
      return false;
    }
  }

  /// Returns a self-service payload for the given topic.
  /// Keys depend on topic — all values are display-ready strings.
  Future<Map<String, dynamic>> fetchForTopic(String topicValue) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return {};

    final profile = await UserService().getCurrentUser() ?? {};

    switch (topicValue) {
      case 'transaction_issue':
        return _fetchTransactionInfo(uid, profile);
      case 'cashback_query':
        return _fetchCashbackInfo(uid, profile);
      case 'account_security':
        return _fetchSecurityInfo(profile);
      case 'card_problem':
        return _fetchCardInfo(uid, profile);
      case 'kyc_verification':
        return _fetchKycInfo(profile);
      default:
        return {'profile': profile};
    }
  }

  // ─── Transaction Issue ───────────────────────────────────────────────────
  Future<Map<String, dynamic>> _fetchTransactionInfo(
      String uid, Map<String, dynamic> profile) async {
    try {
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      final txns = snap.docs.map((d) {
        final data = d.data();
        return {
          'id': d.id,
          'title': data['title'] ?? 'Unknown merchant',
          'amount': data['amountFormatted'] ?? '',
          'date': data['dateFormatted'] ?? '',
          'status': data['status'] ?? 'Completed',
          'positive': data['positive'] ?? false,
          'type': data['type'] ?? '',
        };
      }).toList();

      final balance = profile['walletBalance'];
      final balanceStr = balance != null
          ? '£${(balance as num).toStringAsFixed(2)}'
          : 'N/A';

      // Detect pending transactions
      final pending = txns.where((t) =>
          (t['status'] as String).toLowerCase() == 'pending').toList();

      return {
        'type': 'transaction',
        'walletBalance': balanceStr,
        'transactions': txns,
        'pendingCount': pending.length,
        'hasPending': pending.isNotEmpty,
      };
    } catch (_) {
      return {'type': 'transaction', 'transactions': [], 'walletBalance': 'N/A'};
    }
  }

  // ─── Cashback Query ──────────────────────────────────────────────────────
  Future<Map<String, dynamic>> _fetchCashbackInfo(
      String uid, Map<String, dynamic> profile) async {
    try {
      // Fetch recent spending transactions — these are what users query about
      final spendSnap = await _db
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .where('positive', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      final spendingTxns = spendSnap.docs.map((d) {
        final data = d.data();
        final cashbackEarned = data['cashbackEarned'];
        return {
          'id': d.id,
          'title': data['title'] ?? 'Unknown merchant',
          'amount': data['amountFormatted'] ?? '',
          'amountValue': (data['amount'] as num?)?.toDouble() ?? 0.0,
          'date': data['dateFormatted'] ?? '',
          'status': data['status'] ?? 'Completed',
          'cashbackEarned': cashbackEarned,
          'cashbackStr': cashbackEarned != null
              ? '+£${(cashbackEarned as num).toStringAsFixed(2)}'
              : null,
          'isPartner': cashbackEarned != null,
        };
      }).toList();

      final balance = profile['walletBalance'];
      final balanceStr = balance != null
          ? '£${(balance as num).toStringAsFixed(2)}'
          : 'N/A';

      return {
        'type': 'cashback',
        'walletBalance': balanceStr,
        'spendingTransactions': spendingTxns,
      };
    } catch (_) {
      return {'type': 'cashback', 'walletBalance': 'N/A', 'spendingTransactions': []};
    }
  }

  // ─── Account Security ────────────────────────────────────────────────────
  Future<Map<String, dynamic>> _fetchSecurityInfo(
      Map<String, dynamic> profile) async {
    final uid = _auth.currentUser?.uid;
    final kycStatus = profile['kycStatus'] as String? ?? 'not_verified';
    final email = profile['email'] as String? ?? 'Not set';
    final phone = profile['phone'] as String? ??
        FirebaseAuth.instance.currentUser?.phoneNumber ?? 'Not set';
    final fullName = profile['fullName'] as String? ?? '';

    String kycLabel;
    if (kycStatus == 'verified') {
      kycLabel = 'Verified ✓';
    } else if (kycStatus == 'pending') {
      kycLabel = 'Under Review';
    } else {
      kycLabel = 'Not Verified';
    }

    // Fetch recent transactions for phishing/scam reports
    List<Map<String, dynamic>> recentTxns = [];
    if (uid != null) {
      try {
        final snap = await _db
            .collection('users')
            .doc(uid)
            .collection('transactions')
            .orderBy('createdAt', descending: true)
            .limit(5)
            .get();
        recentTxns = snap.docs.map((d) {
          final data = d.data();
          return {
            'id': d.id,
            'title': data['title'] ?? '',
            'amount': data['amountFormatted'] ?? '',
            'date': data['dateFormatted'] ?? '',
            'status': data['status'] ?? 'Completed',
            'positive': data['positive'] ?? false,
          };
        }).toList();
      } catch (_) {}
    }

    return {
      'type': 'security',
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'kycStatus': kycStatus,
      'kycLabel': kycLabel,
      'accountStatus': 'Active',
      'recentTransactions': recentTxns,
    };
  }

  // ─── Card Problem ────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> _fetchCardInfo(
      String uid, Map<String, dynamic> profile) async {
    try {
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .where('positive', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      final txns = snap.docs.map((d) {
        final data = d.data();
        return {
          'id': d.id,
          'title': data['title'] ?? '',
          'amount': data['amountFormatted'] ?? '',
          'amountValue': (data['amount'] as num?)?.toDouble() ?? 0.0,
          'date': data['dateFormatted'] ?? '',
          'status': data['status'] ?? 'Completed',
          'positive': false,
        };
      }).toList();

      final cardFrozen = profile['cardFrozen'] as bool? ?? false;

      return {
        'type': 'card',
        'cardStatus': cardFrozen ? 'Frozen' : 'Active',
        'cardFrozen': cardFrozen,
        'transactions': txns,
      };
    } catch (_) {
      return {'type': 'card', 'cardStatus': 'Active', 'cardFrozen': false, 'transactions': []};
    }
  }

  // ─── KYC / Verification ──────────────────────────────────────────────────
  Future<Map<String, dynamic>> _fetchKycInfo(
      Map<String, dynamic> profile) async {
    final kycStatus = profile['kycStatus'] as String? ?? 'not_verified';
    final fullName = profile['fullName'] as String? ?? '';

    String statusTitle;
    String statusMessage;
    String statusColor; // 'green', 'orange', 'red', 'grey'

    switch (kycStatus) {
      case 'verified':
        statusTitle = 'Identity Verified';
        statusMessage =
            'Your identity has been successfully verified. Your account has full access.';
        statusColor = 'green';
        break;
      case 'pending':
        statusTitle = 'Under Review';
        statusMessage =
            'Your documents are being reviewed by our team. This usually takes 1–2 business days. You will receive a notification once complete.';
        statusColor = 'orange';
        break;
      case 'rejected':
        statusTitle = 'Verification Failed';
        statusMessage =
            'Your documents were not accepted. Please re-submit with a clear, valid government-issued ID and a matching selfie.';
        statusColor = 'red';
        break;
      default:
        statusTitle = 'Not Verified';
        statusMessage =
            'Your identity has not been verified yet. Tap "Verify Now" in your Profile to complete the process and unlock higher limits.';
        statusColor = 'grey';
    }

    return {
      'type': 'kyc',
      'fullName': fullName,
      'kycStatus': kycStatus,
      'statusTitle': statusTitle,
      'statusMessage': statusMessage,
      'statusColor': statusColor,
    };
  }
}
