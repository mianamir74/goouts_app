// ─────────────────────────────────────────────────────────────────────────────
//  Message your host — the guest half of the conversation.
//
//  Built 21 August 2026, the same day as the host half.
//
//  ── THE OTHER END OF host_22b_guest_thread_screen.dart ──────────────────────
//
//  Both apps write the SAME documents: stay_bookings/{id}/messages. There is no
//  /stay_threads collection and no per-app copy of anything. The booking is the
//  thread, and the two people entitled to read it are already named on the
//  parent document as guestUid and hostUid.
//
//  ⚠ FOUR FIELD NAMES, AND THEY MUST MATCH THE HOST APP EXACTLY:
//
//      senderUid    the writer's uid. Required by the rules.
//      senderRole   'guest' here, 'host' there. Decides which side of the
//                   screen a bubble sits on when the reader is the other party.
//      text         the message. NOT body, NOT message, NOT content.
//      sentAt       FieldValue.serverTimestamp(), never DateTime.now().
//
//  This project's recurring fault is one fact stored under several names, so
//  firestore.rules now REFUSES a create where `text` is missing or is not a
//  1..2000 character string. If somebody renames the field in one app, that
//  app stops sending rather than quietly writing documents the other app
//  cannot read. That is the whole point of validating it in the rule.
//
//  ── WHY sentAt CANNOT BE THE PHONE'S CLOCK ──────────────────────────────────
//
//  The rule is `request.resource.data.sentAt == request.time`. A DateTime.now()
//  is rejected outright. Message timestamps are evidence in a deposit dispute
//  and a device clock can be changed by the person holding the phone.
//
//  ── NOTHING CAN BE EDITED OR DELETED ────────────────────────────────────────
//
//  Not by the guest, not by the host, not by GoOuts. The screen says so before
//  the first message rather than in a policy nobody reads, because a guest is
//  entitled to know that before they type and not after.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../theme/stay_colors.dart';

class MessageHostScreen extends StatefulWidget {
  const MessageHostScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  State<MessageHostScreen> createState() => _MessageHostScreenState();
}

