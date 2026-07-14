import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TransactionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── Icon key → IconData mapping ───────────────────────────
  static IconData iconFromKey(String key) {
    switch (key) {
      case 'coffee':
        return Icons.coffee_rounded;
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'topup':
        return Icons.add_circle_outline_rounded;
      case 'bar':
        return Icons.sports_bar_rounded;
      case 'nightlife':
        return Icons.nightlife_rounded;
      case 'gift':
        return Icons.card_giftcard_rounded;
      case 'burger':
        return Icons.fastfood_rounded;
      case 'music':
        return Icons.music_note_rounded;
      case 'store':
        return Icons.store_rounded;
      case 'transfer':
        return Icons.send_rounded;
      case 'wallet':
        return Icons.account_balance_wallet_rounded;
      case 'star':
        return Icons.star_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  /// Fetch all transactions for the current user, ordered by date (newest first)
  Future<List<Map<String, dynamic>>> getTransactions() async {
    final User? user = _auth.currentUser;
    if (user == null) return [];

    try {
      final snap = await _db
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .orderBy('createdAt', descending: true)
          .get();

      return snap.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['title'] ?? '',
          'date': data['dateFormatted'] ?? '',
          'month': data['month'] ?? '',
          'amount': data['amountFormatted'] ?? '',
          'amountValue': (data['amount'] as num?)?.toDouble() ?? 0.0,
          'type': data['type'] ?? 'Other',
          'icon': iconFromKey(data['iconKey'] ?? ''),
          'positive': data['positive'] ?? false,
          'status': data['status'] ?? 'Completed',
          'cashback': data['type'] == 'Cashback',
          'earnedCashback': data['cashbackEarned'] != null
              ? '+£${(data['cashbackEarned'] as num).toStringAsFixed(2)}'
              : null,
          'category': data['type'] ?? 'Other',
          'groupId': data['groupId'] as String?,
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Add a new transaction to Firestore — returns the Firestore document ID
  Future<String> addTransaction({
    required String title,
    required double amount,
    required String amountFormatted,
    required String type,
    required String iconKey,
    required bool positive,
    String status = 'Completed',
    double? cashbackEarned,
    String? groupId,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) return '';

    final now = DateTime.now();
    final month = _monthLabel(now);
    final dateFormatted = _dateLabel(now);

    final docRef = await _db
        .collection('users')
        .doc(user.uid)
        .collection('transactions')
        .add({
      'title': title,
      'amount': amount,
      'amountFormatted': amountFormatted,
      'dateFormatted': dateFormatted,
      'month': month,
      'type': type,
      'iconKey': iconKey,
      'positive': positive,
      'status': status,
      'cashbackEarned': cashbackEarned,
      'groupId': groupId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  /// Save a partner review to Firestore — optionally linked to a transaction ID.
  /// Returns false if a review already exists for this transaction (duplicate blocked).
  /// If transactionId is empty, no duplicate check is done (standalone review).
  Future<bool> addReview({
    required String merchant,
    required int rating,
    required String review,
    required double amount,
    required double cashback,
    required String transactionId,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) return false;

    // Only check for duplicates when a real transaction ID exists
    if (transactionId.isNotEmpty) {
      final existing = await _db
          .collection('users')
          .doc(user.uid)
          .collection('reviews')
          .where('transactionId', isEqualTo: transactionId)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) return false; // already reviewed this visit
    }

    await _db
        .collection('users')
        .doc(user.uid)
        .collection('reviews')
        .add({
      'merchant': merchant,
      'rating': rating,
      'review': review,
      'amount': amount,
      'cashback': cashback,
      'transactionId': transactionId, // '' for standalone reviews
      'createdAt': FieldValue.serverTimestamp(),
    });

    return true;
  }

  /// Fetch all payment transactions for a specific partner (by title match).
  Future<List<Map<String, dynamic>>> getTransactionsForPartner(
      String partnerName) async {
    final User? user = _auth.currentUser;
    if (user == null) return [];
    try {
      final snap = await _db
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .where('title', isEqualTo: partnerName)
          .where('positive', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'date': data['dateFormatted'] ?? '',
          'amount': data['amountFormatted'] ?? '',
          'amountValue': (data['amount'] as num?)?.toDouble() ?? 0.0,
          'cashbackEarned': data['cashbackEarned'],
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetch the set of transaction IDs that already have a review for a partner.
  Future<Set<String>> getReviewedTransactionIds(String partnerName) async {
    final User? user = _auth.currentUser;
    if (user == null) return {};
    try {
      final snap = await _db
          .collection('users')
          .doc(user.uid)
          .collection('reviews')
          .where('merchant', isEqualTo: partnerName)
          .get();
      return snap.docs
          .map((doc) => (doc.data()['transactionId'] as String?) ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (_) {
      return {};
    }
  }

  /// Fetch ALL reviewed transaction IDs across all merchants for the current user.
  Future<Set<String>> getAllReviewedTransactionIds() async {
    final User? user = _auth.currentUser;
    if (user == null) return {};
    try {
      final snap = await _db
          .collection('users')
          .doc(user.uid)
          .collection('reviews')
          .get();
      return snap.docs
          .map((doc) => (doc.data()['transactionId'] as String?) ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (_) {
      return {};
    }
  }

  /// Check if a review already exists for a given transaction ID.
  /// Always returns false for empty transaction IDs.
  Future<bool> reviewExists(String transactionId) async {
    if (transactionId.isEmpty) return false;
    final User? user = _auth.currentUser;
    if (user == null) return false;
    final snap = await _db
        .collection('users')
        .doc(user.uid)
        .collection('reviews')
        .where('transactionId', isEqualTo: transactionId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  String _monthLabel(DateTime dt) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final txDay = DateTime(dt.year, dt.month, dt.day);
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    final time = '$hour:$minute $ampm';

    if (txDay == today) return 'Today, $time';
    if (txDay == today.subtract(const Duration(days: 1))) return 'Yesterday, $time';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]}, $time';
  }
}
