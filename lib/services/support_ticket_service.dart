import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_service.dart';

class SupportTicketService {
  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // ── Auto-priority logic ───────────────────────────────────────────────────
  /// Maps sub-topic keywords to priority levels.
  /// HIGH  → urgent/financial issues (unauthorized charge, fraud, account locked)
  /// LOW   → informational / general queries
  /// Defaults to 'medium'.
  static String _autoPriority(String category, String subTopic) {
    final s = subTopic.toLowerCase();
    final c = category.toLowerCase();

    // High priority — financial risk or account access blocked
    if (s.contains('unauthorized') ||
        s.contains('fraud') ||
        s.contains('scam') ||
        s.contains('charged twice') ||
        s.contains('account locked') ||
        s.contains('cannot log in') ||
        s.contains('security') ||
        c == 'account_security') return 'high';

    // Low priority — informational / general
    if (s.contains('how') ||
        s.contains('general') ||
        s.contains('other') ||
        c == 'other') return 'low';

    return 'medium';
  }

  // ── Submit new ticket ─────────────────────────────────────────────────────
  /// Creates ticket in support_requests (same collection as driver app so
  /// admin panel sees all user tickets alongside driver tickets).
  Future<Map<String, String>> submitTicket({
    required String category,
    required String categoryLabel,
    required String subject,
    required String message,
    String subTopic  = '',
    String priority  = '',          // leave empty to auto-compute
    String? linkedTransactionId,
    bool   selfServiceAttempted = false,
    Map<String, dynamic> contextSnapshot = const {},
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final profile  = await UserService().getCurrentUser();
    final fullName = profile?['fullName']  as String? ?? '';
    final email    = profile?['email']     as String? ?? '';
    final phone    = profile?['phone']     as String? ?? user.phoneNumber ?? '';

    // Auto-compute priority if not explicitly provided
    final resolvedPriority = priority.isNotEmpty
        ? priority
        : _autoPriority(category, subTopic);

    final ref       = _db.collection('support_requests').doc();
    final shortId   = ref.id.substring(0, 8).toUpperCase();
    final ticketNum = 'SR-$shortId';
    final msgText   = message.trim();

    await ref.set({
      'uid':                user.uid,
      'fullName':           fullName,
      'firstName':          fullName.split(' ').first,
      'surname':            fullName.contains(' ')
                              ? fullName.substring(fullName.indexOf(' ') + 1)
                              : '',
      'email':              email,
      'mobileNumber':       phone,
      'accountType':        'user',
      'sourceCollection':   'users',
      'category':           category,
      'categoryLabel':      categoryLabel,
      'subTopic':           subTopic,
      'subject':            subject.trim(),
      'message':            msgText,
      'status':             'new',
      'priority':           resolvedPriority,
      'ticketNumber':       ticketNum,
      'linkedTransactionId': linkedTransactionId ?? '',
      // Self-service metadata — tells admin user already tried to resolve
      'selfServiceAttempted': selfServiceAttempted,
      // Context snapshot — account state at time of submission
      if (contextSnapshot.isNotEmpty) 'contextSnapshot': contextSnapshot,
      // Chat thread fields (same pattern as driver app)
      'lastMessage':        msgText,
      'lastMessageAt':      FieldValue.serverTimestamp(),
      'lastMessageBy':      'user',
      'unreadByAdmin':      true,
      'unreadByUser':       false,
      // Reply / rating fields
      'adminReply':         '',
      'adminRepliedAt':     null,
      'adminRepliedBy':     '',
      'rating':             0,
      'ratingComment':      '',
      'ratingLabel':        '',
      'createdAt':          FieldValue.serverTimestamp(),
      'updatedAt':          FieldValue.serverTimestamp(),
    });

    // First message in the thread
    await ref.collection('messages').add({
      'sender':     'user',
      'senderType': 'user',   // admin panel reads senderType
      'senderName': fullName,
      'text':       msgText,
      'imageUrl':   '',
      'isRead':     false,
      'createdAt':  FieldValue.serverTimestamp(),
    });

    // Return both ID and formatted ticket number so caller can open chat
    return {'ticketId': ref.id, 'ticketNumber': ticketNum, 'fullName': fullName};
  }

  // ── Send a follow-up message ──────────────────────────────────────────────
  Future<void> sendMessage({
    required String ticketId,
    required String text,
    String imageUrl = '',
  }) async {
    final user    = _auth.currentUser;
    if (user == null) return;
    final profile  = await UserService().getCurrentUser();
    final fullName = profile?['fullName'] as String? ?? 'User';

    final msgText = text.trim();

    final ref = _db.collection('support_requests').doc(ticketId);

    await ref.collection('messages').add({
      'sender':     'user',
      'senderType': 'user',   // admin panel reads senderType
      'senderName': fullName,
      'text':       msgText,
      'imageUrl':   imageUrl,
      'isRead':     false,
      'createdAt':  FieldValue.serverTimestamp(),
    });

    await ref.update({
      'lastMessage':    msgText.isNotEmpty ? msgText : '📷 Image',
      'lastMessageAt':  FieldValue.serverTimestamp(),
      'lastMessageBy':  'user',
      'unreadByAdmin':  true,
      'updatedAt':      FieldValue.serverTimestamp(),
    });
  }

  // ── Mark admin messages as read ───────────────────────────────────────────
  Future<void> markAdminMessagesRead(String ticketId) async {
    try {
      final snap = await _db
          .collection('support_requests')
          .doc(ticketId)
          .collection('messages')
          .where('sender', isEqualTo: 'admin')
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();

      await _db
          .collection('support_requests')
          .doc(ticketId)
          .update({'unreadByUser': false});
    } catch (_) {}
  }

  // ── Messages stream ───────────────────────────────────────────────────────
  Stream<QuerySnapshot> messagesStream(String ticketId) {
    return _db
        .collection('support_requests')
        .doc(ticketId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots();
  }

  // ── Ticket stream (live status updates) ───────────────────────────────────
  Stream<DocumentSnapshot> ticketStream(String ticketId) {
    return _db.collection('support_requests').doc(ticketId).snapshots();
  }

  // ── Fetch all tickets for current user ────────────────────────────────────
  Future<List<Map<String, dynamic>>> getMyTickets() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];
    try {
      // No orderBy — avoids requiring a Firestore composite index.
      // Sorted client-side instead.
      final snap = await _db
          .collection('support_requests')
          .where('uid', isEqualTo: uid)
          .where('sourceCollection', isEqualTo: 'users')
          .get();
      final list = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      list.sort((a, b) {
        final aTs = a['createdAt'];
        final bTs = b['createdAt'];
        if (aTs == null && bTs == null) return 0;
        if (aTs == null) return 1;
        if (bTs == null) return -1;
        final aDt = aTs is Timestamp ? aTs.toDate() : DateTime.now();
        final bDt = bTs is Timestamp ? bTs.toDate() : DateTime.now();
        return bDt.compareTo(aDt);
      });
      return list;
    } catch (_) {
      return [];
    }
  }

