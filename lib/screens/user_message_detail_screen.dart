import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'support_ticket_chat_screen.dart';

class UserMessageDetailScreen extends StatefulWidget {
  final String messageId;
  final String senderName;
  final String title;
  final String body;
  final String createdAtLabel;
  final bool isRead;
  final String? ticketId;
  final String? ticketNumber;
  final String? imageUrl;
  final String? imageCaption;
  final String? ctaLabel;
  final String? ctaValue;

  const UserMessageDetailScreen({
    super.key,
    required this.messageId,
    required this.senderName,
    required this.title,
    required this.body,
    required this.createdAtLabel,
    required this.isRead,
    this.ticketId,
    this.ticketNumber,
    this.imageUrl,
    this.imageCaption,
    this.ctaLabel,
    this.ctaValue,
  });

  @override
  State<UserMessageDetailScreen> createState() =>
      _UserMessageDetailScreenState();
}

class _UserMessageDetailScreenState extends State<UserMessageDetailScreen> {
  static const Color _goOutsBlue = Color(0xFF0392CA);
  static const Color _screenBackground = Color(0xFFF2F3F7);

  @override
  void initState() {
    super.initState();
    _markAsRead();
  }

  Future<void> _markAsRead() async {
    if (widget.isRead) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('messages')
          .doc(widget.messageId)
          .set(
        <String, dynamic>{
          'isRead': true,
          'read': true,
          'seen': true,
          'readAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final hasTicket =
        widget.ticketId != null && widget.ticketId!.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: _screenBackground,
      appBar: AppBar(
        backgroundColor: _goOutsBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Message',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton.icon(
            onPressed: () =>
                Navigator.pushNamed(context, '/support-tickets'),
            icon: const Icon(
              Icons.support_agent_rounded,
              color: Colors.white,
              size: 18,
            ),
            label: Text(
              'My Tickets',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          children: [
            // ── Header card ──────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _goOutsBlue.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.mail_outline_rounded,
                      color: _goOutsBlue,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.senderName,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF6B7280),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.title,
                          style: GoogleFonts.inter(
                            fontSize: 19,
                            color: const Color(0xFF1F2937),
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.createdAtLabel,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: _goOutsBlue,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Body card ────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                widget.body,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  height: 1.65,
                  color: const Color(0xFF374151),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // ── Promo image ───────────────────────────────────────────
            if (widget.imageUrl != null && widget.imageUrl!.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.network(
                  widget.imageUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              if (widget.imageCaption != null && widget.imageCaption!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  widget.imageCaption!,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],

            // ── CTA button ────────────────────────────────────────────
            if (widget.ctaLabel != null && widget.ctaLabel!.trim().isNotEmpty &&
                widget.ctaValue != null && widget.ctaValue!.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _goOutsBlue),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    widget.ctaLabel!,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: _goOutsBlue,
                    ),
                  ),
                ),
              ),
            ],

            // ── Open Chat button (admin/support messages only) ────────
            if (hasTicket) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SupportTicketChatScreen(
                          ticketId: widget.ticketId!,
                          subject: widget.title,
                          ticketNumber: widget.ticketNumber ?? '',
                          userName: 'GoOuts Support',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.chat_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  label: Text(
                    'Open Support Chat',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _goOutsBlue,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
