import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/support_ticket_service.dart';

class SupportTicketsScreen extends StatefulWidget {
  const SupportTicketsScreen({super.key});

  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen> {
  static const Color _primary = Color(0xFF0392CA);
  static const Color _dark = Color(0xFF0D1B3E);
  static const Color _teal = Color(0xFF0A6E8A);

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

  int get _openCount =>
      _tickets.where((t) {
        final s = (t['status'] as String? ?? '').toLowerCase();
        return s == 'new' || s == 'open' || s == 'pending';
      }).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: _primary, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('My Tickets',
            style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _primary)),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF0392CA), strokeWidth: 2.5))
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
                    Text('Track and manage your support requests',
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
                          Text('Active Overview',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _primary)),
                          const SizedBox(height: 12),
                          _overviewRow(
                              Icons.confirmation_number_rounded,
                              'Total Tickets',
                              '${_tickets.length}'),
                          const SizedBox(height: 10),
                          _overviewRow(
                              Icons.folder_open_rounded,
                              'Open Now',
                              '$_openCount'),
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
                                      fontSize: 13,
                                      color: Colors.grey[400])),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Text('LATEST REQUESTS',
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[500],
                                  letterSpacing: 1.0)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ..._tickets.map((t) => _ticketCard(context, t)),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  Widget _overviewRow(IconData icon, String label, String count) =>
      Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 10),
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

  Widget _ticketCard(BuildContext context, Map<String, dynamic> t) {
    final status = (t['status'] as String? ?? 'new').toLowerCase();
    final style = SupportTicketService.statusStyle(status);
    final hasReply = (t['adminReply'] as String? ?? '').isNotEmpty;

    return GestureDetector(
      onTap: () => _showTicketDetail(context, t),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
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
            Row(
              children: [
                Text(t['ticketNumber'] as String? ?? '',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: Colors.grey[400])),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Color(style['bg'] as int),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(style['label'] as String,
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(style['color'] as int))),
                ),
                if (hasReply) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F4FB),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Reply received',
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _primary)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(t['subject'] as String? ?? '',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _dark)),
            const SizedBox(height: 3),
            Text(t['categoryLabel'] as String? ?? '',
                style: GoogleFonts.inter(
                    fontSize: 12, color: Colors.grey[500])),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                    SupportTicketService.formatDate(t['createdAt']),
                    style: GoogleFonts.inter(
                        fontSize: 12, color: Colors.grey[500])),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded,
                    color: Colors.grey, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Ticket detail bottom sheet
  // ─────────────────────────────────────────────────────────────────────────
  void _showTicketDetail(
      BuildContext context, Map<String, dynamic> t) {
    final status = (t['status'] as String? ?? 'new').toLowerCase();
    final style = SupportTicketService.statusStyle(status);
    final adminReply = t['adminReply'] as String? ?? '';
    final hasReply = adminReply.isNotEmpty;
    final isResolved = status == 'resolved';
    final hasRating = (t['rating'] as int? ?? 0) > 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Color(style['bg'] as int),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(style['label'] as String,
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(
                                        style['color'] as int))),
                          ),
                          const SizedBox(width: 8),
                          Text(
                              t['ticketNumber'] as String? ?? '',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.grey[400])),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(t['subject'] as String? ?? '',
                          style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _dark)),
                      const SizedBox(height: 4),
                      Text(
                          '${t['categoryLabel'] ?? ''} • ${SupportTicketService.formatDate(t['createdAt'])}',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey[500])),

                      const SizedBox(height: 20),

                      // Your message
                      _detailSection(
                        icon: Icons.person_outline_rounded,
                        label: 'Your Message',
                        content: t['message'] as String? ?? '',
                        iconColor: _teal,
                      ),

                      // Admin reply
                      if (hasReply) ...[
                        const SizedBox(height: 16),
                        _detailSection(
                          icon: Icons.support_agent_rounded,
                          label: 'Support Reply',
                          content: adminReply,
                          iconColor: _primary,
                          bgColor: const Color(0xFFF0F8FE),
                          footerText: t['adminRepliedAt'] != null
                              ? 'Replied ${SupportTicketService.formatRelative(t['adminRepliedAt'])}'
                              : null,
                        ),
                      ] else ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFFF59E0B)
                                    .withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                  Icons.hourglass_top_rounded,
                                  color: Color(0xFFF59E0B),
                                  size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                    'Awaiting reply from support team. Usually within 2 hours.',
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: const Color(0xFF92400E),
                                        height: 1.4)),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Rating section for resolved tickets
                      if (isResolved && !hasRating) ...[
                        const SizedBox(height: 20),
                        _ratingSection(context, t),
                      ],

                      if (isResolved && hasRating) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: Color(0xFF388E3C), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                  'You rated this ticket ${t['ratingLabel']} (${t['rating']}/5)',
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: const Color(0xFF1B5E20),
                                      fontWeight: FontWeight.w600)),
                            ],
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
    );
  }

  Widget _detailSection({
    required IconData icon,
    required String label,
    required String content,
    required Color iconColor,
    Color bgColor = const Color(0xFFF5F5F5),
    String? footerText,
  }) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 16),
                const SizedBox(width: 6),
                Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: iconColor)),
              ],
            ),
            const SizedBox(height: 8),
            Text(content,
                style: GoogleFonts.inter(
                    fontSize: 14, color: _dark, height: 1.5)),
            if (footerText != null) ...[
              const SizedBox(height: 8),
              Text(footerText,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: Colors.grey[400])),
            ],
          ],
        ),
      );

  Widget _ratingSection(
      BuildContext context, Map<String, dynamic> t) {
    int selectedRating = 0;
    final commentCtrl = TextEditingController();

    return StatefulBuilder(
      builder: (ctx, setLocal) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rate this support experience',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _dark)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final star = i + 1;
                return GestureDetector(
                  onTap: () =>
                      setLocal(() => selectedRating = star),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.star_rounded,
                        size: 36,
                        color: star <= selectedRating
                            ? const Color(0xFFF59E0B)
                            : Colors.grey[300]),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF0F6FA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: commentCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Any additional feedback? (optional)',
                  hintStyle: GoogleFonts.inter(
                      fontSize: 13, color: Colors.grey[400]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(12),
                ),
                style:
                    GoogleFonts.inter(fontSize: 13, color: _dark),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: selectedRating == 0
                    ? null
                    : () async {
                        await _service.rateTicket(
                          ticketId: t['id'] as String,
                          rating: selectedRating,
                          comment: commentCtrl.text,
                        );
                        if (mounted) {
                          Navigator.pop(context); // close sheet
                          _load(); // refresh list
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  disabledBackgroundColor: Colors.grey[200],
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: Text('Submit Rating',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: selectedRating == 0
                            ? Colors.grey
                            : Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(context, Icons.home_rounded, 'Home', '/home'),
                _navItem(context,
                    Icons.account_balance_wallet_rounded, 'Wallet', '/wallet'),
                _navItemActive(),
                _navItem(
                    context, Icons.person_rounded, 'Profile', '/profile'),
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

  Widget _navItemActive() => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE0F3FB),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.help_outline_rounded,
                color: _primary, size: 22),
            const SizedBox(width: 6),
            Text('Support',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _primary)),
          ],
        ),
      );
}
