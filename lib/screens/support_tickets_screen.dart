import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/support_ticket_service.dart';
import 'support_ticket_chat_screen.dart';

class SupportTicketsScreen extends StatefulWidget {
  const SupportTicketsScreen({super.key});

  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen> {
  static const Color _primary = Color(0xFF0392CA);
  static const Color _dark    = Color(0xFF0D1B3E);
  static const Color _teal    = Color(0xFF0A6E8A);

  final _service = SupportTicketService();
  bool _loading = true;
  List<Map<String, dynamic>> _tickets = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final tickets = await _service.getMyTickets();
    if (mounted) setState(() { _tickets = tickets; _loading = false; });
  }

  int get _openCount => _tickets.where((t) {
    final s = (t['status'] as String? ?? '').toLowerCase();
    return s == 'new' || s == 'in_progress' ||
           s == 'need_more_info' || s == 'waiting_user' || s == 'waiting_driver';
  }).length;

  // ── Open chat for a ticket ────────────────────────────────────────────────
  void _openChat(Map<String, dynamic> t) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupportTicketChatScreen(
          ticketId:     t['id']          as String,
          subject:      t['subject']     as String? ?? '',
          ticketNumber: t['ticketNumber'] as String? ?? '',
          userName:     t['fullName']    as String? ?? 'User',
        ),
      ),
    ).then((_) => _load()); // refresh after returning
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _primary, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('My Tickets',
            style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w700, color: _primary)),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _primary, strokeWidth: 2.5))
          : RefreshIndicator(
              color: _primary,
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ticket History',
                        style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: _dark)),
                    const SizedBox(height: 4),
                    Text('Track and reply to your support requests',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: Colors.grey[500])),
                    const SizedBox(height: 14),

                    // New Ticket button
                    ElevatedButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/contact-support')
                              .then((_) => _load()),
                      icon: const Icon(Icons.add_rounded,
                          color: Colors.white, size: 18),
                      label: Text('New Ticket',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _teal,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 12),
                        elevation: 0,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Overview card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2))
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Overview',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _primary)),
                          const SizedBox(height: 12),
                          _overviewRow(Icons.confirmation_number_rounded,
                              'Total Tickets', '${_tickets.length}'),
                          const SizedBox(height: 10),
                          _overviewRow(Icons.folder_open_rounded,
                              'Open Now', '$_openCount'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_tickets.isEmpty) ...[
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              Icon(Icons.inbox_rounded,
                                  size: 52, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text('No tickets yet',
                                  style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.grey[400])),
                              const SizedBox(height: 6),
                              Text('Submit a ticket and we\'ll help you out.',
                                  style: GoogleFonts.inter(
                                      fontSize: 13, color: Colors.grey[400])),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      Text('LATEST REQUESTS',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[500],
                              letterSpacing: 1.0)),
                      const SizedBox(height: 10),
                      ..._tickets.map((t) => _ticketCard(t)),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  // ── Ticket card with unread badge ─────────────────────────────────────────
  Widget _ticketCard(Map<String, dynamic> t) {
    final status    = (t['status']       as String? ?? 'new').toLowerCase();
    final style     = SupportTicketService.statusStyle(status);
    final unread    = t['unreadByUser']  as bool?   ?? false;
    final lastMsg   = t['lastMessage']   as String? ?? t['message'] as String? ?? '';
    final lastBy    = t['lastMessageBy'] as String? ?? 'user';
    final lastAt    = t['lastMessageAt'] ?? t['updatedAt'];

    return GestureDetector(
      onTap: () => _openChat(t),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: unread ? const Color(0xFFE8F4FB) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: unread
              ? Border.all(color: _primary.withOpacity(0.25))
              : null,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: ticket number + status + unread dot
            Row(
              children: [
                Text(t['ticketNumber'] as String? ?? '',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: Colors.grey[400])),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: Color(style['bg'] as int),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(style['label'] as String,
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(style['color'] as int))),
                ),
                const Spacer(),
                if (unread)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('New reply',
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
              ],
            ),
            const SizedBox(height: 6),

            // Subject
            Text(t['subject'] as String? ?? '',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _dark)),
            const SizedBox(height: 4),

            // Last message preview
            if (lastMsg.isNotEmpty)
              Text(
                '${lastBy == 'admin' ? 'Support: ' : 'You: '}$lastMsg',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: unread && lastBy == 'admin'
                        ? _primary
                        : Colors.grey[500],
                    fontWeight: unread && lastBy == 'admin'
                        ? FontWeight.w600
                        : FontWeight.normal),
              ),
            const SizedBox(height: 8),

            Row(
              children: [
                Text(SupportTicketService.formatRelative(lastAt),
                    style: GoogleFonts.inter(
                        fontSize: 11, color: Colors.grey[400])),
                const Spacer(),
                Row(
                  children: [
                    Text('Open chat',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: _primary,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 3),
                    const Icon(Icons.chevron_right_rounded,
                        color: _primary, size: 16),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _overviewRow(IconData icon, String label, String count) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                  color: Color(0xFFD6EEF8), shape: BoxShape.circle),
              child: Icon(icon, color: _teal, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: GoogleFonts.inter(fontSize: 14, color: _dark)),
            ),
            Text(count,
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _dark)),
          ],
        ),
      );

  Widget _buildBottomNav(BuildContext context) => Container(
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(context, Icons.home_rounded, 'Home', '/home'),
                _navItem(context, Icons.explore_rounded, 'Explore', '/explore'),
                _navItem(context, Icons.account_balance_wallet_rounded,
                    'Wallet', '/wallet'),
                _navItem(context, Icons.receipt_long_rounded,
                    'Activity', '/activity'),
                _navItem(context, Icons.person_rounded, 'Profile', '/profile'),
              ],
            ),
          ),
        ),
      );

  Widget _navItem(BuildContext context, IconData icon, String label,
          String route) =>
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
