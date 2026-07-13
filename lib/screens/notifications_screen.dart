import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'support_ticket_chat_screen.dart';
import '../widgets/goouts_sheet.dart';

const Color _primary          = Color(0xFF0392CA);
const Color _surfaceColor     = Color(0xFFF9F9FC);
const Color _onSurface        = Color(0xFF191C1E);
const Color _onSurfaceVariant = Color(0xFF42474E);

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> get _ref =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('notifications');

  // ── Mark all read ────────────────────────────────────────────────────────
  Future<void> _markAllRead() async {
    if (_uid.isEmpty) return;
    final snap = await _ref.where('isRead', isEqualTo: false).get();
    if (snap.docs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final d in snap.docs) batch.update(d.reference, {'isRead': true});
    await batch.commit();
  }

  Future<void> _markRead(String docId) async {
    if (_uid.isEmpty) return;
    await _ref.doc(docId).update({'isRead': true});
  }

  Future<void> _delete(String docId) async {
    if (_uid.isEmpty) return;
    await _ref.doc(docId).delete();
  }

  // ── Tap routing ──────────────────────────────────────────────────────────
  void _onTap(Map<String, dynamic> data, String docId) async {
    await _markRead(docId);
    final screen = (data['screen'] ?? '').toString();
    final extra  = Map<String, dynamic>.from(data['data'] as Map? ?? {});
    if (!mounted) return;
    switch (screen) {
      case 'support_ticket_chat':
        final tid  = extra['ticketId']?.toString()     ?? '';
        final num  = extra['ticketNumber']?.toString() ?? '';
        final subj = extra['subject']?.toString()      ?? 'Support Ticket';
        if (tid.isNotEmpty) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => SupportTicketChatScreen(
              ticketId: tid, subject: subj, ticketNumber: num, userName: 'GoOuts Support'),
          ));
        }
        break;
      case 'kyc':     Navigator.pushNamed(context, '/kyc');     break;
      case 'profile': Navigator.pushNamed(context, '/profile'); break;
      case 'wallet':  Navigator.pushNamed(context, '/wallet');  break;
      case 'messages':Navigator.pushNamed(context, '/messages');break;
      default:
        // Informational notifications → show detail screen
        Navigator.pushNamed(context, '/notification-detail', arguments: data);
        break;
    }
  }

  // ── Icon & colour per type ───────────────────────────────────────────────
  IconData _iconFor(String type) {
    switch (type) {
      case 'kyc_approved':  return Icons.verified_outlined;
      case 'kyc_rejected':  return Icons.security_outlined;
      case 'ticket_reply':  return Icons.chat_outlined;
      case 'ticket_status': return Icons.support_agent_outlined;
      case 'cashback':      return Icons.account_balance_wallet_outlined;
      case 'transaction':   return Icons.receipt_long_outlined;
      default:              return Icons.notifications_none_outlined;
    }
  }

  Color _iconBgFor(String type) {
    switch (type) {
      case 'kyc_approved':  return const Color(0xFFE8F5E9);
      case 'kyc_rejected':  return const Color(0xFFFFEBEE);
      case 'ticket_reply':  return const Color(0xFFE1F5FE);
      case 'ticket_status': return const Color(0xFFEDE7F6);
      case 'cashback':      return const Color(0xFFE1F5FE);
      case 'transaction':   return const Color(0xFFF5F5F5);
      default:              return const Color(0xFFF5F5F5);
    }
  }

  Color _iconColorFor(String type) {
    switch (type) {
      case 'kyc_approved':  return const Color(0xFF2E7D32);
      case 'kyc_rejected':  return const Color(0xFFC62828);
      case 'ticket_reply':  return _primary;
      case 'ticket_status': return const Color(0xFF6A1B9A);
      case 'cashback':      return _primary;
      case 'transaction':   return Colors.grey.shade600;
      default:              return Colors.grey.shade600;
    }
  }

  // ── Date grouping ────────────────────────────────────────────────────────
  String _groupLabel(DateTime dt) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d     = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return 'TODAY';
    if (d == today.subtract(const Duration(days: 1))) return 'YESTERDAY';
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const days   = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return '${days[dt.weekday - 1].toUpperCase()}, ${dt.day} ${months[dt.month - 1].toUpperCase()}';
  }

  String _timeLabel(Timestamp? ts) {
    if (ts == null) return '';
    final dt   = ts.toDate();
    final now  = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1)  return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    if (diff.inDays == 1)   return 'Yesterday, $h:$m';
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceColor,
      appBar: _buildAppBar(),
      body: SafeArea(child: _buildBody()),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── AppBar ───────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _primary, size: 20),
        onPressed: () => Navigator.maybePop(context),
      ),
      centerTitle: true,
      title: Text('GoOuts',
        style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold,
            color: _primary, letterSpacing: -0.5)),
      actions: [
        StreamBuilder<QuerySnapshot>(
          stream: _uid.isEmpty ? const Stream.empty()
              : _ref.where('isRead', isEqualTo: false).snapshots(),
          builder: (_, snap) {
            final count = snap.data?.docs.length ?? 0;
            return Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_none_outlined, color: _primary),
                  onPressed: () {},
                ),
                if (count > 0)
                  Positioned(
                    right: 12, top: 12,
                    child: Container(
                      width: 16, height: 16,
                      decoration: const BoxDecoration(
                          color: Color(0xFFB3261E), shape: BoxShape.circle),
                      child: Center(
                        child: Text(count > 9 ? '9+' : '$count',
                          style: GoogleFonts.inter(color: Colors.white,
                              fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ── Body ─────────────────────────────────────────────────────────────────
  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title row
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Notifications',
                style: GoogleFonts.inter(fontSize: 28,
                    fontWeight: FontWeight.bold, color: _onSurface)),
              TextButton(
                onPressed: _markAllRead,
                child: Text('Mark all as read',
                  style: GoogleFonts.inter(color: _primary,
                      fontWeight: FontWeight.w600, fontSize: 14)),
              ),
            ],
          ),
        ),

        // List
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildList() {
    if (_uid.isEmpty) {
      return const Center(child: Text('Not signed in'));
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _ref.orderBy('createdAt', descending: true).limit(60).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _primary));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return _buildEmpty();

        // Group by date label
        final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> groups = {};
        for (final doc in docs) {
          final ts    = doc.data()['createdAt'] as Timestamp?;
          final label = ts != null ? _groupLabel(ts.toDate()) : 'EARLIER';
          groups.putIfAbsent(label, () => []).add(doc);
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            for (final entry in groups.entries) ...[
              _buildSectionHeader(entry.key),
              for (final doc in entry.value)
                _buildSwipeable(doc),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 100),
          ],
        );
      },
    );
  }

  // ── Section header (Stitch style) ────────────────────────────────────────
  Widget _buildSectionHeader(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
    child: Text(title,
      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold,
          color: Colors.grey[500], letterSpacing: 1.2)),
  );

  // ── Swipeable wrapper ────────────────────────────────────────────────────
  Widget _buildSwipeable(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return Dismissible(
      key: ValueKey(doc.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
            color: const Color(0xFFDC2626),
            borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_rounded, color: Colors.white, size: 24),
            SizedBox(height: 4),
            Text('Delete', style: TextStyle(color: Colors.white,
                fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        return await GoOutsSheet.confirm(
          context,
          title: 'Delete Notification?',
          message: 'This notification will be permanently removed.',
        );
      },
      onDismissed: (_) async {
        await _delete(doc.id);
      },
      child: _buildNotificationCard(doc),
    );
  }

  // ── Notification card (Stitch style, live data) ──────────────────────────
  Widget _buildNotificationCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data    = doc.data();
    final type    = (data['type']  ?? '').toString();
    final title   = (data['title'] ?? '').toString();
    final body    = (data['body']  ?? '').toString();
    final isRead  = data['isRead'] == true;
    final ts      = data['createdAt'] as Timestamp?;

    return GestureDetector(
      onTap: () => _onTap(data, doc.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : const Color(0xFFF0F9FF),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02),
                blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon badge
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _iconBgFor(type),
                shape: BoxShape.circle,
              ),
              child: Icon(_iconFor(type), color: _iconColorFor(type), size: 24),
            ),
            const SizedBox(width: 16),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(title,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: _onSurface,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Text(_timeLabel(ts),
                            style: GoogleFonts.inter(
                                fontSize: 12, color: Colors.grey[500])),
                          if (!isRead) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 6, height: 6,
                              decoration: const BoxDecoration(
                                  color: _primary, shape: BoxShape.circle),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(body,
                    style: GoogleFonts.inter(
                        color: _onSurfaceVariant, fontSize: 14, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty state ──────────────────────────────────────────────────────────
  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
              color: Color(0xFFE1F5FE), shape: BoxShape.circle),
          child: const Icon(Icons.notifications_none_outlined,
              color: _primary, size: 40),
        ),
        const SizedBox(height: 16),
        Text("You're all caught up",
          style: GoogleFonts.inter(fontSize: 18,
              fontWeight: FontWeight.bold, color: _onSurface)),
        const SizedBox(height: 6),
        Text("We'll notify you about important\naccount updates here.",
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 14,
              color: _onSurfaceVariant, height: 1.5)),
      ],
    ),
  );

  // ── Bottom nav (Stitch style) ────────────────────────────────────────────
  Widget _buildBottomNav() => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: Colors.grey[200]!)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _navItem(Icons.home_outlined,                   'Home',     '/home',     false),
        _navItem(Icons.explore_outlined,                'Explore',  '/explore',  false),
        _navItem(Icons.account_balance_wallet_outlined, 'Wallet',   '/wallet',   false),
        _navItem(Icons.receipt_long_outlined,           'Activity', '/activity', true),
        _navItem(Icons.person_outline,                  'Profile',  '/profile',  false),
      ],
    ),
  );

  Widget _navItem(IconData icon, String label, String route, bool isActive) {
    if (isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE1F5FE),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          Icon(icon, color: _primary, size: 20),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.inter(
              color: _primary, fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
      );
    }
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: _onSurfaceVariant, size: 24),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.inter(
            color: _onSurfaceVariant, fontSize: 11)),
      ])