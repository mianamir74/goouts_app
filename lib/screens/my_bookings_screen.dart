// The customer's advance booking requests (venue_bookings where userId is
// them). Added 10 November 2026.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/goouts_sheet.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  static const Color _primary = Color(0xFF0392CA);
  static const Color _dark = Color(0xFF0D1B3E);
  final Set<String> _busy = {};

  Color _colour(String s) {
    switch (s) {
      case 'accepted':
        return const Color(0xFF10B981);
      case 'declined':
      case 'cancelled':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  String _label(String s) {
    switch (s) {
      case 'accepted':
        return 'Confirmed';
      case 'declined':
        return 'Declined';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Waiting for venue';
    }
  }

  Future<void> _cancel(String id) async {
    final ok = await GoOutsSheet.confirm(context,
        title: 'Cancel this booking?',
        message: 'The venue will be told it is cancelled.',
        confirmLabel: 'Cancel booking',
        cancelLabel: 'Keep it',
        icon: Icons.event_busy_rounded);
    if (!ok) return;
    setState(() => _busy.add(id));
    try {
      await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('cancelMyBooking')
          .call({'bookingId': id});
    } catch (_) {
      if (mounted) {
        GoOutsSheet.error(context,
            title: 'Could not cancel', message: 'Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '_';
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text('My Bookings',
            style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w600, color: _primary)),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('venue_bookings')
            .where('userId', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Could not load your bookings.'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                    'No bookings yet. Tap Book a table on a partner page.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: Colors.grey[600])),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final d = docs[i].data();
              final id = docs[i].id;
              final status = (d['status'] ?? 'pending').toString();
              final at = d['bookingAt'];
              final future = at is Timestamp &&
                  at.toDate().isAfter(DateTime.now());
              final canCancel = future &&
                  (status == 'pending' || status == 'accepted');
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text('${d['partnerName'] ?? ''}',
                            style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _dark)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _colour(status).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(_label(status),
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _colour(status))),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Text(
                        '${d['date'] ?? ''} at ${d['time'] ?? ''}  ·  '
                        '${d['partySize'] ?? ''} people  ·  '
                        '${d['bookingType'] ?? ''}',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: Colors.grey[700])),
                    if ((d['venueMessage'] ?? '').toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('Venue: ${d['venueMessage']}',
                            style: GoogleFonts.inter(fontSize: 13)),
                      ),
                    if (canCancel)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed:
                              _busy.contains(id) ? null : () => _cancel(id),
                          child: const Text('Cancel booking',
                              style: TextStyle(color: Color(0xFFEF4444))),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
