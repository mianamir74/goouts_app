import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/support_ticket_service.dart';
import '../widgets/goouts_sheet.dart';

class SupportTicketChatScreen extends StatefulWidget {
  final String ticketId;
  final String subject;
  final String ticketNumber;
  final String userName;

  const SupportTicketChatScreen({
    super.key,
    required this.ticketId,
    required this.subject,
    required this.ticketNumber,
    required this.userName,
  });

  @override
  State<SupportTicketChatScreen> createState() =>
      _SupportTicketChatScreenState();
}

class _SupportTicketChatScreenState extends State<SupportTicketChatScreen> {
  static const Color _primary    = Color(0xFF0392CA);
  static const Color _dark       = Color(0xFF0D1B3E);
  static const Color _green      = Color(0xFF16A34A);
  static const Color _bg         = Color(0xFFF0F4F8);

  final _svc        = SupportTicketService();
  final _msgCtrl    = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode  = FocusNode();
  final _picker     = ImagePicker();

  String _ticketStatus = 'new';
  int    _ticketRating = 0;
  bool   _sending      = false;
  bool   _uploading    = false;

  int    _chosenRating     = 0;
  final  _ratingCtrl       = TextEditingController();
  bool   _submittingRating = false;

  @override
  void initState() {
    super.initState();
    _svc.markAdminMessagesRead(widget.ticketId);
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    _ratingCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool get _isClosed =>
      _ticketStatus == 'closed' || _ticketStatus == 'resolved';

  Future<void> _sendText() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _isClosed) return;
    setState(() => _sending = true);
    _msgCtrl.clear();
    try {
      await _svc.sendMessage(ticketId: widget.ticketId, text: text);
      _scrollToBottom();
    } catch (_) {
      if (mounted) {
        GoOutsSheet.error(context,
          title: 'Send Failed',
          message: 'Failed to send. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendImage() async {
    if (_isClosed) return;
    final picked = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final file = File(picked.path);
      final ref  = FirebaseStorage.instance.ref(
          'support_images/${widget.ticketId}/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      await _svc.sendMessage(ticketId: widget.ticketId, text: '', imageUrl: url);
      _scrollToBottom();
    } catch (_) {
      if (mounted) {
        GoOutsSheet.info(context,
          title: 'Failed to upload image',
          message: 'Failed to upload image. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submitRating() async {
    if (_chosenRating == 0) return;
    setState(() => _submittingRating = true);
    try {
      await _svc.rateTicket(
        ticketId: widget.ticketId,
        rating:   _chosenRating,
        comment:  _ratingCtrl.text.trim(),
      );
      if (mounted) {
        GoOutsSheet.info(context,
          title: 'Thank you for your',
          message: 'Thank you for your feedback!',
        );
      }
    } finally {
      if (mounted) setState(() => _submittingRating = false);
    }
  }

  // ── Status chip ────────────────────────────────────────────────────────────
  Widget _statusChip(String status) {
    final s     = SupportTicketService.statusStyle(status);
    final color = Color(s['color'] as int);
    final bg    = Color(s['bg']    as int);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(s['label'] as String,
          style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }

  // ── Date separator label ───────────────────────────────────────────────────
  Widget _dateSeparator(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Expanded(child: Divider(color: Colors.grey[300], thickness: 0.8)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(label,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[400])),
        ),
        Expanded(child: Divider(color: Colors.grey[300], thickness: 0.8)),
      ]),
    );
  }

  String _dayLabel(DateTime d) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day   = DateTime(d.year, d.month, d.day);
    final diff  = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
  }

  String _timeStr(Timestamp? ts) {
    if (ts == null) return '';
    final d  = ts.toDate();
    final h  = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m  = d.minute.toString().padLeft(2, '0');
    final ap = d.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ap';
  }

  // ── Message bubble ─────────────────────────────────────────────────────────
  Widget _bubble(Map<String, dynamic> data) {
    final isUser   = data['sender'] == 'user';
    final text     = data['text']     as String? ?? '';
    final imageUrl = data['imageUrl'] as String? ?? '';
    final ts       = data['createdAt'] as Timestamp?;
    final timeStr  = _timeStr(ts);

    return Padding(
      padding: EdgeInsets.only(
          top: 2, bottom: 2,
          left: isUser ? 48 : 0,
          right: isUser ? 0 : 48),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Support avatar
          if (!isUser) ...[
            Container(
              width: 34,
              height: 34,
              margin: const EdgeInsets.only(right: 8, bottom: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF0392CA), Color(0xFF026899)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                      color: _primary.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ],
              ),
              child: const Icon(Icons.support_agent_rounded,
                  size: 18, color: Colors.white),
            ),
          ],

          // Bubble content
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isUser)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3, left: 2),
                    child: Text('GoOuts Support',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _primary)),
                  ),
                Container(
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.70),
                  decoration: BoxDecoration(
                    gradient: isUser
                        ? const LinearGradient(
                            colors: [Color(0xFF0392CA), Color(0xFF026899)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isUser ? null : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft:     const Radius.circular(18),
                      topRight:    const Radius.circular(18),
                      bottomLeft:  Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: isUser
                              ? _primary.withValues(alpha: 0.25)
                              : Colors.black.withValues(alpha: 0.07),
                          blurRadius: 8,
                          offset: const Offset(0, 3))
                    ],
                  ),
                  child: imageUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.only(
                            topLeft:     const Radius.circular(18),
                            topRight:    const Radius.circular(18),
                            bottomLeft:  Radius.circular(isUser ? 18 : 4),
                            bottomRight: Radius.circular(isUser ? 4 : 18),
                          ),
                          child: Image.network(imageUrl,
                              width: 220, height: 160, fit: BoxFit.cover),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 11),
                          child: Text(text,
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: isUser
                                      ? Colors.white
                                      : const Color(0xFF1A1A2E),
                                  height: 1.5)),
                        ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(timeStr,
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.grey[400])),
                    if (isUser) ...[
                      const SizedBox(width: 3),
                      Icon(Icons.done_all_rounded,
                          size: 13, color: _primary.withValues(alpha: 0.7)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Rating card ────────────────────────────────────────────────────────────
  Widget _ratingCard() {
    const labels = ['', 'Poor', 'Fair', 'Good', 'Very Good', 'Excellent'];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EEF3)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: _green, size: 28),
          ),
          const SizedBox(height: 10),
          Text('Ticket Resolved',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _dark)),
          const SizedBox(height: 4),
          Text('How would you rate your support experience?',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 13, color: Colors.grey[500])),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final star = i + 1;
              return GestureDetector(
                onTap: () => setState(() => _chosenRating = star),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Icon(
                    _chosenRating >= star
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 38,
                    color: _chosenRating >= star
                        ? const Color(0xFFF59E0B)
                        : Colors.grey[300],
                  ),
                ),
              );
            }),
          ),
          if (_chosenRating > 0) ...[
            const SizedBox(height: 6),
            Text(labels[_chosenRating],
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFF59E0B))),
            const SizedBox(height: 12),
            TextField(
              controller: _ratingCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Add a comment (optional)',
                hintStyle:
                    GoogleFonts.inter(fontSize: 13, color: Colors.grey[400]),
                filled: true,
                fillColor: _bg,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              style: GoogleFonts.inter(fontSize: 13),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: _submittingRating ? null : _submitRating,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _submittingRating
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text('Submit Rating',
                        style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _svc.ticketStream(widget.ticketId),
        builder: (context, ticketSnap) {
          if (ticketSnap.hasData) {
            final d = ticketSnap.data!.data() as Map<String, dynamic>?;
            _ticketStatus = d?['status'] as String? ?? 'new';
            _ticketRating = (d?['rating'] as num?)?.toInt() ?? 0;
          }
          final showRating = _ticketStatus == 'resolved' && _ticketRating == 0;

          return Column(
            children: [
              // ── Messages list ───────────────────────────────────────────────
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _svc.messagesStream(widget.ticketId),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(
                          child: CircularProgressIndicator(color: _primary));
                    }
                    final docs = snap.data!.docs;
                    _scrollToBottom();
                    // markAdminMessagesRead called once in initState — not here

                    // Build list with date separators
                    final List<Widget> items = [];
                    String? lastDay;
                    for (final doc in docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final ts   = data['createdAt'] as Timestamp?;
                      if (ts != null) {
                        final dayLabel = _dayLabel(ts.toDate());
                        if (dayLabel != lastDay) {
                          items.add(_dateSeparator(dayLabel));
                          lastDay = dayLabel;
                        }
                      }
                      items.add(_bubble(data));
                    }

                    return ListView(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      children: items,
                    );
                  },
                ),
              ),

              // ── Rating card ─────────────────────────────────────────────────
              if (showRating) _ratingCard(),

              // ── Closed banner ───────────────────────────────────────────────
              if (_ticketStatus == 'closed')
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline_rounded,
                          size: 14, color: Colors.grey[400]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'This ticket is closed. Open a new ticket to raise another issue.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                              fontSize: 12, color: Colors.grey[500]),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Input bar ───────────────────────────────────────────────────
              if (!_isClosed) _buildInputBar(),
            ],
          );
        },
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(68),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0392CA), Color(0xFF026899)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
                color: Color(0x330392CA), blurRadius: 12, offset: Offset(0, 4))
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                // Back button
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 18, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                // Avatar
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.2),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: const Icon(Icons.support_agent_rounded,
                      size: 22, color: Colors.white),
                ),
                const SizedBox(width: 10),
                // Title + ticket number
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('GoOuts Support',
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                      Row(children: [
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(right: 5),
                          decoration: const BoxDecoration(
                              color: Color(0xFF4ADE80),
                              shape: BoxShape.circle),
                        ),
                        Text('Online  ·  ${widget.ticketNumber}',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.85))),
                      ]),
                    ],
                  ),
                ),
                // Status chip
                StreamBuilder<DocumentSnapshot>(
                  stream: _svc.ticketStream(widget.ticketId),
                  builder: (context, snap) {
                    final status =
                        snap.data?.get('status') as String? ?? _ticketStatus;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35), width: 1),
                      ),
                      child: Text(
                        SupportTicketService.statusStyle(status)['label']
                            as String,
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Input bar ──────────────────────────────────────────────────────────────
  Widget _buildInputBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 12,
              offset: const Offset(0, -3))
        ],
      ),
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Image button
          GestureDetector(
            onTap: _uploading ? null : _sendImage,
            child: Container(
              width: 42,
              height: 42,
              margin: const EdgeInsets.only(bottom: 1),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: _uploading
                  ? const Padding(
                      padding: EdgeInsets.all(11),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _primary))
                  : const Icon(Icons.image_outlined,
                      color: _primary, size: 22),
            ),
          ),
          const SizedBox(width: 8),
          // Text field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _msgCtrl,
                focusNode: _focusNode,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Write a message…',
                  hintStyle: GoogleFonts.inter(
                      fontSize: 14, color: Colors.grey[400]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 11),
                ),
                style: GoogleFonts.inter(fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send button
          GestureDetector(
            onTap: _sending ? null : _sendText,
            child: Container(
              width: 42,
              height: 42,
              margin: const EdgeInsets.only(bottom: 1),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0392CA), Color(0xFF026899)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: _primary.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3))
                ],
              ),
              child: _sending
                  ? const Padding(
                      padding: EdgeInsets.all(11),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