class _MessageHostScreenState extends State<MessageHostScreen> {
  /// A stay does not generate more than this, and it keeps one conversation to
  /// a single bounded read.
  static const int _messageLimit = 200;

  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  bool _sending = false;
  String? _sendError;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: GoOutsColors.pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: GoOutsColors.primaryBlue),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Message your host',
          style: GoogleFonts.inter(
            color: GoOutsColors.deepNavy,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: widget.bookingId.isEmpty || uid == null
          ? _notice(
              'This conversation could not be opened.',
              'Go back to your booking and try again.',
            )
          : Column(
              children: <Widget>[
                _permanentRecordNotice(),
                Expanded(child: _messages(uid)),
                _composer(uid),
              ],
            ),
    );
  }

  // ── MESSAGES ──────────────────────────────────────────────────────────────

  Widget _messages(String uid) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('stay_bookings')
          .doc(widget.bookingId)
          .collection('messages')
          .orderBy('sentAt')
          .limit(_messageLimit)
          .snapshots(),
      builder: (context, snap) {
        // Failed is not empty. A thread that would not load and a thread with
        // nothing in it look identical, and only one of them means "your host
        // has not replied".
        if (snap.hasError) {
          return _notice(
            'We could not load this conversation.',
            '${snap.error}',
          );
        }
        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(
                color: GoOutsColors.primaryBlue, strokeWidth: 2),
          );
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            snap.data!.docs;
        if (docs.isEmpty) return _emptyThread();

        return ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final Map<String, dynamic> m = docs[i].data();
            final bool mine = (m['senderUid'] ?? '').toString() == uid;

            // Null until the server timestamp lands. "Sending…" is what is
            // actually happening; the device clock would be a guess.
            final Timestamp? ts = m['sentAt'] as Timestamp?;
            final bool showDay = i == 0 ||
                !_sameDay(ts, docs[i - 1].data()['sentAt'] as Timestamp?);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (showDay && ts != null) _dayDivider(ts.toDate()),
                _bubble(
                  text: (m['text'] ?? '').toString(),
                  mine: mine,
                  stamp: ts == null ? 'Sending…' : _time(ts.toDate()),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _bubble({
    required String text,
    required bool mine,
    required String stamp,
  }) =>
      Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          decoration: BoxDecoration(
            color: mine ? GoOutsColors.primaryBlue : GoOutsColors.cardSurface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(mine ? 14 : 4),
              bottomRight: Radius.circular(mine ? 4 : 14),
            ),
            border: mine
                ? null
                : Border.all(color: GoOutsColors.dividerGray),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                text,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.45,
                  color: mine ? Colors.white : GoOutsColors.deepNavy,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                stamp,
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  color: mine
                      ? Colors.white.withValues(alpha: 0.75)
                      : GoOutsColors.bodyText.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _dayDivider(DateTime d) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: GoOutsColors.dividerGray,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _dayLabel(d),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: GoOutsColors.bodyText,
              ),
            ),
          ),
        ),
      );

  Widget _emptyThread() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.chat_bubble_outline_rounded,
                  size: 34, color: GoOutsColors.starGray),
              const SizedBox(height: 12),
              Text(
                'No messages yet',
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: GoOutsColors.deepNavy),
              ),
              const SizedBox(height: 6),
              Text(
                'Ask about arrival times, parking, or anything you need to '
                'know. Your host sees this in their GoOuts Host app.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 13, height: 1.5, color: GoOutsColors.bodyText),
              ),
            ],
          ),
        ),
      );

  /// ⚠ BEFORE THE FIRST MESSAGE, NOT BURIED IN A POLICY. Nothing here can be
  /// edited or deleted afterwards by anyone, and a guest is entitled to know
  /// that before they type.
  Widget _permanentRecordNotice() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        color: GoOutsColors.infoBlueBg,
        child: Row(
          children: <Widget>[
            Icon(Icons.lock_outline_rounded,
                size: 14, color: GoOutsColors.bodyText),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Messages cannot be edited or deleted, by you, your host or '
                'GoOuts. They can be used to settle a dispute.',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  height: 1.4,
                  color: GoOutsColors.bodyText,
                ),
              ),
            ),
          ],
        ),
      );

  // ── COMPOSER ──────────────────────────────────────────────────────────────

  Widget _composer(String uid) => Container(
        padding: EdgeInsets.fromLTRB(
          12,
          10,
          12,
          10 + MediaQuery.of(context).viewPadding.bottom,
        ),
        decoration: const BoxDecoration(
          color: GoOutsColors.cardSurface,
          border: Border(top: BorderSide(color: GoOutsColors.dividerGray)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (_sendError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.error_outline_rounded,
                        size: 15, color: GoOutsColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _sendError!,
                        style: GoogleFonts.inter(
                            fontSize: 11.5, color: GoOutsColors.error),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 5,
                    // The rule rejects over 2000 characters. Stopping it at
                    // the keyboard is kinder than a permission error after
                    // somebody has written an essay.
                    maxLength: 2000,
                    textCapitalization: TextCapitalization.sentences,
                    style: GoogleFonts.inter(
                        fontSize: 14, color: GoOutsColors.deepNavy),
                    decoration: InputDecoration(
                      hintText: 'Write a message',
                      counterText: '',
                      hintStyle: GoogleFonts.inter(
                          fontSize: 14, color: GoOutsColors.starGray),
                      filled: true,
                      fillColor: GoOutsColors.pageBackground,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(
                            color: GoOutsColors.outlineVariant),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(
                            color: GoOutsColors.outlineVariant),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(
                            color: GoOutsColors.primaryBlue),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 46,
                  height: 46,
                  child: _sending
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: GoOutsColors.primaryBlue),
                          ),
                        )
                      : IconButton.filled(
                          onPressed: () => _send(uid),
                          icon: const Icon(Icons.send_rounded, size: 18),
                          style: IconButton.styleFrom(
                            backgroundColor: GoOutsColors.primaryBlue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      );

  Future<void> _send(String uid) async {
    final String text = _input.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _sending = true;
      _sendError = null;
    });

    try {
      await FirebaseFirestore.instance
          .collection('stay_bookings')
          .doc(widget.bookingId)
          .collection('messages')
          .add(<String, dynamic>{
        'senderUid': uid,
        // 'guest' here, 'host' in the host app. The only difference between
        // the two writers.
        'senderRole': 'guest',
        'text': text,
        // ⚠ SERVER TIME. serverTimestamp() resolves to request.time during
        // rule evaluation, which is what the rule compares against. A
        // DateTime.now() is rejected, and that is deliberate.
        'sentAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _input.clear();
      setState(() => _sending = false);
      _scrollToEnd();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        // What they wrote stays in the box. Clearing it on a failed send
        // loses the message with no way to get it back.
        _sendError =
            'That did not send. Check your connection and try again. ($e)';
      });
    }
  }

  void _scrollToEnd() {
    // The new bubble has not been laid out when this runs, so jump after the
    // frame rather than to a maxScrollExtent that is already stale.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  // ── FORMATTING ────────────────────────────────────────────────────────────

  static bool _sameDay(Timestamp? a, Timestamp? b) {
    if (a == null || b == null) return false;
    final DateTime x = a.toDate();
    final DateTime y = b.toDate();
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }

  static String _time(DateTime d) => DateFormat('HH:mm').format(d);

  static String _dayLabel(DateTime d) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime that = DateTime(d.year, d.month, d.day);
    final int diff = today.difference(that).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('d MMMM yyyy').format(d);
  }

  Widget _notice(String title, String detail) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.cloud_off_rounded,
                  size: 34, color: GoOutsColors.starGray),
              const SizedBox(height: 12),
              Text(title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: GoOutsColors.deepNavy)),
              const SizedBox(height: 8),
              Text(detail,
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 12.5,
                      height: 1.45,
                      color: GoOutsColors.bodyText)),
            ],
          ),
        ),
      );
}
