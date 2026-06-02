import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_service.dart';

class SupportTicketService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// Submit a new ticket — saves to support_tickets collection
  /// matching the admin panel's SupportTicketModel field names
  Future<String> submitTicket({
    required String category,
    required String categoryLabel,
    required String subject,
    required String message,
    String subTopic = '',
    String priority = 'medium',
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // Load user profile for name/email/phone
    final profile = await UserService().getCurrentUser();
    final fullName = profile?['fullName'] as String? ?? '';
    final email = profile?['email'] as String? ?? '';
    final phone = profile?['phone'] as String? ??
        user.phoneNumber ?? '';

    final ref = _db.collection('support_tickets').doc();
    final shortId = ref.id.substring(0, 8).toUpperCase();
    final ticketNumber = 'TK-$shortId';

    await ref.set({
      'uid': user.uid,
      'fullName': fullName,
      'email': email,
      'mobileNumber': phone,
      'accountType': 'user',
      'sourceCollection': 'users',
      'category': category,
      'categoryLabel': categoryLabel,
      'subTopic': subTopic,
      'subject': subject.trim(),
      'message': message.trim(),
      'status': 'new',
      'priority': priority,
      'ticketNumber': ticketNumber,
      'adminReply': '',
      'adminRepliedAt': null,
      'adminRepliedBy': '',
      'rating': 0,
      'ratingComment': '',
      'ratingLabel': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return ticketNumber;
  }

  /// Fetch all tickets for the current user, newest first
  Future<List<Map<String, dynamic>>> getMyTickets() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];
    try {
      final snap = await _db
          .collection('support_tickets')
          .where('uid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (_) {
      return [];
    }
  }

  /// Submit a star rating for a resolved ticket
  Future<void> rateTicket({
    required String ticketId,
    required int rating,
    required String comment,
  }) async {
    const labels = ['', 'Poor', 'Fair', 'Good', 'Very Good', 'Excellent'];
    await _db.collection('support_tickets').doc(ticketId).update({
      'rating': rating,
      'ratingComment': comment.trim(),
      'ratingLabel': rating > 0 && rating <= 5 ? labels[rating] : '',
      'ratedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Helper: status color
  static Map<String, dynamic> statusStyle(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return {
          'label': 'New',
          'color': 0xFF0392CA,
          'bg': 0xFFD6EEF8,
        };
      case 'open':
        return {
          'label': 'Open',
          'color': 0xFF0392CA,
          'bg': 0xFFD6EEF8,
        };
      case 'pending':
        return {
          'label': 'Pending',
          'color': 0xFFE65100,
          'bg': 0xFFFFF3E0,
        };
      case 'resolved':
        return {
          'label': 'Resolved',
          'color': 0xFF388E3C,
          'bg': 0xFFE8F5E9,
        };
      default:
        return {
          'label': status,
          'color': 0xFF757575,
          'bg': 0xFFF0F0F0,
        };
    }
  }

  /// Format Firestore Timestamp to readable date string
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
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }
}
