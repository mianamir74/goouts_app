import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MessageService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// User's personal inbox: users/{uid}/messages
  CollectionReference<Map<String, dynamic>>? get _inbox {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('messages');
  }

  /// Fetch all messages for the current user, newest first
  Future<List<Map<String, dynamic>>> getMessages() async {
    final inbox = _inbox;
    if (inbox == null) return [];
    try {
      final snap =
          await inbox.orderBy('createdAt', descending: true).get();
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (_) {
      return [];
    }
  }

  /// Mark a single message as read (updates the doc's isRead field)
  Future<void> markAsRead(String messageId) async {
    final inbox = _inbox;
    if (inbox == null) return;
    try {
      await inbox.doc(messageId).set(
        {
          'isRead': true,
          'read': true,
          'seen': true,
          'readAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  /// Mark ALL messages as read in one batch
  Future<void> markAllAsRead() async {
    final inbox = _inbox;
    if (inbox == null) return;
    try {
      final snap = await inbox.get();
      final unread = snap.docs.where((d) {
        final data = d.data();
        return data['isRead'] != true &&
            data['read'] != true &&
            data['seen'] != true;
      }).toList();
      if (unread.isEmpty) return;
      final batch = _db.batch();
      for (final doc in unread) {
        batch.set(
          doc.reference,
          {
            'isRead': true,
            'read': true,
            'seen': true,
            'readAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
      await batch.commit();
    } catch (_) {}
  }

  /// Seed sample messages into users/{uid}/messages if the inbox is empty.
  /// This simulates what a Cloud Function / admin panel would deliver to users.
  Future<void> seedIfEmpty() async {
    final inbox = _inbox;
    if (inbox == null) return;
    try {
      final existing = await inbox.limit(1).get();
      if (existing.docs.isNotEmpty) return;

      final now = DateTime.now();
      final batch = _db.batch();

      final samples = [
        {
          'title': 'Welcome to GoOuts! 🎉',
          'body':
              'Your account is set up and ready to go. Start earning cashback at participating partners near you — just scan, tap, and earn. Enjoy GoOuts!',
          'category': 'updates',
          'urgent': false,
          'isRead': false,
          'read': false,
          'seen': false,
          'imageUrl': null,
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        },
      ];

      for (final m in samples) {
        batch.set(inbox.doc(), m);
      }
      await batch.commit();
    } catch (_) {}
  }

  /// Live stream of unread message count from users/{uid}/messages.
  Stream<int> unreadCountStream() {
    final inbox = _inbox;
    if (inbox == null) return Stream.value(0);
    return inbox.snapshots().map(
          (s) => s.docs.where((d) => isUnread(d.data())).length,
        );
  }

  /// Live stream of unread notification count from users/{uid}/notifications.
  Stream<int> unreadNotificationsStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(0);
    return _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  /// Check if a message map is unread
  static bool isUnread(Map<String, dynamic> m) {
    return m['isRead'] != true && m['read'] != true && m['seen'] != true;
  }

  /// Format createdAt Timestamp to human-readable relative time
  static String formatTime(dynamic createdAt) {
    if (createdAt == null) return '';
    final DateTime dt = createdAt is Timestamp
        ? createdAt.toDate()
        : createdAt is DateTime
            ? createdAt
            : DateTime.now();
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