  // ── Unread count stream (for badge in Profile) ────────────────────────────
  Stream<int> unreadCountStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(0);
    return _db
        .collection('support_requests')
        .where('uid', isEqualTo: uid)
        .where('sourceCollection', isEqualTo: 'users')
        .where('unreadByUser', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs.length);
  }

  // ── Star rating ───────────────────────────────────────────────────────────
  Future<void> rateTicket({
    required String ticketId,
    required int    rating,
    required String comment,
  }) async {
    const labels = ['', 'Poor', 'Fair', 'Good', 'Very Good', 'Excellent'];
    await _db.collection('support_requests').doc(ticketId).update({
      'rating':        rating,
      'ratingComment': comment.trim(),
      'ratingLabel':   rating >= 1 && rating <= 5 ? labels[rating] : '',
      'ratedAt':       FieldValue.serverTimestamp(),
      'updatedAt':     FieldValue.serverTimestamp(),
    });
  }

  // ── Status helpers ────────────────────────────────────────────────────────
  static Map<String, dynamic> statusStyle(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return {'label': 'New',         'color': 0xFF0392CA, 'bg': 0xFFD6EEF8};
      case 'in_progress':
        return {'label': 'In Progress', 'color': 0xFFD97706, 'bg': 0xFFFEF3C7};
      case 'need_more_info':
        return {'label': 'Need More Info','color': 0xFF7C3AED,'bg': 0xFFEDE9FE};
      case 'waiting_driver':
      case 'waiting_user':
        return {'label': 'Waiting for You','color': 0xFF0891B2,'bg': 0xFFE0F7FA};
      case 'resolved':
        return {'label': 'Resolved',    'color': 0xFF16A34A, 'bg': 0xFFDCFCE7};
      case 'closed':
        return {'label': 'Closed',      'color': 0xFF64748B, 'bg': 0xFFF1F5F9};
      default:
        return {'label': status,        'color': 0xFF757575, 'bg': 0xFFF0F0F0};
    }
  }

  static String formatDate(dynamic ts) {
    if (ts == null) return '';
    final dt = ts is Timestamp ? ts.toDate() : DateTime.now();
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month]} ${dt.day}, ${dt.year}';
  }

  static String formatRelative(dynamic ts) {
    if (ts == null) return '';
    final dt = ts is Timestamp ? ts.toDate() : DateTime.now();
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    if (diff.inDays == 1)    return 'Yesterday';
    return '${diff.inDays}d ago';
  }
}
