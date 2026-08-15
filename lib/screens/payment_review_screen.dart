import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/transaction_service.dart';
import '../widgets/goouts_sheet.dart';

class PaymentReviewScreen extends StatefulWidget {
  const PaymentReviewScreen({super.key});

  @override
  State<PaymentReviewScreen> createState() => _PaymentReviewScreenState();
}

class _PaymentReviewScreenState extends State<PaymentReviewScreen> {
  static const Color _primary = Color(0xFF0392CA);
  static const Color _dark = Color(0xFF191C1E);
  static const Color _green = Color(0xFF0A7A3E);

  int _starRating = 0;
  int _submittedRating = 0;
  final _reviewController = TextEditingController();
  String _submittedReview = '';
  bool _reviewSubmitted = false;
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submitReview(String merchant, double amount, double cashback) async {
    if (_starRating == 0) {
      GoOutsSheet.warning(context,
        title: 'Rating Required',
        message: 'Please select a star rating first.',
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await TransactionService().addReview(
        merchant: merchant,
        rating: _starRating,
        review: _reviewController.text.trim(),
        amount: amount,
        cashback: cashback,
        transactionId: '',
      );
      if (!mounted) return;
      setState(() {
        _reviewSubmitted = true;
        _isEditing = false;
        _submittedRating = _starRating;
        _submittedReview = _reviewController.text.trim();
        _isSaving = false;
      });
      if (mounted) {
        GoOutsSheet.success(context,
          title: 'Review Submitted',
          message: 'Review submitted! Thank you.',
        );
      }
    } catch (_) {
      setState(() => _isSaving = false);
      if (mounted) {
        GoOutsSheet.error(context,
          title: 'Submission Failed',
          message: 'Failed to submit review. Please try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final merchant = args?['merchant'] as String? ?? 'Partner';
    final amount = (args?['amount'] as num?)?.toDouble() ?? 0.0;
    final cashback = (args?['cashback'] as num?)?.toDouble() ?? 0.0;
    final cashbackPct = (args?['cashbackPct'] as num?)?.toDouble() ?? 0.0;
    final walletPortion = (args?['walletPortion'] as num?)?.toDouble() ?? amount;
    final bankPortion = (args?['bankPortion'] as num?)?.toDouble() ?? 0.0;
    final now = DateTime.now();
    final timeStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}  '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _primary, size: 18),
          onPressed: () => Navigator.of(context).popUntil((r) => r.settings.name == '/home' || r.isFirst),
        ),
        title: Text(
          'Payment Receipt',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: _primary),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── Receipt ticket ─────────────────────────────────────────────
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Green success header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0A7A3E),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_rounded,
                              color: Colors.white, size: 32),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Payment Successful',
                          style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          merchant,
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.85)),
                        ),
                      ],
                    ),
                  ),

                  // Dotted separator
                  _DottedDivider(),

                  // Receipt rows
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
                    child: Column(
                      children: [
                        _receiptRow('Total Paid', '£${amount.toStringAsFixed(2)}', bold: true),
                        if (walletPortion > 0)
                          _receiptRow('  → GoOuts Wallet', '-£${walletPortion.toStringAsFixed(2)}',
                              color: _primary),
                        if (bankPortion > 0)
                          _receiptRow('  → Bank Card', '-£${bankPortion.toStringAsFixed(2)}',
                              color: Colors.orange[700]!),
                        const SizedBox(height: 8),
                        const Divider(height: 1, color: Color(0xFFEEEEEE)),
                        const SizedBox(height: 8),
                        _receiptRow('Cashback Rate', '$cashbackPct% back'),
                        _receiptRow('Cashback Earned', '+£${cashback.toStringAsFixed(2)}',
                            color: _green, bold: true),
                        const SizedBox(height: 8),
                        const Divider(height: 1, color: Color(0xFFEEEEEE)),
                        const SizedBox(height: 8),
                        _receiptRow('Date & Time', timeStr),
                        _receiptRow('Status', 'Completed', color: _green),
                      ],
                    ),
                  ),

                  // Cashback badge
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6F4EC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_wallet_rounded,
                              color: Color(0xFF0A7A3E), size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '£${cashback.toStringAsFixed(2)} cashback added to your wallet!',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF0A7A3E),
                                  height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Rate & Review card ─────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        _reviewSubmitted && !_isEditing
                            ? 'Your Review'
                            : 'Rate Your Experience',
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _dark),
                      ),
                      const Spacer(),
                      // Edit button (like Uber / Deliveroo)
                      if (_reviewSubmitted && !_isEditing)
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _isEditing = true;
                              _starRating = _submittedRating;
                              _reviewController.text = _submittedReview;
                            });
                          },
                          icon: const Icon(Icons.edit_outlined,
                              size: 16, color: _primary),
                          label: Text(
                            'Edit',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _primary),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'How was your visit to $merchant?',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[500]),
                  ),

                  const SizedBox(height: 16),

                  // Star rating row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final filled = i < (_isEditing || !_reviewSubmitted
                          ? _starRating
                          : _submittedRating);
                      return GestureDetector(
                        onTap: (_reviewSubmitted && !_isEditing)
                            ? null
                            : () => setState(() => _starRating = i + 1),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            filled ? Icons.star_rounded : Icons.star_border_rounded,
                            color: Colors.amber,
                            size: 40,
                          ),
                        ),
                      );
                    }),
                  ),

                  if ((_isEditing || !_reviewSubmitted) && _starRating > 0) ...[
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        ['', 'Poor', 'Fair', 'Good', 'Very Good', 'Excellent'][_starRating],
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber[700],
                        ),
                      ),
                    ),
                  ],

                  if (_reviewSubmitted && !_isEditing && _submittedRating > 0) ...[
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        ['', 'Poor', 'Fair', 'Good', 'Very Good', 'Excellent'][_submittedRating],
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber[700],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Review text field — read-only when submitted & not editing
                  if (_reviewSubmitted && !_isEditing) ...[
                    if (_submittedReview.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F4F7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _submittedReview,
                          style: GoogleFonts.inter(
                              fontSize: 14, color: _dark, height: 1.5),
                        ),
                      ),
                  ] else ...[
                    TextField(
                      controller: _reviewController,
                      maxLines: 3,
                      style: GoogleFonts.inter(fontSize: 14, color: _dark),
                      decoration: InputDecoration(
                        hintText: 'Write a short review (optional)…',
                        hintStyle:
                            GoogleFonts.inter(fontSize: 14, color: Colors.grey[400]),
                        filled: true,
                        fillColor: const Color(0xFFF2F4F7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: _primary, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Submit / Update button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving
                            ? null
                            : () => _submitReview(merchant, amount, cashback),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          disabledBackgroundColor: _primary.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5))
                            : Text(
                                _isEditing ? 'Update Review' : 'Submit Review',
                                style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white),
                              ),
                      ),
                    ),

                    if (_isEditing) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => setState(() {
                            _isEditing = false;
                            _starRating = _submittedRating;
                            _reviewController.text = _submittedReview;
                          }),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.inter(
                                fontSize: 14, color: Colors.grey[500]),
                          ),
                        ),
                      ),
                    ],
                  ],

                  if (_reviewSubmitted && !_isEditing) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: Color(0xFF0A7A3E), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Review submitted. Thank you!',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF0A7A3E),
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Done button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context)
                    .popUntil((r) => r.settings.name == '/home' || r.isFirst),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _dark,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(
                  'Back to Home',
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value,
      {Color? color, bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                  fontSize: 13, color: Colors.grey[600]),
            ),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: bold ? 15 : 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: color ?? _dark,
              ),
            ),
          ],
        ),
      );
}

// ── Dotted separator ──────────────────────────────────────────────────────────
class _DottedDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: CustomPaint(
        painter: _DottedLinePainter(),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 24,
              decoration: const BoxDecoration(
                color: Color(0xFFF2F4F7),
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
            ),
            const Spacer(),
            Container(
              width: 16,
              height: 24,
              decoration: const BoxDecoration(
                color: Color(0xFFF2F4F7),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFEEEEEE)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    double x = 16;
    final y = size.height / 2;

    while (x < size.width - 16) {
      canvas.drawLine(Offset(x, y), Offset(x + dashWidth, y), paint);
      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
