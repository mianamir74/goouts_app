import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'support_ticket_chat_screen.dart';
import 'user_message_detail_screen.dart';
import '../widgets/goouts_sheet.dart';

const Color _primary          = Color(0xFF0392CA);
const Color _surfaceColor     = Color(0xFFF9F9FC);
const Color _onSurface        = Color(0xFF191C1E);
const Color _onSurfaceVariant = Color(0xFF42474E);
const Color _securityRed      = Color(0xFFB3261E);

class MessageCenterScreen extends StatefulWidget {
  const MessageCenterScreen({super.key});

  @override
  State<MessageCenterScreen> createState() => _MessageCenterScreenState();
}

class _MessageCenterScreenState extends State<MessageCenterScreen> {
  int    _selectedFilter = 0; // 0=All 1=Security 2=Offers 3=Updates
  String _searchQuery    = '';
  bool   _showSearch     = false;
  bool   _isArchiveView  = false;
  final  _searchCtrl     = TextEditingController();

  static const List<String> _filters = ['All Messages', 'Security', 'Offers', 'Updates'];

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> get _inbox =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('messages');

  // ── Firestore helpers ────────────────────────────────────────────────────
  Future<void> _delete(String id) async {
    if (_uid.isEmpty) return;
    await _inbox.doc(id).delete();
  }

  Future<void> _archive(String id) async {
    if (_uid.isEmpty) return;
    await _inbox.doc(id).set({'isArchived': true}, SetOptions(merge: true));
  }

  Future<void> _unarchive(String id) async {
    if (_uid.isEmpty) return;
    await _inbox.doc(id).set({'isArchived': false}, SetOptions(merge: true));
  }

  Future<void> _markRead(String id) async {
    if (_uid.isEmpty) return;
    await _inbox.doc(id).set({'isRead': true, 'read': true},
        SetOptions(merge: true));
  }

  // ── Filtering ────────────────────────────────────────────────────────────
  bool _matchesFilter(Map<String, dynamic> data) {
    switch (_selectedFilter) {
      case 1: // Security
        return (data['category'] ?? '').toString().toLowerCase() == 'security' ||
               data['urgent'] == true;
      case 2: // Offers
        return (data['category'] ?? '').toString().toLowerCase() == 'offers' ||
               (data['contentType'] ?? '').toString().toLowerCase() == 'promo';
      case 3: // Updates
        return (data['category'] ?? '').toString().toLowerCase() == 'updates';
      default:
        return true;
    }
  }

