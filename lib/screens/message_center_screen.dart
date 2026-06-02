import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/message_service.dart';

class MessageCenterScreen extends StatefulWidget {
  const MessageCenterScreen({super.key});

  @override
  State<MessageCenterScreen> createState() => _MessageCenterScreenState();
}

class _MessageCenterScreenState extends State<MessageCenterScreen> {
  static const Color _primary = Color(0xFF0392CA);
  static const Color _dark = Color(0xFF0D1B3E);

  final _service = MessageService();

  int _selectedTab = 0;
  bool _loading = true;
  List<Map<String, dynamic>> _allMessages = [];

  // Tab 0=All, 1=security, 2=offers, 3=updates
  final List<String> _tabs = ['All Messages', 'Security', 'Offers', 'Updates'];
  final List<String?> _categories = [null, 'security', 'offers', 'updates'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    // Seeds sample messages into users/{uid}/messages if inbox is empty
    await _service.seedIfEmpty();
    final msgs = await _service.getMessages();
    if (mounted) {
      setState(() {
        _allMessages = msgs;
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final cat = _categories[_selectedTab];
    if (cat == null) return _allMessages;
    return _allMessages
        .where((m) => (m['category'] as String?) == cat)
        .toList();
  }

  int get _totalUnread =>
      _allMessages.where((m) => MessageService.isUnread(m)).length;

  int _unreadForTab(int tab) {
    final cat = _categories[tab];
    final list = cat == null
        ? _allMessages
        : _allMessages.where((m) => m['category'] == cat).toList();
    return list.where((m) => MessageService.isUnread(m)).length;
  }

  Future<void> _onTapMessage(Map<String, dynamic> msg) async {
    final id = msg['id'] as String;
    if (MessageService.isUnread(msg)) {
      await _service.markAsRead(id);
      if (mounted) {
        setState(() {
          final idx = _allMessages.indexWhere((m) => m['id'] == id);
          if (idx != -1) {
            _allMessages[idx] = {
              ..._allMessages[idx],
              'isRead': true,
              'read': true,
              'seen': true,
            };
          }
        });
      }
    }
  }

  Future<void> _markAllRead() async {
    await _service.markAllAsRead();
    if (mounted) {
      setState(() {
        _allMessages = _allMessages.map((m) => {
          ...m,
          'isRead': true,
          'read': true,
          'seen': true,
        }).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: Colors.black87, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Text('Messages',
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _dark)),
            if (_totalUnread > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color: _primary,
                    borderRadius: BorderRadius.circular(10)),
                child: Text('$_totalUnread',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ],
          ],
        ),
        centerTitle: false,
        actions: [
          if (_totalUnread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: Text('Mark all read',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _primary)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            color: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _tabs.asMap().entries.map((entry) {
                  final i = entry.key;
                  final selected = _selectedTab == i;
                  final unread = _unreadForTab(i);
                  return GestureDetector(
                    onTap: () => setState(() => _selectedTab = i),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: selected ? _primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? _primary
                              : Colors.grey[300]!,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(entry.value,
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? Colors.white
                                      : Colors.grey[600])),
                          if (unread > 0) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: selected
                                    ? Colors.white.withOpacity(0.3)
                                    : _primary,
                                borderRadius:
                                    BorderRadius.circular(8),
                              ),
                              child: Text('$unread',
                                  style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Body
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: _primary, strokeWidth: 2.5))
                : _filtered.isEmpty
                    ? _emptyState()
                    : RefreshIndicator(
                        color: _primary,
                        onRefresh: _loadData,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                              16, 12, 16, 24),
                          itemCount: _filtered.length,
                          itemBuilder: (ctx, i) =>
                              _messageCard(_filtered[i]),
                        ),
                      ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Message card
  // ─────────────────────────────────────────────────────────────────────────
  Widget _messageCard(Map<String, dynamic> m) {
    final isUnread = MessageService.isUnread(m);
    final isUrgent = m['urgent'] as bool? ?? false;
    final category = m['category'] as String? ?? 'updates';
    final imageUrl = m['imageUrl'] as String?;
    final attachmentUrl = m['attachmentUrl'] as String?;

    return GestureDetector(
      onTap: () => _onTapMessage(m),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isUnread ? const Color(0xFFF0F8FE) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: IntrinsicHeight(
            child: Row(
              children: [
                if (isUrgent)
                  Container(width: 4, color: Colors.red),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            // Icon
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: _iconBg(category, isUrgent),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                  _icon(category, isUrgent),
                                  color:
                                      _iconColor(category, isUrgent),
                                  size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _readStr(m, [
                                            'title',
                                            'subject'
                                          ]),
                                          style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight:
                                                  FontWeight.w700,
                                              color: _dark),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Row(children: [
                                        Text(
                                          MessageService.formatTime(
                                              m['createdAt']),
                                          style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: Colors.grey[400]),
                                        ),
                                        if (isUnread) ...[
                                          const SizedBox(width: 5),
                                          Container(
                                            width: 7,
                                            height: 7,
                                            decoration:
                                                const BoxDecoration(
                                                    color: _primary,
                                                    shape: BoxShape
                                                        .circle),
                                          ),
                                        ],
                                      ]),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _readStr(m, [
                                      'body',
                                      'message',
                                      'content',
                                      'preview'
                                    ]),
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: Colors.grey[500],
                                        height: 1.4),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // Image preview
                        if ((imageUrl?.isNotEmpty == true) ||
                            (attachmentUrl?.isNotEmpty == true)) ...[
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              imageUrl ?? attachmentUrl!,
                              height: 100,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 100,
                                color: const Color(0xFFE8F4FB),
                                child: Center(
                                    child: Icon(Icons.image_rounded,
                                        color: Colors.grey[400],
                                        size: 32)),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Empty state
  // ─────────────────────────────────────────────────────────────────────────
  Widget _emptyState() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_rounded, size: 52, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('No ${_tabs[_selectedTab]}',
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[400])),
            const SizedBox(height: 6),
            Text('Nothing to show here yet.',
                style: GoogleFonts.inter(
                    fontSize: 13, color: Colors.grey[400])),
          ],
        ),
      );

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────
  String _readStr(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return '';
  }

  IconData _icon(String cat, bool urgent) {
    if (urgent) return Icons.warning_amber_rounded;
    switch (cat) {
      case 'security':
        return Icons.shield_rounded;
      case 'offers':
        return Icons.local_offer_rounded;
      default:
        return Icons.campaign_rounded;
    }
  }

  Color _iconBg(String cat, bool urgent) {
    if (urgent) return const Color(0xFFFFEBEE);
    switch (cat) {
      case 'security':
        return const Color(0xFFE8F4FB);
      case 'offers':
        return const Color(0xFFFFF3E0);
      default:
        return const Color(0xFFF0F0F0);
    }
  }

  Color _iconColor(String cat, bool urgent) {
    if (urgent) return Colors.red;
    switch (cat) {
      case 'security':
        return _primary;
      case 'offers':
        return const Color(0xFFF59E0B);
      default:
        return Colors.grey;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Bottom nav
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildBottomNav() => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, -2))
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(Icons.home_rounded, 'Home', '/home'),
                _navItem(Icons.explore_rounded, 'Explore', '/explore'),
                _navItem(Icons.account_balance_wallet_rounded,
                    'Wallet', '/wallet'),
                _navItem(Icons.receipt_long_rounded, 'Activity',
                    '/activity'),
                _navItem(Icons.person_rounded, 'Profile', '/profile'),
              ],
            ),
          ),
        ),
      );

  Widget _navItem(IconData icon, String label, String route) =>
      GestureDetector(
        onTap: () => Navigator.pushNamed(context, route),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.grey[400], size: 24),
            const SizedBox(height: 3),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 11, color: Colors.grey[400])),
          ],
        ),
      );
}
