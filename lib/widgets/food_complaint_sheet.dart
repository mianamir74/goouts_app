import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'goouts_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  showFoodComplaintSheet — the low-rating auto-complaint bottom sheet.
//
//  Extracted 4 September 2026 from food_order_tracking_screen.dart's
//  _showComplaintSheet, which had exactly one caller: the old rating bottom
//  sheet (_showRatingSheet), itself dead code once DeliveryConfirmationScreen
//  took over — see that file's own header. Rather than leave a real,
//  already-built complaint flow (real categories: missing items, wrong
//  items, cold food and so on) stranded behind dead code, or copy-paste it
//  into the new screen, it moved here — one implementation, two callers.
//
//  Call after a rating submission of 3 stars or under, from wherever that
//  submission happened.
//
//  Writes to `food_complaints` with the same shape and the same fix as the
//  original: `customerId` is the SIGNED-IN caller, not read off the order
//  (see firestore.rules — create requires customerId == request.auth.uid
//  and that the named orderId actually belongs to them).
// ─────────────────────────────────────────────────────────────────────────────
Future<void> showFoodComplaintSheet({
  required BuildContext context,
  required String orderId,
  required String restaurantId,
  required String restaurantName,
  required String? driverId,
  required int stars,
}) {
  const Color navy = Color(0xFF0D1B3E);
  const Color red = Color(0xFFEF4444);

  final categories = [
    'Late delivery',
    'Wrong items',
    'Missing items',
    'Poor packaging',
    'Cold food',
    'Driver behaviour',
    'Food quality',
    'Other',
  ];
  final selected = <String>{};
  final noteCtrl = TextEditingController();
  bool submitting = false;

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    constraints: kIsWeb && MediaQuery.of(context).size.width >= 900
        ? const BoxConstraints(maxWidth: 640)
        : null,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        Future<void> submitComplaint() async {
          if (selected.isEmpty) return;
          setSheet(() => submitting = true);
          try {
            await FirebaseFirestore.instance.collection('food_complaints').add({
              'orderId': orderId,
              'restaurantId': restaurantId,
              'restaurantName': restaurantName,
              'customerId': FirebaseAuth.instance.currentUser?.uid,
              'driverId': driverId,
              'driverRating': stars,
              'categories': selected.toList(),
              'note': noteCtrl.text.trim(),
              'status': 'open',
              'createdAt': FieldValue.serverTimestamp(),
            });
            if (ctx.mounted) Navigator.pop(ctx);
            if (context.mounted) {
              GoOutsSheet.info(context,
                title: 'Complaint submitted — our',
                message: 'Complaint submitted — our team will review it.',
              );
            }
          } catch (_) {
            setSheet(() => submitting = false);
          }
        }

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),

                // Header
                Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: red.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.sentiment_dissatisfied_rounded,
                        color: red, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('What went wrong?',
                        style: GoogleFonts.inter(
                            fontSize: 18, fontWeight: FontWeight.w800, color: navy)),
                    Text('Help us improve your experience.',
                        style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[500])),
                  ])),
                ]),
                const SizedBox(height: 20),

                // Category chips
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: categories.map((cat) {
                    final isSelected = selected.contains(cat);
                    return GestureDetector(
                      onTap: () => setSheet(() {
                        if (isSelected) {
                          selected.remove(cat);
                        } else {
                          selected.add(cat);
                        }
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? red.withValues(alpha: 0.1) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: isSelected ? red : Colors.grey.shade300,
                              width: isSelected ? 1.5 : 1),
                        ),
                        child: Text(cat,
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                                color: isSelected ? red : Colors.black54)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Note field
                TextField(
                  controller: noteCtrl,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  style: GoogleFonts.inter(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Add more details (optional)…',
                    hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFFF2F4F7),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: (submitting || selected.isEmpty) ? null : submitComplaint,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: red,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade200,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: submitting
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(
                            selected.isEmpty
                                ? 'Select at least one issue'
                                : 'Submit Complaint',
                            style: GoogleFonts.inter(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Skip for now',
                      style: GoogleFonts.inter(
                          color: Colors.grey[400], fontSize: 13)),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