  bool _matchesSearch(Map<String, dynamic> data) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery.toLowerCase();
    return (data['title']   ?? '').toString().toLowerCase().contains(q) ||
           (data['body']    ?? '').toString().toLowerCase().contains(q) ||
           (data['preview'] ?? '').toString().toLowerCase().contains(q);
  }

  // ── Navigation ───────────────────────────────────────────────────────────
  void _openMessage(BuildContext context, String docId, Map<String, dynamic> data) async {
    await _markRead(docId);
    if (!context.mounted) return;

    final tid = (data['ticketId'] ?? '').toString().trim();
    if (tid.isNotEmpty) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => SupportTicketChatScreen(
          ticketId: tid,
          subject: (data['title'] ?? 'Support').toString(),
          ticketNumber: (data['ticketNumber'] ?? tid.substring(0, 8).toUpperCase()).toString(),
          userName: (data['senderName'] ?? 'GoOuts Admin').toString(),
        ),
      ));
      return;
    }

    Navigator.push(context, MaterialPageRoute(
      builder: (_) => UserMessageDetailScreen(
        messageId:       docId,
        senderName:      (data['senderName']  ?? 'GoOuts Admin').toString(),
        title:           (data['title']       ?? '').toString(),
        body:            (data['body']        ?? data['message'] ?? '').toString(),
        createdAtLabel:  _timeLabel(data['createdAt'] as Timestamp?),
        isRead:          data['isRead'] == true,
        ticketId:        null,
        ticketNumber:    null,
        imageUrl:        _str(data, ['imageUrl', 'attachmentUrl']),
        imageCaption:    _str(data, ['imageCaption', 'subtitle']),
        ctaLabel:        _str(data, ['ctaLabel']),
        ctaValue:        _str(data, ['ctaValue']),
      ),
    ));
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  String? _str(Map<String, dynamic> d, List<String> keys) {
    for (final k in keys) {
      final v = (d[k] ?? '').toString().trim();
      if (v.isNotEmpty) return v;
    }
    return null;
  }

  String _timeLabel(Timestamp? ts) {
    if (ts == null) return '';
    final dt   = ts.toDate();
    final now  = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1)  return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    if (diff.inDays == 1)    return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  // ── Icon / colour per category ───────────────────────────────────────────
  IconData _iconFor(Map<String, dynamic> data) {
    final cat = (data['category'] ?? '').toString().toLowerCase();
    final urgent = data['urgent'] == true;
    if (cat == 'security' || urgent) return Icons.shield_outlined;
    if (cat == 'offers')             return Icons.celebration_outlined;
    if (cat == 'updates')            return Icons.auto_awesome_outlined;
    return Icons.mail_outline_rounded;
  }

  Color _iconBgFor(Map<String, dynamic> data) {
    final cat    = (data['category'] ?? '').toString().toLowerCase();
    final urgent = data['urgent'] == true;
    if (cat == 'security' || urgent) return const Color(0xFFFFEBEE);
    if (cat == 'offers')             return const Color(0xFFE0F2F1);
    if (cat == 'updates')            return const Color(0xFFE1F5FE);
    return const Color(0xFFF5F5F5);
  }

  Color _iconColorFor(Map<String, dynamic> data) {
    final cat    = (data['category'] ?? '').toString().toLowerCase();
    final urgent = data['urgent'] == true;
    if (cat == 'security' || urgent) return _securityRed;
    if (cat == 'offers')             return const Color(0xFF00897B);
    if (cat == 'updates')            return _primary;
    return Colors.grey.shade600;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceColor,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            // Search bar (shown when search tapped)
            if (_showSearch) _buildSearchBar(),

            // Filter chips
            _buildFilterRow(),

            // Message list
            Expanded(child: _buildList()),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  // ── AppBar ───────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: Colors.white,
    elevation: 0,
    leading: _isArchiveView
        ? IconButton(
            icon: const Icon(Icons.arrow_back, color: _onSurface),
            onPressed: () => setState(() => _isArchiveView = false),
          )
        : IconButton(
            icon: const Icon(Icons.arrow_back, color: _onSurface),
            onPressed: () => Navigator.maybePop(context),
          ),
    centerTitle: false,
    title: Text(
      _isArchiveView ? 'Archived' : 'Messages',
      style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold,
          color: const Color(0xFF003354)),
    ),
    actions: [
      if (!_isArchiveView)
        IconButton(
          icon: Icon(_showSearch ? Icons.search_off : Icons.search,
              color: _onSurfaceVariant),
          onPressed: () => setState(() {
            _showSearch = !_showSearch;
            if (!_showSearch) { _searchQuery = ''; _searchCtrl.clear(); }
          }),
        ),
      // Archive folder toggle
      IconButton(
        tooltip: _isArchiveView ? 'Back to Inbox' : 'Archived Messages',
        icon: Icon(
          _isArchiveView ? Icons.inbox_rounded : Icons.archive_outlined,
          color: _isArchiveView ? _primary : _onSurfaceVariant,
        ),
        onPressed: () => setState(() {
          _isArchiveView = !_isArchiveView;
          _searchQuery = '';
          _searchCtrl.clear();
          _showSearch = false;
        }),
      ),
      const SizedBox(width: 4),
    ],
  );

  // ── Search bar ───────────────────────────────────────────────────────────
  Widget _buildSearchBar() => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: TextField(
      controller: _searchCtrl,
      autofocus: true,
      onChanged: (v) => setState(() => _searchQuery = v),
      decoration: InputDecoration(
        hintText: 'Search messages...',
        hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontSize: 14),
        prefixIcon: const Icon(Icons.search, color: _primary, size: 20),
        filled: true,
        fillColor: const Color(0xFFF1F1F1),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
      ),
    ),
  );

  // ── Filter chips ─────────────────────────────────────────────────────────
  Widget _buildFilterRow() => Container(
    height: 64,
    color: Colors.white,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _filters.length,
      itemBuilder: (_, i) => GestureDetector(
        onTap: () => setState(() => _selectedFilter = i),
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: _selectedFilter == i ? _primary : const Color(0xFFF1F1F1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(_filters[i],
            style: GoogleFonts.inter(
              color: _selectedFilter == i ? Colors.white : _onSurfaceVariant,
              fontSize: 14,
              fontWeight: _selectedFilter == i
                  ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    ),
  );

  // ── Message list ─────────────────────────────────────────────────────────
  Widget _buildList() {
    if (_uid.isEmpty) return const Center(child: Text('Not signed in'));
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _inbox.orderBy('createdAt', descending: true).limit(60).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _primary));
        }
        final all = (snap.data?.docs ?? [])
            .where((d) => _isArchiveView
                ? d.data()['isArchived'] == true
                : d.data()['isArchived'] != true)
            .where((d) => _matchesFilter(d.data()))
            .where((d) => _matchesSearch(d.data()))
            .toList();

        if (all.isEmpty) return _buildEmpty();

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: all.length,
          itemBuilder: (context, i) {
            final doc  = all[i];
            final data = doc.data();
            return _buildSwipeableCard(context, doc.id, data);
          },
        );
      },
    );
  }

  // ── Swipeable card ────────────────────────────────────────────────────────
  Widget _buildSwipeableCard(BuildContext context, String docId,
      Map<String, dynamic> data) {
    return Dismissible(
      key: ValueKey(docId),
      direction: DismissDirection.horizontal,

      // Right swipe → Archive (inbox) or Unarchive (archive view)
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
            color: _isArchiveView
                ? const Color(0xFF0392CA)
                : const Color(0xFF6366F1),
            borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isArchiveView ? Icons.inbox_rounded : Icons.archive_rounded,
              color: Colors.white, size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              _isArchiveView ? 'Restore' : 'Archive',
              style: const TextStyle(color: Colors.white,
                  fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),

      // Left swipe → Delete
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
            color: const Color(0xFFDC2626),
            borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_rounded, color: Colors.white, size: 26),
            SizedBox(height: 4),
            Text('Delete', style: TextStyle(color: Colors.white,
                fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),

      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Archive / Unarchive — no dialog needed
          return true;
        }
        // Delete — branded confirm sheet
        return await GoOutsSheet.confirm(
          context,
          title: 'Delete Message?',
          message: 'This will permanently remove the message.',
        );
      },

      onDismissed: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          if (_isArchiveView) {
            await _unarchive(docId);
            if (context.mounted) {
              GoOutsSheet.info(context,
                title: 'Moved to inbox',
                message: 'Moved to inbox',
              );
            }
          } else {
            await _archive(docId);
            if (context.mounted) {
              GoOutsSheet.info(context,
                title: 'Message archived',
                message: 'Message archived',
              );
            }
          }
        } else {
          await _delete(docId);
          if (context.mounted) {
            GoOutsSheet.error(context,
              title: 'Message deleted',
              message: 'Message deleted',
            );
          }
        }
      },

      child: _buildMessageCard(context, docId, data),
    );
  }

  // ── Three-dot menu actions ────────────────────────────────────────────────
  Future<void> _showCardMenu(
      BuildContext context, String docId, Map<String, dynamic> data) async {
    final isRead     = data['isRead'] == true || data['read'] == true;
    final isArchived = data['isArchived'] == true;

    final result = await showMenu<String>(
      context: context,
      position: _menuPosition(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 8,
      items: [
        // Mark read / unread
        PopupMenuItem(
          value: isRead ? 'unread' : 'read',
          child: Row(children: [
            Icon(
              isRead
                  ? Icons.mark_email_unread_outlined
                  : Icons.mark_email_read_outlined,
              size: 20,
              color: _primary,
            ),
            const SizedBox(width: 12),
            Text(
              isRead ? 'Mark as Unread' : 'Mark as Read',
              style: GoogleFonts.inter(fontSize: 14),
            ),
          ]),
        ),

        // Archive / Unarchive
        PopupMenuItem(
          value: isArchived ? 'unarchive' : 'archive',
          child: Row(children: [
            Icon(
              isArchived ? Icons.inbox_rounded : Icons.archive_outlined,
              size: 20,
              color: const Color(0xFF6366F1),
            ),
            const SizedBox(width: 12),
            Text(
              isArchived ? 'Move to Inbox' : 'Archive',
              style: GoogleFonts.inter(fontSize: 14),
            ),
          ]),
        ),

        const PopupMenuDivider(),

        // Delete
        PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            const Icon(Icons.delete_outline_rounded,
                size: 20, color: Color(0xFFDC2626)),
            const SizedBox(width: 12),
            Text('Delete',
                style: GoogleFonts.inter(
                    fontSize: 14, color: const Color(0xFFDC2626))),
          ]),
        ),
      ],
    );

    if (result == null || !context.mounted) return;

    switch (result) {
      case 'read':
        await _markRead(docId);
        break;
      case 'unread':
        await _inbox.doc(docId).set(
            {'isRead': false, 'read': false}, SetOptions(merge: true));
        break;
      case 'archive':
        await _archive(docId);
        if (context.mounted) {
          GoOutsSheet.info(context,
            title: 'Message archived',
            message: 'Message archived',
          );
        }
        break;
      case 'unarchive':
        await _unarchive(docId);
        if (context.mounted) {
          GoOutsSheet.info(context,
            title: 'Moved to inbox',
            message: 'Moved to inbox',
          );
        }
        break;
      case 'delete':
        final confirmed = await GoOutsSheet.confirm(
          context,
          title: 'Delete Message?',
          message: 'This will permanently remove the message.',
        );
        if (confirmed) {
          await _delete(docId);
          if (context.mounted) {
            GoOutsSheet.error(context,
              title: 'Message deleted',
              message: 'Message deleted',
            );
          }
        }
        break;
    }
  }

  // Calculate menu position near top-right of the card
  RelativeRect _menuPosition(BuildContext context) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) {
      return RelativeRect.fromLTRB(
          MediaQuery.of(context).size.width - 60, 100, 16, 0);
    }
    final Offset position = box.localToGlobal(
        Offset(box.size.width - 48, box.size.height / 2),
        ancestor: overlay);
    return RelativeRect.fromLTRB(
        position.dx, position.dy, 16, 0);
  }

  // ── Message card (Stitch style) ───────────────────────────────────────────
  Widget _buildMessageCard(BuildContext context, String docId,
      Map<String, dynamic> data) {
    final title    = (data['title']   ?? 'GoOuts Message').toString();
    final preview  = (data['preview'] ?? data['body'] ?? '').toString();
    final isRead   = data['isRead'] == true || data['read'] == true;
    final urgent   = data['urgent'] == true;
    final isArchived = data['isArchived'] == true;
    final imageUrl = _str(data, ['imageUrl', 'attachmentUrl']);
    final ts       = data['createdAt'] as Timestamp?;

    return GestureDetector(
      onTap: () => _openMessage(context, docId, data),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isRead ? Colors.white : const Color(0xFFF0F9FF),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02),
                blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Accent bar for urgent/security
              if (urgent)
                Container(width: 4, color: _securityRed),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon circle
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                color: _iconBgFor(data),
                                shape: BoxShape.circle),
                            child: Icon(_iconFor(data),
                                color: _iconColorFor(data), size: 20),
                          ),
                          const SizedBox(width: 12),

                          // Title + preview
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Unread dot
                                    if (!isRead) ...[
                                      Container(
                                        width: 8, height: 8,
                                        margin: const EdgeInsets.only(right: 6),
                                        decoration: const BoxDecoration(
                                            color: _primary,
                                            shape: BoxShape.circle),
                                      ),
                                    ],
                                    Expanded(
                                      child: Text(title,
                                        style: GoogleFonts.inter(
                                          fontWeight: isRead
                                              ? FontWeight.w600
                                              : FontWeight.bold,
                                          color: _onSurface,
                                          fontSize: 15,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(preview,
                                  style: GoogleFonts.inter(
                                      color: _onSurfaceVariant,
                                      fontSize: 13, height: 1.4),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Text(_timeLabel(ts),
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: Colors.grey[400])),
                              ],
                            ),
                          ),

                          // ── Three-dot menu button ──────────────────────
                          GestureDetector(
                            onTap: () =>
                                _showCardMenu(context, docId, data),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(8, 0, 4, 0),
                              child: Icon(Icons.more_vert_rounded,
                                  size: 20, color: Colors.grey[400]),
                            ),
                          ),
                        ],
                      ),

                      // Inline image
                      if (imageUrl != null && imageUrl.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            imageUrl,
                            height: 100,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox(),
                          ),
                        ),
                      ],

                      // Archive badge (shown in archive view)
                      if (isArchived) ...[
                        const SizedBox(height: 8),
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDE9FE),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.archive_outlined,
                                  size: 11, color: Color(0xFF6366F1)),
                              const SizedBox(width: 4),
                              Text('Archived',
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF6366F1))),
                            ]),
                          ),
                        ]),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
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
          decoration: BoxDecoration(
              color: _isArchiveView
                  ? const Color(0xFFEDE9FE)
                  : const Color(0xFFE1F5FE),
              shape: BoxShape.circle),
          child: Icon(
            _isArchiveView
                ? Icons.archive_outlined
                : Icons.mail_outline_rounded,
            color: _isArchiveView ? const Color(0xFF6366F1) : _primary,
            size: 40,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _isArchiveView ? 'No archived messages' : 'No messages yet',
          style: GoogleFonts.inter(fontSize: 18,
              fontWeight: FontWeight.bold, color: _onSurface),
        ),
        const SizedBox(height: 6),
        Text(
          _isArchiveView
              ? "Swipe right on a message\nto archive it."
              : "Admin messages and updates\nwill appear here.",
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 14,
              color: _onSurfaceVariant, height: 1.5),
        ),
      ],
    ),
  );

  // ── Bottom nav (Stitch style) ────────────────────────────────────────────
  Widget _buildBottomNav(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: Colors.grey[200]!)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _navItem(context, Icons.home_outlined,                   'Home',     '/home',     false),
        _navItem(context, Icons.explore_outlined,                'Explore',  '/explore',  false),
        _navItem(context, Icons.account_balance_wallet_outlined, 'Wallet',   '/wallet',   false),
        _navItem(context, Icons.notifications_none,              'Activity', '/activity', true),
        _navItem(context, Icons.person_outline,                  'Profile',  '/profile',  false),
      ],
    ),
  );

  Widget _navItem(BuildContext ctx, IconData icon, String label,
      String route, bool isActive) {
    if (isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFFE1F5FE),
            borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          Icon(icon, color: _primary, size: 20),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.inter(
              color: _primary, fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
      );
    }
    return GestureDetector(
      onTap: () => Navigator.pushNamed(ctx, route),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: _onSurfaceVariant, size: 24),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.inter(
            color: _onSurfaceVariant, fontSize: 11)),
      ]),
    );
  }
}
