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
          'title': 'Security Alert',
          'body':
              'A new login was detected on your GoOuts account from a new device. If this was not you, please change your PIN immediately from Profile → Security.',
          'category': 'security',
          'urgent': true,
          'isRead': false,
          'read': false,
          'seen': false,
          'imageUrl': null,
          'createdAt': Timestamp.fromDate(now.subtract(const Duration(hours: 1))),
          'updatedAt': Timestamp.fromDate(now.subtract(const Duration(hours: 1))),
        },
        {
          'title': 'Weekend Cashback Special',
          'body':
              'Earn double cashback at all partner restaurants this weekend only. Valid Saturday and Sunday — visit any GoOuts partner and scan to earn!',
          'category': 'offers',
          'urgent': false,
          'isRead': false,
          'read': false,
          'seen': false,
          'imageUrl': null,
          'createdAt': Timestamp.fromDate(now.subtract(const Duration(hours: 4))),
          'updatedAt': Timestamp.fromDate(now.subtract(const Duration(hours: 4))),
        },
        {
          'title': 'Exclusive Partner Offer',
          'body':
              'Burger Palace is offering 20% extra cashback today only. Visit in-store and scan your GoOuts QR code to redeem. Offer expires midnight tonight.',
          'category': 'offers',
          'urgent': false,
          'isRead': false,
          'read': false,
          'seen': false,
          'imageUrl': null,
          'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 1))),
          'updatedAt': Timestamp.fromDate(now.subtract(const Duration(days: 1))),
        },
        {
          'title': 'New Feature: Pending Reviews',
          'body':
              'You can now leave reviews directly from your Transaction History screen. Earn 2 reward points for every review you submit — check the Reviews tab.',
          'category': 'updates',
          'urgent': false,
          'isRead': false,
          'read': false,
          'seen': false,
          'imageUrl': null,
          'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 2))),
          'updatedAt': Timestamp.fromDate(now.subtract(const Duration(days: 2))),
        },
        {
          'title': 'Scheduled Maintenance',
          'body':
              'GoOuts services will undergo scheduled maintenance this Sunday between 2 AM and 4 AM. Some features may be briefly unavailable during this window.',
          'category': 'updates',
          'urgent': false,
          'isRead': false,
          'read': false,
          'seen': false,
          'imageUrl': null,
          'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 3))),
          'updatedAt': Timestamp.fromDate(now.subtract(const Duration(days: 3))),
        },
      ];

      for (final m in samples) {
        batch.set(inbox.doc(), m);
      }
      await batch.commit();
    } catch (_) {}
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
