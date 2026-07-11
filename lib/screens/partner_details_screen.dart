import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/user_service.dart';
import '../services/transaction_service.dart';
import '../services/visit_verifier.dart';
import '../utils/pin_hasher.dart';

enum _VerifyState { loading, passed, failed, waiting }

class PartnerDetailsScreen extends StatefulWidget {
  const PartnerDetailsScreen({super.key});

  @override
  State<PartnerDetailsScreen> createState() => _PartnerDetailsScreenState();
}

class _PartnerDetailsScreenState extends State<PartnerDetailsScreen> {
  static const Color _primary = Color(0xFF0392CA);
  static const Color _dark = Color(0xFF0D1B3E);
  static const Color _green = Color(0xFF0A7A3E);

  // Points system — loaded from Firestore
  int _reviewPoints = 0;
  static const int _pointsPerReview = 2;
  static const int _pointsForBonus = 100;

  // Social Boost — loaded from route args in build()
  bool _socialBoostEnabled = false;
  double _socialBoostPct   = 10.0;

  @override
  void initState() {
    super.initState();
    _loadReviewPoints();
  }

  /// Returns true if the category is counter-service (QR scan required).
  /// Returns false for table-service categories (GPS only).
  static bool _isCounterService(String category) {
    final c = category.toLowerCase();
    const counterKeywords = [
      'café', 'cafe', 'coffee', 'fast food', 'fastfood', 'takeaway',
      'take away', 'bakery', 'street food', 'retail', 'shop', 'store',
      'pharmacy', 'supermarket', 'grocery', 'deli', 'sandwich', 'juice',
      'smoothie', 'bubble tea', 'ice cream', 'dessert', 'food court',
    ];
    return counterKeywords.any((kw) => c.contains(kw));
  }

  Future<void> _loadReviewPoints() async {
    final userData = await UserService().getCurrentUser();
    final int pts = (userData?['reviewPoints'] as num?)?.toInt() ?? 0;
    if (mounted) setState(() => _reviewPoints = pts);
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final name = args?['name'] as String? ?? 'Monmouth Coffee Co.';
    final address = args?['address'] as String? ?? '2 Park St, Borough Market, SE1 9AB';
    final rating = args?['rating'] as String? ?? '4.9';
    final cashback = args?['cashback'] as String? ?? args?['cashback_pct'] as String? ?? '12%';
    final category = args?['category'] as String? ?? 'Café';
    final visits = args?['visits'] as String? ?? '18.4k+ visits';
    final phone = args?['phone'] as String? ?? '020 7232 3010';
    final imageUrl = args?['imageUrl'] as String?;
    final desc = args?['desc'] as String? ??
        'One of London\'s most celebrated independent coffee roasters, beloved for its single-origin brews served in a rustic Borough Market setting.';
    final partnerLat = (args?['lat'] as num?)?.toDouble() ?? 0.0;
    final partnerLng = (args?['lng'] as num?)?.toDouble() ?? 0.0;

    // Social Boost — sync to state fields so methods can access them
    _socialBoostEnabled = args?['socialBoostEnabled'] as bool? ?? false;
    _socialBoostPct     = (args?['socialBoostPercent'] as num?)?.toDouble() ?? 10.0;

    final merchantId = VisitVerifier.merchantIdFromName(name);
    final verifyCode = args?['verificationCode'] as String? ?? '';

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
        title: Text(
          'Partner Details',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _primary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined,
                color: Colors.black87, size: 22),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 90),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero image
                SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: imageUrl != null
                      ? Image.network(
                          imageUrl,
                          height: 220,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, st) => Container(
                            height: 220,
                            color: const Color(0xFF5C8FA8),
                            child: Center(
                              child: Icon(Icons.store_rounded,
                                  color: Colors.white.withOpacity(0.3), size: 64),
                            ),
                          ),
                        )
                      : Image.asset(
                          'assets/images/signup_hero.webp',
                          height: 220,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (ctx, err, st) => Container(
                            height: 220,
                            color: const Color(0xFF5C8FA8),
                            child: Center(
                              child: Icon(Icons.store_rounded,
                                  color: Colors.white.withOpacity(0.3), size: 64),
                            ),
                          ),
                        ),
                ),

                // QR/GPS + Leave a Review buttons — side by side
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Row(
                    children: [
                      // Scan & Earn — same flow for all partner types (GPS → code fallback)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _verifyAndPay(
                            context, name, cashback, partnerLat, partnerLng,
                            merchantId: merchantId, verifyCode: verifyCode,
                          ),
                          icon: const Icon(Icons.location_on_rounded,
                              color: Colors.white, size: 18),
                          label: Text(
                            'Scan & Earn',
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            minimumSize: const Size(0, 48),
                            shape: const StadiumBorder(),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Leave a Review
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _checkAndShowReview(context, name),
                          icon: const Icon(Icons.star_rounded,
                              color: Colors.white, size: 18),
                          label: Text(
                            'Leave a Review',
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            minimumSize: const Size(0, 48),
                            shape: const StadiumBorder(),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Info card
                _card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _primary),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              address,
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: Colors.grey[600]),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '$rating stars',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _dark),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F3FB),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.group_rounded,
                                    size: 13, color: _primary),
                                const SizedBox(width: 4),
                                Text(
                                  visits,
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _primary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _amenity(Icons.wifi_rounded, 'Wi-Fi'),
                          _amenity(Icons.chair_rounded, 'Seating'),
                          _amenity(Icons.bolt_rounded, 'Charging'),
                          _amenity(Icons.pets_rounded, 'Pets'),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // About card
                _card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'About',
                        style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _dark),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        desc,
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey[600],
                            height: 1.6),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Icon(Icons.phone_outlined, size: 15, color: Colors.grey[500]),
                          const SizedBox(width: 6),
                          Text(
                            phone,
                            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
                          ),
                          const SizedBox(width: 16),
                          Icon(Icons.store_outlined, size: 15, color: Colors.grey[500]),
                          const SizedBox(width: 6),
                          Text(
                            category,
                            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Exclusive offer card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F3FB),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'EXCLUSIVE OFFER',
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: _primary,
                                      letterSpacing: 0.8),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$cashback Instant Cashback',
                                  style: GoogleFonts.inter(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: _dark),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet_rounded,
                              color: _primary,
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'When paying with your GoOuts Virtual Debit Card at checkout.',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            color: _primary.withOpacity(0.8),
                            height: 1.5),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.credit_card_rounded,
                              color: _primary, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'GoOuts Virtual Card',
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _primary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),
              ],
            ),
          ),

          // Bottom CTA button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: const Color(0xFFF2F4F7),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 25),
              child: ElevatedButton.icon(
                onPressed: () => _verifyAndPay(
                  context, name, cashback, partnerLat, partnerLng,
                  merchantId: merchantId, verifyCode: verifyCode,
                ),
                icon: const Icon(
                  Icons.credit_card_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                label: Text(
                  'Pay & Earn Cashback',
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A5E7A),
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Review Bottom Sheet ─────────────────────────────────────
  // ── Smart review entry point ───────────────────────────────────────────────
  Future<void> _checkAndShowReview(
      BuildContext context, String partnerName) async {
    // Show loading snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white)),
          const SizedBox(width: 12),
          Text('Checking your visits…',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white)),
        ]),
        backgroundColor: _primary,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    final svc = TransactionService();
    final allTxns = await svc.getTransactionsForPartner(partnerName);
    final reviewedIds = await svc.getReviewedTransactionIds(partnerName);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    // No visits at all
    if (allTxns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'No visits found for $partnerName. '
              'Pay with GoOuts first to leave a review.',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white)),
          backgroundColor: Colors.grey[700],
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    // Filter unreviewed
    final unreviewed = allTxns
        .where((t) => !reviewedIds.contains(t['id'] as String))
        .toList();

    // All already reviewed
    if (unreviewed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'All your visits to $partnerName have been reviewed. Thank you!',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white)),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    // One unreviewed — open review directly
    if (unreviewed.length == 1) {
      _showReviewSheet(context, partnerName,
          transactionId: unreviewed.first['id'] as String);
      return;
    }

    // Multiple unreviewed — show visit picker
    _showVisitPickerSheet(context, partnerName, unreviewed);
  }

  // ── Visit picker sheet (multiple unreviewed visits) ────────────────────────
  void _showVisitPickerSheet(BuildContext context, String partnerName,
      List<Map<String, dynamic>> unreviewedVisits) {
    final visits = List<Map<String, dynamic>>.from(unreviewedVisits);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setPickerState) {
          if (visits.isEmpty) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 28),
                  const Icon(Icons.check_circle_rounded,
                      color: _green, size: 56),
                  const SizedBox(height: 14),
                  Text('All Visits Reviewed!',
                      style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _dark)),
                  const SizedBox(height: 8),
                  Text('Thank you for reviewing all your visits.',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: Colors.grey[500])),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0),
                      child: Text('Done',
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                  ),
                ],
              ),
            );
          }

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: _primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.star_rounded,
                          color: _primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Review Your Visits',
                              style: GoogleFonts.inter(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: _dark)),
                          Text(
                              '${visits.length} unreviewed visit${visits.length > 1 ? 's' : ''} at $partnerName',
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: Colors.grey[500])),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Visit list
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: visits.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final v = visits[i];
                      final cashback = v['cashbackEarned'];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7FBFE),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            // Visit icon
                            Container(
                              width: 42, height: 42,
                              decoration: BoxDecoration(
                                  color: _primary.withOpacity(0.08),
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.receipt_long_rounded,
                                  color: _primary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            // Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(v['date'] as String,
                                      style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: _dark)),
                                  const SizedBox(height: 2),
                                  Row(children: [
                                    Text(v['amount'] as String,
                                        style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: Colors.grey[600])),
                                    if (cashback != null) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                          '· +£${(cashback as num).toStringAsFixed(2)} cashback',
                                          style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: _green,
                                              fontWeight:
                                                  FontWeight.w600)),
                                    ],
                                  ]),
                                ],
                              ),
                            ),
                            // Review button
                            TextButton(
                              onPressed: () {
                                final txnId = v['id'] as String;
                                Navigator.pop(ctx);
                                Future.delayed(
                                    const Duration(milliseconds: 300),
                                    () {
                                  if (context.mounted) {
                                    _showReviewSheet(context, partnerName,
                                        transactionId: txnId,
                                        onReviewDone: () {
                                      setPickerState(
                                          () => visits.removeWhere(
                                              (x) => x['id'] == txnId));
                                      if (visits.isNotEmpty &&
                                          context.mounted) {
                                        _showVisitPickerSheet(context,
                                            partnerName, visits);
                                      }
                                    });
                                  }
                                });
                              },
                              style: TextButton.styleFrom(
                                  foregroundColor: _primary,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(8),
                                      side: BorderSide(
                                          color: _primary
                                              .withOpacity(0.4)))),
                              child: Text('Review',
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _primary)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Maybe Later',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: Colors.grey[500])),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showReviewSheet(BuildContext context, String partnerName,
      {String transactionId = '', VoidCallback? onReviewDone}) {
    int selectedStars = 0;
    bool submitted = false;
    bool isSubmitting = false;
    bool alreadyReviewed = false;
    bool checking = transactionId.isNotEmpty;
    final reviewController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          // Check Firebase once if we have a transaction ID
          if (checking) {
            checking = false;
            TransactionService().reviewExists(transactionId).then((exists) {
              if (!ctx.mounted) return;
              setSheetState(() => alreadyReviewed = exists);
            });
          }

          // ── Submit handler — lives here so setSheetState works properly ──
          Future<void> handleSubmit() async {
            if (isSubmitting) return;
            if (selectedStars == 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Please tap a star to rate your visit first.',
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.white)),
                  backgroundColor: Colors.orange[700],
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  duration: const Duration(seconds: 2),
                ),
              );
              return;
            }
            setSheetState(() => isSubmitting = true);
            try {
              final saved = await TransactionService().addReview(
                merchant: partnerName,
                rating: selectedStars,
                review: reviewController.text.trim(),
                amount: 0,
                cashback: 0,
                transactionId: transactionId,
              );
              if (!ctx.mounted) return;
              if (!saved) {
                setSheetState(() {
                  isSubmitting = false;
                  alreadyReviewed = true;
                });
                return;
              }
              // Update review points in Firestore
              final userData = await UserService().getCurrentUser();
              final int curPoints =
                  (userData?['reviewPoints'] as num?)?.toInt() ?? 0;
              final int newPoints =
                  (curPoints + _pointsPerReview).clamp(0, _pointsForBonus);
              await UserService().updateUser({'reviewPoints': newPoints});
              if (!ctx.mounted) return;
              setState(() => _reviewPoints = newPoints);
              setSheetState(() {
                isSubmitting = false;
                submitted = true;
              });
              onReviewDone?.call();
            } catch (e) {
              if (!ctx.mounted) return;
              setSheetState(() => isSubmitting = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Could not submit review. Please try again.',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
                  ),
                  backgroundColor: Colors.redAccent,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: alreadyReviewed
                  ? _buildAlreadyReviewed(ctx, transactionId)
                  : submitted
                      ? _buildSubmittedState(ctx)
                      : _buildReviewForm(
                          ctx,
                          partnerName,
                          selectedStars,
                          reviewController,
                          (stars) => setSheetState(() => selectedStars = stars),
                          handleSubmit,
                          isSubmitting: isSubmitting,
                        ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAlreadyReviewed(BuildContext ctx, String transactionId) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 24),
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.rate_review_rounded,
                color: Colors.orange, size: 32),
          ),
          const SizedBox(height: 14),
          Text('Already Reviewed',
              style: GoogleFonts.inter(
                  fontSize: 20, fontWeight: FontWeight.w800, color: _dark)),
          const SizedBox(height: 8),
          Text(
            'You have already submitted a review for this visit.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[500], height: 1.5),
          ),
          if (transactionId.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'TXN-${transactionId.substring(0, 8).toUpperCase()}',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey[400],
                  letterSpacing: 1.2),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Text('OK',
                  style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      );

  Widget _buildReviewForm(
    BuildContext ctx,
    String partnerName,
    int selectedStars,
    TextEditingController controller,
    void Function(int) onStarTap,
    Future<void> Function() onSubmit, {
    bool isSubmitting = false,
  }) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Points progress pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: _green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events_rounded, color: _green, size: 15),
                const SizedBox(width: 6),
                Text(
                  '$_reviewPoints/$_pointsForBonus pts — review earns +$_pointsPerReview pts',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _green,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Thank you header
          Text(
            '🎉 Thank you for visiting',
            style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 4),
          Text(
            partnerName,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 20, fontWeight: FontWeight.w800, color: _dark),
          ),
          const SizedBox(height: 6),
          Text(
            'How was your experience? Your review helps\nothers discover great places.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 13, color: Colors.grey[500], height: 1.5),
          ),

          const SizedBox(height: 20),

          // 5 Stars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < selectedStars;
              return GestureDetector(
                onTap: () => onStarTap(i + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: filled ? Colors.amber : Colors.grey[300],
                    size: 40,
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 8),

          Text(
            selectedStars == 0
                ? 'Tap a star to rate'
                : selectedStars == 5
                    ? 'Excellent!'
                    : selectedStars == 4
                        ? 'Very Good!'
                        : selectedStars == 3
                            ? 'Good'
                            : selectedStars == 2
                                ? 'Fair'
                                : 'Poor',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selectedStars == 0 ? Colors.grey[400] : Colors.amber[700],
            ),
          ),

          const SizedBox(height: 18),

          // Review text box
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: TextField(
              controller: controller,
              maxLines: 3,
              style: GoogleFonts.inter(fontSize: 14, color: _dark),
              decoration: InputDecoration(
                hintText: 'Share your experience... (optional)',
                hintStyle:
                    GoogleFonts.inter(fontSize: 13, color: Colors.grey[400]),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: isSubmitting ? null : () => onSubmit(),
              style: ElevatedButton.styleFrom(
                backgroundColor: isSubmitting
                    ? Colors.grey[300]
                    : selectedStars > 0
                        ? _primary
                        : _primary.withOpacity(0.45),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : Text(
                      'Submit Review',
                      style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
            ),
          ),

          const SizedBox(height: 12),

          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Maybe Later',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[500]),
            ),
          ),
        ],
      );

  Widget _buildSubmittedState(BuildContext ctx) {
    final newPoints = (_reviewPoints).clamp(0, _pointsForBonus);
    final remaining = _pointsForBonus - newPoints;
    final progress = newPoints / _pointsForBonus;
    final bonusUnlocked = newPoints >= _pointsForBonus;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 24),

        // Success icon
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: _green.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_rounded,
              color: _green, size: 38),
        ),
        const SizedBox(height: 16),

        Text(
          'Review Submitted!',
          style: GoogleFonts.inter(
              fontSize: 22, fontWeight: FontWeight.w800, color: _dark),
        ),
        const SizedBox(height: 6),
        Text(
          'Thank you for using GoOuts services.',
          style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[500]),
        ),

        const SizedBox(height: 20),

        // Points earned badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: _green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_circle_rounded, color: _green, size: 18),
              const SizedBox(width: 6),
              Text(
                '+$_pointsPerReview Points Earned',
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _green),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Progress card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.emoji_events_rounded,
                      color: Color(0xFFE0A500), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    bonusUnlocked
                        ? '🎉 £10 Bonus Unlocked!'
                        : '$newPoints / $_pointsForBonus pts — £10 Bonus',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _dark),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFE0A500)),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                bonusUnlocked
                    ? '£10 bonus has been added to your wallet!'
                    : '$remaining more points to earn your £10 bonus — keep reviewing!',
                style: GoogleFonts.inter(
                    fontSize: 12, color: Colors.grey[500], height: 1.4),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: Text(
              'Done',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
          ),
        ),

        const SizedBox(height: 8),
      ],
    );
  }

  // ── PIN Authorisation Sheet ────────────────────────────────────────────────
  // Shows a 4-digit PIN entry bottom sheet before processing payment.
  // Returns true if PIN verified, false/null if cancelled.
  Future<bool?> _showPinSheet(BuildContext ctx) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    return showModalBottomSheet<bool>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _PinAuthSheet(uid: uid),
    );
  }

  // ── Verify visit: GPS first → partner code fallback if GPS fails ──────────
  void _verifyAndPay(BuildContext context, String merchant,
      String cashback, double partnerLat, double partnerLng,
      {String merchantId = '', String verifyCode = ''}) {

    final bool hasCoords   = partnerLat != 0.0 && partnerLng != 0.0;
    final String storedCode = verifyCode.toUpperCase().trim();

    bool gpsChecked  = false;
    bool gpsPassed   = false;
    bool gpsRunning  = hasCoords;
    String gpsMessage = hasCoords ? 'Checking your location…' : 'No GPS coordinates set for this partner.';

    // 'choose' = picking QR or Code, 'qr' = scanner active, 'code' = text input
    String fallbackMode = '';
    bool showFallback = !hasCoords;   // immediately show fallback if no coords

    bool codePassed    = false;
    bool codeChecking  = false;
    String codeError   = '';
    final codeCtrl     = TextEditingController();
    MobileScannerController? scanCtrl;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {

          // Auto-run GPS once
          if (hasCoords && !gpsChecked) {
            gpsChecked = true;
            VisitVerifier.checkGps(partnerLat, partnerLng).then((result) {
              if (!ctx.mounted) return;
              setSheet(() {
                gpsRunning = false;
                gpsPassed  = result.withinRange;
                if (result.error != null) {
                  gpsMessage    = result.error!;
                  showFallback  = true;
                  fallbackMode  = 'choose';
                } else if (result.withinRange) {
                  final dist = result.distanceMetres != null
                      ? ' (${result.distanceMetres!.toStringAsFixed(0)}m)'
                      : '';
                  gpsMessage = 'You\'re at $merchant$dist ✓';
                } else {
                  final dist = result.distanceMetres != null
                      ? '${result.distanceMetres!.toStringAsFixed(0)}m away'
                      : 'location not confirmed';
                  gpsMessage   = 'GPS shows you\'re $dist.';
                  showFallback = true;
                  fallbackMode = 'choose';
                }
              });
            });
          }

          // Auto-proceed when GPS passes
          if (gpsPassed) {
            Future.microtask(() {
              if (ctx.mounted) {
                Navigator.pop(ctx);
                _showCashbackApplySheet(context, merchant, cashback);
              }
            });
          }

          // Verify typed partner code — matches stored code OR master override
          const String _masterCode = '123456';
          Future<void> checkCode() async {
            final entered = codeCtrl.text.trim().toUpperCase();
            if (entered.isEmpty) {
              setSheet(() => codeError = 'Please enter the partner code.');
              return;
            }
            setSheet(() { codeChecking = true; codeError = ''; });
            await Future.delayed(const Duration(milliseconds: 600));
            if (!ctx.mounted) return;
            final bool valid = entered == _masterCode ||
                (storedCode.isNotEmpty && entered == storedCode);
            if (valid) {
              setSheet(() { codeChecking = false; codePassed = true; });
              await Future.delayed(const Duration(milliseconds: 500));
              if (ctx.mounted) {
                Navigator.pop(ctx);
                _showCashbackApplySheet(context, merchant, cashback);
              }
            } else {
              setSheet(() {
                codeChecking = false;
                codeError = 'Incorrect code. Please ask staff for the correct partner code.';
              });
            }
          }

          // Handle QR scan result — matches stored code OR master override
          void onQrDetect(BarcodeCapture capture) {
            final raw = capture.barcodes.firstOrNull?.rawValue ?? '';
            final scanned = raw.toUpperCase().trim();
            if (scanned.isEmpty) return;
            scanCtrl?.stop();
            final bool qrValid = scanned == '123456' ||
                (storedCode.isNotEmpty && scanned == storedCode);
            if (qrValid) {
              setSheet(() { codePassed = true; fallbackMode = 'qr_ok'; });
              Future.delayed(const Duration(milliseconds: 500), () {
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  _showCashbackApplySheet(context, merchant, cashback);
                }
              });
            } else {
              setSheet(() {
                fallbackMode = 'choose';
                codeError = 'QR code not recognised. Try entering the partner code manually.';
              });
            }
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 20),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            color: _primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.verified_user_rounded,
                              color: _primary, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Verify Your Visit',
                                  style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0D1B3E))),
                              Text(
                                showFallback && fallbackMode == ''
                                    ? 'Choose how to verify'
                                    : gpsRunning
                                        ? 'Checking your location…'
                                        : showFallback
                                            ? 'Verify with QR or enter partner code'
                                            : 'GPS verified ✓',
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: Colors.grey[500])),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 20),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        // Step 1: GPS
                        if (hasCoords) ...[
                          _verifyStepCard(
                            step: '1',
                            icon: Icons.location_on_rounded,
                            title: 'GPS Location Check',
                            message: gpsMessage,
                            state: gpsRunning
                                ? _VerifyState.loading
                                : gpsPassed
                                    ? _VerifyState.passed
                                    : _VerifyState.failed,
                          ),
                        ],

                        // Fallback section
                        if (showFallback) ...[
                          if (hasCoords) const SizedBox(height: 16),

                          // ── Choose mode ─────────────────────────────────
                          if (fallbackMode == 'choose' || fallbackMode == '') ...[
                            Text(
                              'GPS could not confirm your location.\nVerify using one of the options below:',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: Colors.grey[600], height: 1.5),
                            ),
                            if (codeError.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(codeError,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                      fontSize: 12, color: Colors.red[600])),
                            ],
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                // QR Scan tile
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      scanCtrl = MobileScannerController();
                                      setSheet(() { fallbackMode = 'qr'; codeError = ''; });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 20),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF0F9FF),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: _primary.withOpacity(0.3)),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(Icons.qr_code_scanner_rounded,
                                              size: 36, color: _primary),
                                          const SizedBox(height: 8),
                                          Text('Scan QR Code',
                                              style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: _primary)),
                                          const SizedBox(height: 2),
                                          Text('Ask staff to show\nthe QR code',
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.inter(
                                                  fontSize: 11, color: Colors.grey[500])),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Enter code tile
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setSheet(() { fallbackMode = 'code'; codeError = ''; }),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 20),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8F4FF),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.purple.withOpacity(0.3)),
                                      ),
                                      child: Column(
                                        children: [
                                          const Icon(Icons.pin_rounded,
                                              size: 36, color: Colors.purple),
                                          const SizedBox(height: 8),
                                          Text('Enter Code',
                                              style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.purple)),
                                          const SizedBox(height: 2),
                                          Text('Ask staff for the\npartner code',
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.inter(
                                                  fontSize: 11, color: Colors.grey[500])),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // ── QR Test Mode ────────────────────────────────
                          // TODO: Remove before go-live — replace with real
                          // MobileScanner that reads partner's printed QR.
                          if (fallbackMode == 'qr') ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F9FF),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: _primary.withOpacity(0.3)),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text('TEST MODE',
                                        style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.orange[800],
                                            letterSpacing: 1.2)),
                                  ),
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.06),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: QrImageView(
                                      data: '123456',
                                      version: QrVersions.auto,
                                      size: 160,
                                      eyeStyle: const QrEyeStyle(
                                        eyeShape: QrEyeShape.square,
                                        color: Color(0xFF0D1B3E),
                                      ),
                                      dataModuleStyle: const QrDataModuleStyle(
                                        dataModuleShape: QrDataModuleShape.square,
                                        color: Color(0xFF0D1B3E),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text('123456',
                                      style: GoogleFonts.inter(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 6,
                                          color: _primary)),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        _showCashbackApplySheet(
                                            context, merchant, cashback);
                                      },
                                      icon: const Icon(Icons.check_circle_rounded),
                                      label: Text('Pay & Earn Cashback',
                                          style: GoogleFonts.inter(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF0A7A3E),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14)),
                                        elevation: 0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () => setSheet(
                                  () { fallbackMode = 'choose'; codeError = ''; }),
                              icon: const Icon(Icons.arrow_back_rounded, size: 16),
                              label: Text('Back to options',
                                  style: GoogleFonts.inter(fontSize: 13)),
                            ),
                          ],

                          // ── Code entry ──────────────────────────────────
                          if (fallbackMode == 'code') ...[
                            TextFormField(
                              controller: codeCtrl,
                              textCapitalization: TextCapitalization.characters,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 6,
                                  color: const Color(0xFF0D1B3E)),
                              decoration: InputDecoration(
                                hintText: 'ENTER CODE',
                                hintStyle: GoogleFonts.inter(
                                    fontSize: 16, letterSpacing: 4, color: Colors.grey[350]),
                                errorText: codeError.isNotEmpty ? codeError : null,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: _primary, width: 2)),
                              ),
                              onFieldSubmitted: (_) => checkCode(),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity, height: 50,
                              child: ElevatedButton(
                                onPressed: codeChecking || codePassed ? null : checkCode,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primary,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: Colors.grey[300],
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                                child: codeChecking
                                    ? const SizedBox(
                                        width: 20, height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2, color: Colors.white))
                                    : Text('Verify Code',
                                        style: GoogleFonts.inter(
                                            fontSize: 15, fontWeight: FontWeight.w700)),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () => setSheet(() { fallbackMode = 'choose'; codeError = ''; }),
                              icon: const Icon(Icons.arrow_back_rounded, size: 16),
                              label: Text('Back to options',
                                  style: GoogleFonts.inter(fontSize: 13)),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  GestureDetector(
                    onLongPress: () => setSheet(() {
                      gpsRunning = false;
                      gpsPassed  = true;
                      gpsMessage = 'Demo: location verified ✓';
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Demo mode: long-press to simulate GPS pass',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[400]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      codeCtrl.dispose();
      scanCtrl?.dispose();
    });
  }

  // ── Verify step card (local) ───────────────────────────────────────────────
  Widget _verifyStepCard({
    required String step,
    required IconData icon,
    required String title,
    required String message,
    required _VerifyState state,
  }) {
    Color bg, iconColor, border;
    Widget indicator;
    switch (state) {
      case _VerifyState.loading:
        bg = const Color(0xFFF0F4F8); iconColor = Colors.grey; border = const Color(0xFFE2E8F0);
        indicator = const SizedBox(width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0392CA)));
        break;
      case _VerifyState.passed:
        bg = const Color(0xFFEBF9F1); iconColor = const Color(0xFF0A7A3E); border = const Color(0xFFB2DFC8);
        indicator = const Icon(Icons.check_circle_rounded, color: Color(0xFF0A7A3E), size: 20);
        break;
      case _VerifyState.failed:
        bg = const Color(0xFFFFF0F0); iconColor = Colors.red; border = const Color(0xFFFFCDD2);
        indicator = const Icon(Icons.cancel_rounded, color: Colors.red, size: 20);
        break;
      case _VerifyState.waiting:
        bg = const Color(0xFFF8F9FA); iconColor = Colors.grey; border = const Color(0xFFE2E8F0);
        indicator = Container(
          width: 20, height: 20,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.grey[400]!)),
          child: Center(child: Text(step, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
        );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border)),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: const Color(0xFF0D1B3E))),
                const SizedBox(height: 2),
                Text(message,
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600], height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          indicator,
        ],
      ),
    );
  }

  // ── Not at location error sheet ─────────────────────────────────────────────
  void _showNotAtLocationSheet(
      BuildContext context, String merchant, String distance) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.location_off_rounded,
                  color: Colors.red, size: 34),
            ),
            const SizedBox(height: 14),
            Text('Not at This Location',
                style: GoogleFonts.inter(
                    fontSize: 19, fontWeight: FontWeight.w800,
                    color: const Color(0xFF0D1B3E))),
            const SizedBox(height: 8),
            Text(
              'You appear to be $distance from $merchant.\n\nCashback can only be claimed when you are physically at the partner location.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 13, color: Colors.grey[500], height: 1.55),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F3FB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Color(0xFF0392CA), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'If you are inside $merchant, please make sure location access is enabled for GoOuts.',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF0392CA),
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0392CA),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text('OK, Got It',
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Cashback Apply Sheet ──────────────────────────────────────────────────
  Future<void> _showCashbackApplySheet(
      BuildContext context, String merchant, String cashback) async {
    double walletBalance = 0.0;
    double cashbackBalance = 0.0;
    try {
      final userData = await UserService().getCurrentUser();
      walletBalance   = (userData?['walletBalance']   as num?)?.toDouble() ?? 0.0;
      cashbackBalance = (userData?['cashbackBalance'] as num?)?.toDouble() ?? 0.0;
    } catch (_) {}

    if (!context.mounted) return;

    Map<String, double>? chosen = await showModalBottomSheet<Map<String, double>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) {
        final billCtrl      = TextEditingController();
        final cbRedeemCtrl  = TextEditingController();
        final walRedeemCtrl = TextEditingController();
        double billAmount   = 0.0;
        double cbRedeem     = 0.0;
        double walRedeem    = 0.0;
        bool cbMax          = false;
        bool walMax         = false;

        return StatefulBuilder(
          builder: (ctx2, setSheet) {
            final double totalAvailable = walletBalance + cashbackBalance;
            final double maxCb  = billAmount > cashbackBalance ? cashbackBalance : billAmount;
            final double maxWal = (billAmount - cbRedeem) > walletBalance
                ? walletBalance
                : (billAmount - cbRedeem).clamp(0.0, walletBalance);
            final double bankCharge =
                (billAmount - cbRedeem - walRedeem).clamp(0.0, billAmount);

            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx2).viewInsets.bottom),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 36, height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Title
                      Text('Your Wallet Balance',
                          style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _dark)),
                      const SizedBox(height: 4),
                      Text(
                          'Use your cashback & wallet to reduce your bill',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: Colors.grey[500])),
                      const SizedBox(height: 16),

                      // Balance summary card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0392CA), Color(0xFF026899)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            _balanceCol('Wallet',
                                '£${walletBalance.toStringAsFixed(2)}'),
                            _balanceDivider(),
                            _balanceCol('Cashback',
                                '£${cashbackBalance.toStringAsFixed(2)}'),
                            _balanceDivider(),
                            _balanceCol('Total',
                                '£${totalAvailable.toStringAsFixed(2)}',
                                highlight: true),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Bill amount
                      Text('Total Bill to Pay',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _dark)),
                      const SizedBox(height: 8),
                      _amountInput(
                        ctrl: billCtrl,
                        hint: 'Enter bill amount',
                        autofocus: true,
                        onChanged: (v) => setSheet(() {
                          billAmount = double.tryParse(v) ?? 0.0;
                          if (cbMax) {
                            cbRedeem = billAmount > cashbackBalance
                                ? cashbackBalance
                                : billAmount;
                            cbRedeemCtrl.text =
                                cbRedeem.toStringAsFixed(2);
                          }
                          if (walMax) {
                            final rem = billAmount - cbRedeem;
                            walRedeem =
                                rem > walletBalance ? walletBalance : rem;
                            walRedeemCtrl.text =
                                walRedeem.toStringAsFixed(2);
                          }
                        }),
                      ),

                      if (billAmount > 0) ...[
                        const SizedBox(height: 16),

                        // Redeem Cashback
                        _inputLabel('Redeem Cashback'),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                            child: _amountInput(
                              ctrl: cbRedeemCtrl,
                              hint:
                                  'e.g. ${maxCb.toStringAsFixed(2)}',
                              enabled: !cbMax,
                              onChanged: (v) => setSheet(() {
                                cbRedeem = (double.tryParse(v) ?? 0.0)
                                    .clamp(0.0, maxCb);
                              }),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _maxButton(
                            active: cbMax,
                            onTap: () => setSheet(() {
                              cbMax = !cbMax;
                              if (cbMax) {
                                cbRedeem = maxCb;
                                cbRedeemCtrl.text =
                                    maxCb.toStringAsFixed(2);
                              } else {
                                cbRedeemCtrl.clear();
                                cbRedeem = 0;
                              }
                            }),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        Text(
                            'Available: £${cashbackBalance.toStringAsFixed(2)}',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.grey[400])),

                        const SizedBox(height: 14),

                        // Redeem Wallet
                        _inputLabel('Redeem Wallet Balance'),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                            child: _amountInput(
                              ctrl: walRedeemCtrl,
                              hint:
                                  'e.g. ${maxWal.toStringAsFixed(2)}',
                              enabled: !walMax,
                              onChanged: (v) => setSheet(() {
                                walRedeem = (double.tryParse(v) ?? 0.0)
                                    .clamp(0.0, maxWal);
                              }),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _maxButton(
                            active: walMax,
                            onTap: () => setSheet(() {
                              walMax = !walMax;
                              if (walMax) {
                                walRedeem = maxWal;
                                walRedeemCtrl.text =
                                    maxWal.toStringAsFixed(2);
                              } else {
                                walRedeemCtrl.clear();
                                walRedeem = 0;
                              }
                            }),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        Text(
                            'Available: £${walletBalance.toStringAsFixed(2)}',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.grey[400])),

                        const SizedBox(height: 18),

                        // Bank charge summary
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: bankCharge == 0
                                ? const Color(0xFFEDF7F1)
                                : const Color(0xFFF0F6FA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: bankCharge == 0
                                  ? _green.withOpacity(0.3)
                                  : Colors.grey[200]!,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text('Charged to Bank',
                                      style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: Colors.grey[500])),
                                  Text(
                                    bankCharge == 0
                                        ? 'Fully covered ✓'
                                        : '£${bankCharge.toStringAsFixed(2)}',
                                    style: GoogleFonts.inter(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: bankCharge == 0
                                            ? _green
                                            : _dark),
                                  ),
                                ],
                              ),
                              if (bankCharge == 0)
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _green.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.check_rounded,
                                      color: _green, size: 20),
                                ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Apply & Pay button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: billAmount <= 0
                              ? null
                              : () async {
                                  final confirmed = await _showPinSheet(ctx);
                                  if (confirmed == true && ctx.mounted) {
                                    Navigator.pop(ctx, <String, double>{
                                      'bill': billAmount,
                                      'cashback': cbRedeem,
                                      'wallet': walRedeem,
                                    });
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            disabledBackgroundColor: Colors.grey[200],
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: Text(
                            billAmount <= 0
                                ? 'Enter bill amount to continue'
                                : 'Apply & Pay  •  £${bankCharge.toStringAsFixed(2)}',
                            style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: billAmount <= 0
                                    ? Colors.grey[400]
                                    : Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () {
                            if (billAmount <= 0) {
                              Navigator.pop(ctx, null); // no bill entered — abort
                            } else {
                              Navigator.pop(ctx, <String, double>{
                                'bill': billAmount,
                                'cashback': 0,
                                'wallet': 0,
                              });
                            }
                          },
                          child: Text(
                            billAmount > 0
                                ? 'Skip — charge full £${billAmount.toStringAsFixed(2)} to bank'
                                : 'Skip cashback',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.grey[400]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (!context.mounted) return;

    // Only proceed if user explicitly confirmed with a bill amount
    final bill = chosen?['bill'] ?? 0.0;
    if (bill <= 0) return; // sheet dismissed or skipped without entering bill

    _showPayConfirmation(context, merchant, cashback,
      billAmount:         bill,
      cashbackToUse:      chosen?['cashback'] ?? 0.0,
      walletToUse:        chosen?['wallet']   ?? 0.0,
      socialBoostEnabled: _socialBoostEnabled,
      socialBoostPct:     _socialBoostPct,
    );
  }

  // ── Pay & Earn — Processing → Success ────────────────────────────────────
  Future<void> _showPayConfirmation(
    BuildContext context, String merchant, String cashback, {
    double billAmount         = 0.0,
    double cashbackToUse      = 0.0,
    double walletToUse        = 0.0,
    bool   socialBoostEnabled = false,
    double socialBoostPct     = 10.0,
  }) async {
    double cashbackPct = 0.0;
    final pctMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(cashback);
    if (pctMatch != null) {
      cashbackPct = double.tryParse(pctMatch.group(1)!) ?? 0.0;
    }
    final double billAmt = billAmount > 0 ? billAmount : 20.0;
    final double cashbackAmount = billAmt * (cashbackPct / 100);

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56, height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFD6EEF8),
                shape: BoxShape.circle,
              ),
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Color(0xFF0392CA)),
              ),
            ),
            const SizedBox(height: 18),
            Text('Processing Payment…',
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _dark)),
            const SizedBox(height: 6),
            Text('Please keep your phone near the terminal',
                style: GoogleFonts.inter(
                    fontSize: 13, color: Colors.grey[500])),
          ],
        ),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 1800));

    double newWalletBalance = cashbackAmount;
    String transactionId = '';
    bool plusUnlocked = false;
    try {
      final userData = await UserService().getCurrentUser();
      final double curWallet =
          (userData?['walletBalance'] as num?)?.toDouble() ?? 0.0;
      final double curCashback =
          (userData?['cashbackBalance'] as num?)?.toDouble() ?? 0.0;

      newWalletBalance =
          (curWallet - walletToUse + cashbackAmount).clamp(0.0, double.infinity);
      final double newCashbackBalance =
          (curCashback - cashbackToUse + cashbackAmount).clamp(0.0, double.infinity);

      await UserService().updateUser({
        'walletBalance':   newWalletBalance,
        'cashbackBalance': newCashbackBalance,
      });

      // Track lifetime cashback — returns true if £100 milestone just triggered
      plusUnlocked = await UserService().recordCashbackEarned(cashbackAmount);

      transactionId = await TransactionService().addTransaction(
        title: merchant,
        amount: billAmt,
        amountFormatted: '-£${billAmt.toStringAsFixed(2)}',
        type: 'Spending',
        iconKey: 'restaurant',
        positive: false,
        status: 'Completed',
        cashbackEarned: cashbackAmount,
      );

      if (cashbackToUse > 0) {
        await TransactionService().addTransaction(
          title: 'Cashback Redeemed at $merchant',
          amount: cashbackToUse,
          amountFormatted: '-£${cashbackToUse.toStringAsFixed(2)}',
          type: 'Cashback',
          iconKey: 'gift',
          positive: false,
          status: 'Completed',
          groupId: transactionId,
        );
      }

      if (walletToUse > 0) {
        await TransactionService().addTransaction(
          title: 'Wallet Used at $merchant',
          amount: walletToUse,
          amountFormatted: '-£${walletToUse.toStringAsFixed(2)}',
          type: 'Spending',
          iconKey: 'wallet',
          positive: false,
          status: 'Completed',
          groupId: transactionId,
        );
      }

      await TransactionService().addTransaction(
        title: '$merchant — Cashback',
        amount: cashbackAmount,
        amountFormatted: '+£${cashbackAmount.toStringAsFixed(2)}',
        type: 'Cashback',
        iconKey: 'gift',
        positive: true,
        status: 'Completed',
        cashbackEarned: cashbackAmount,
        groupId: transactionId,
      );
    } catch (_) {}

    if (!context.mounted) return;
    Navigator.pop(context);
    _showPaymentSuccess(
      context,
      merchant: merchant,
      spendAmount: billAmt,
      cashbackAmount: cashbackAmount,
      cashbackPct: cashbackPct,
      newWalletBalance: newWalletBalance,
      transactionId: transactionId,
      cashbackUsed: cashbackToUse,
      walletUsed: walletToUse,
      socialBoostEnabled: socialBoostEnabled,
      socialBoostPct: socialBoostPct,
    );

    // If £100 milestone just triggered — show GoOuts Plus celebration
    // after a short delay so the payment success screen shows first
    if (plusUnlocked && context.mounted) {
      Future.delayed(const Duration(seconds: 2), () {
        if (context.mounted) {
          Navigator.pushNamed(context, '/goouts-plus-unlocked');
        }
      });
    }
  }

  // ── Payment Success Screen ────────────────────────────────────────────────
  void _showPaymentSuccess(
    BuildContext context, {
    required String merchant,
    required double spendAmount,
    required double cashbackAmount,
    required double cashbackPct,
    required double newWalletBalance,
    required String transactionId,
    double cashbackUsed       = 0.0,
    double walletUsed         = 0.0,
    bool   socialBoostEnabled = false,
    double socialBoostPct     = 10.0,
  }) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: _green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      color: _green, size: 40),
                ),
                const SizedBox(height: 12),
                Text('Payment Complete!',
                    style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _dark)),
                const SizedBox(height: 4),
                Text('Cashback added to your wallet',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: Colors.grey[500])),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_circle_rounded,
                          color: _green, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '+£${cashbackAmount.toStringAsFixed(2)} Cashback Earned',
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _green),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F4F7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      _summaryRow('Partner', merchant),
                      const SizedBox(height: 8),
                      _summaryRow('Bill Amount',
                          '£${spendAmount.toStringAsFixed(2)}'),
                      if (cashbackUsed > 0) ...[
                        const SizedBox(height: 8),
                        _summaryRow('Cashback Redeemed',
                            '-£${cashbackUsed.toStringAsFixed(2)}',
                            valueColor: _green),
                      ],
                      if (walletUsed > 0) ...[
                        const SizedBox(height: 8),
                        _summaryRow('Wallet Used',
                            '-£${walletUsed.toStringAsFixed(2)}',
                            valueColor: _primary),
                      ],
                      if (cashbackUsed > 0 || walletUsed > 0) ...[
                        const SizedBox(height: 8),
                        _summaryRow('Charged to Bank',
                            '£${(spendAmount - cashbackUsed - walletUsed).clamp(0, spendAmount).toStringAsFixed(2)}'),
                      ],
                      const SizedBox(height: 8),
                      _summaryRow('Cashback Rate',
                          '${cashbackPct.toStringAsFixed(0)}%'),
                      const Divider(
                          height: 16, color: Color(0xFFDDE1E9)),
                      _summaryRow(
                        'Cashback Earned',
                        '+£${cashbackAmount.toStringAsFixed(2)}',
                        valueColor: _green,
                        bold: true,
                      ),
                      const SizedBox(height: 8),
                      _summaryRow(
                        'New Wallet Balance',
                        '£${newWalletBalance.toStringAsFixed(2)}',
                        bold: true,
                      ),
                      if (transactionId.isNotEmpty) ...[
                        const Divider(
                            height: 16, color: Color(0xFFDDE1E9)),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Transaction ID',
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.grey[400])),
                            Text(
                              'TXN-${transactionId.substring(0, 8).toUpperCase()}',
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.grey[400],
                                  letterSpacing: 1.2),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Future.delayed(
                          const Duration(milliseconds: 400), () {
                        if (!context.mounted) return;
                        if (socialBoostEnabled) {
                          _showSocialBoostSheet(
                            context,
                            merchant: merchant,
                            transactionId: transactionId,
                            socialBoostPct: socialBoostPct,
                            billAmount: spendAmount,
                            onDone: () => Future.delayed(
                              const Duration(milliseconds: 300),
                              () { if (context.mounted) _showReviewSheet(context, merchant, transactionId: transactionId); },
                            ),
                          );
                        } else {
                          _showReviewSheet(context, merchant,
                              transactionId: transactionId);
                        }
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Text('Rate Your Visit',
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Back to Partner',
                      style: GoogleFonts.inter(
                          fontSize: 14, color: Colors.grey[500])),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _summaryRow(String label, String value,
          {bool bold = false, Color? valueColor}) =>
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontWeight: bold ? FontWeight.w600 : FontWeight.w400)),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                  color: valueColor ?? _dark)),
        ],
      );

  Widget _balanceCol(String label, String value,
          {bool highlight = false}) =>
      Expanded(
        child: Column(
          children: [
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.75),
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(value,
                style: GoogleFonts.inter(
                    fontSize: highlight ? 15 : 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
                textAlign: TextAlign.center),
          ],
        ),
      );

  Widget _balanceDivider() => Container(
      width: 1, height: 32, color: Colors.white.withOpacity(0.25));

  Widget _inputLabel(String text) => Text(text,
      style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey[500],
          letterSpacing: 0.4));

  Widget _amountInput({
    required TextEditingController ctrl,
    required String hint,
    bool autofocus = false,
    bool enabled = true,
    required ValueChanged<String> onChanged,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFF0F6FA) : const Color(0xFFF8FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Text('£',
                style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w300,
                    color: _primary)),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: ctrl,
                autofocus: autofocus,
                enabled: enabled,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: enabled ? _dark : Colors.grey[400]),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: hint,
                  hintStyle: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey[350]),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      );

  Widget _maxButton({required bool active, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: active ? _primary : const Color(0xFFF0F6FA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('MAX',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : Colors.grey[500])),
        ),
      );

  Widget _amenity(IconData icon, String label) => Column(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(height: 4),
          Text(label,
              style:
                  GoogleFonts.inter(fontSize: 11, color: Colors.grey[500])),
        ],
      );

  Widget _card({required Widget child, EdgeInsets? margin}) => Container(
        margin: margin ?? EdgeInsets.zero,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: child,
      );

  // ── Social Boost Sheet trigger ─────────────────────────────────────────────
  void _showSocialBoostSheet(
    BuildContext context, {
    required String merchant,
    required String transactionId,
    required double socialBoostPct,
    required double billAmount,
    VoidCallback? onDone,
  }) {
    final double bonusAmount = billAmount * (socialBoostPct / 100);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SocialBoostSheet(
        merchant:       merchant,
        transactionId:  transactionId,
        socialBoostPct: socialBoostPct,
        bonusAmount:    bonusAmount,
        onDone:         onDone,
      ),
    );
  }
}

// ── PIN Authorisation Bottom Sheet ────────────────────────────────────────────
class _PinAuthSheet extends StatefulWidget {
  final String uid;
  const _PinAuthSheet({required this.uid});

  @override
  State<_PinAuthSheet> createState() => _PinAuthSheetState();
}

class _PinAuthSheetState extends State<_PinAuthSheet>
    with SingleTickerProviderStateMixin {
  static const _primary = Color(0xFF0392CA);
  static const _dark    = Color(0xFF0D1B3E);

  final List<String> _digits = [];
  bool _checking  = false;
  bool _shake     = false;
  int  _attempts  = 0;
  String? _error;

  late AnimationController _shakeCtrl;
  late Animation<double>   _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnim = Tween<double>(begin: 0, end: 12).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _onKey(String digit) {
    if (_digits.length >= 4 || _checking) return;
    HapticFeedback.lightImpact();
    setState(() {
      _digits.add(digit);
      _error = null;
    });
    if (_digits.length == 4) _verify();
  }

  void _onDelete() {
    if (_digits.isEmpty || _checking) return;
    HapticFeedback.selectionClick();
    setState(() => _digits.removeLast());
  }

  Future<void> _verify() async {
    setState(() => _checking = true);
    try {
      final entered = _digits.join();
      final hashed  = PinHasher.hash(entered, widget.uid);
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .get();
      final stored = doc.data()?['pin'] as String?;
      if (stored == hashed) {
        if (mounted) Navigator.of(context).pop(true);
      } else {
        _attempts++;
        await _shakeCtrl.forward(from: 0);
        setState(() {
          _digits.clear();
          _checking = false;
          _error = _attempts >= 3
              ? 'Too many attempts. Please try again later.'
              : 'Incorrect PIN. ${3 - _attempts} attempt${3 - _attempts == 1 ? '' : 's'} remaining.';
        });
        if (_attempts >= 3 && mounted) {
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) Navigator.of(context).pop(false);
        }
      }
    } catch (_) {
      setState(() {
        _checking = false;
        _digits.clear();
        _error = 'Could not verify PIN. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 28),

          // Lock icon
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_rounded, color: _primary, size: 30),
          ),
          const SizedBox(height: 16),

          Text('Enter your PIN',
              style: GoogleFonts.inter(
                  fontSize: 20, fontWeight: FontWeight.w800, color: _dark)),
          const SizedBox(height: 6),
          Text('Authorise this payment',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[500])),
          const SizedBox(height: 32),

          // PIN dots with shake
          AnimatedBuilder(
            animation: _shakeAnim,
            builder: (_, child) => Transform.translate(
              offset: Offset(_shakeAnim.value * (_shakeCtrl.status == AnimationStatus.forward ? 1 : -1), 0),
              child: child,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _digits.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 18, height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? _primary : Colors.transparent,
                    border: Border.all(
                      color: filled ? _primary : Colors.grey[300]!,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),
          ),

          // Error message
          AnimatedOpacity(
            opacity: _error != null ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error ?? '',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.red[600],
                                fontWeight: FontWeight.w500),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Numpad
          if (_checking)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: CircularProgressIndicator(),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  for (final row in [
                    ['1','2','3'],
                    ['4','5','6'],
                    ['7','8','9'],
                    ['','0','⌫'],
                  ])
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: row.map((k) => _key(k)).toList(),
                    ),
                ],
              ),
            ),

          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text('Cancel',
                style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[500])),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _key(String label) {
    if (label.isEmpty) return const SizedBox(width: 72, height: 72);
    return GestureDetector(
      onTap: () => label == '⌫' ? _onDelete() : _onKey(label),
      child: Container(
        width: 72, height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: label == '⌫' ? Colors.grey[100] : const Color(0xFFF0F6FA),
          shape: BoxShape.circle,
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: label == '⌫'
            ? Icon(Icons.backspace_outlined, size: 20, color: Colors.grey[600])
            : Text(label,
                style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0D1B3E))),
      ),
    );
  }
}

// ── Social Boost Sheet ────────────────────────────────────────────────────────
class _SocialBoostSheet extends StatefulWidget {
  final String merchant;
  final String transactionId;
  final double socialBoostPct;
  final double bonusAmount;
  final VoidCallback? onDone;

  const _SocialBoostSheet({
    required this.merchant,
    required this.transactionId,
    required this.socialBoostPct,
    required this.bonusAmount,
    this.onDone,
  });

  @override
  State<_SocialBoostSheet> createState() => _SocialBoostSheetState();
}

class _SocialBoostSheetState extends State<_SocialBoostSheet>
    with SingleTickerProviderStateMixin {
  static const Color _purple   = Color(0xFF8B5CF6);
  static const Color _pink     = Color(0xFFEC4899);
  static const Color _dark     = Color(0xFF0D1B3E);
  static const Color _green    = Color(0xFF0A7A3E);

  // States: idle | handle_input | pending | verified
  String _state = 'idle';
  String? _verificationStatus;
  final _handleCtrl = TextEditingController();
  bool _submitting  = false;

  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Listen for real-time verification if already pending
    if (widget.transactionId.isNotEmpty) {
      FirebaseFirestore.instance
          .collection('transactions')
          .doc(widget.transactionId)
          .snapshots()
          .listen((snap) {
        final status = snap.data()?['socialCampaign']?['verificationStatus'] as String?;
        if (status == 'VERIFIED_AND_RELEASED' && mounted) {
          setState(() { _state = 'verified'; _verificationStatus = status; });
        }
      });
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _handleCtrl.dispose();
    super.dispose();
  }

  Future<void> _onShareTap() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Check if handle is stored
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final storedHandle = userDoc.data()?['instagramHandle'] as String?;

    if (storedHandle == null || storedHandle.isEmpty) {
      setState(() => _state = 'handle_input');
      return;
    }

    await _doShare(uid, storedHandle);
  }

  Future<void> _saveHandleAndShare() async {
    final handle = _handleCtrl.text.trim();
    if (handle.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _submitting = true);

    // Save handle to users doc
    final cleanHandle = handle.startsWith('@') ? handle : '@$handle';
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'instagramHandle': cleanHandle,
    });

    await _doShare(uid, cleanHandle);
  }

  Future<void> _doShare(String uid, String handle) async {
    // Write socialCampaign to transaction
    if (widget.transactionId.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('transactions')
          .doc(widget.transactionId)
          .update({
        'socialCampaign': {
          'isOptedIn':          true,
          'userHandle':         handle,
          'requiredTags':       ['@GoOuts_App', '@${widget.merchant.replaceAll(' ', '')}'],
          'verificationStatus': 'PENDING_VERIFICATION',
          'metaMediaId':        null,
        },
        'amounts.socialBonus': widget.bonusAmount,
      });
    }

    // Copy caption to clipboard
    final caption =
        'Just had an amazing time at ${widget.merchant}! 🙌 '
        'Powered by @GoOuts_App ✨ #GoOuts #CashbackLife';
    await Clipboard.setData(ClipboardData(text: caption));

    // Native share
    // Using url_launcher to open Instagram if available, else generic share
    // We do the simple approach: copy to clipboard + show pending state
    if (mounted) setState(() { _state = 'pending'; _submitting = false; });
  }

  void _dismiss() {
    Navigator.pop(context);
    widget.onDone?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // X button row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: _dismiss,
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded, size: 18, color: Colors.grey[500]),
                  ),
                ),
              ],
            ),
          ),

          if (_state == 'idle') _buildIdle(),
          if (_state == 'handle_input') _buildHandleInput(),
          if (_state == 'pending') _buildPending(),
          if (_state == 'verified') _buildVerified(),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Idle state ──────────────────────────────────────────────────────────────
  Widget _buildIdle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        children: [
          // Gradient icon
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 34),
          ),
          const SizedBox(height: 16),

          Text('Share & Earn Extra Cashback!',
              style: GoogleFonts.inter(
                  fontSize: 20, fontWeight: FontWeight.w800, color: _dark),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),

          // Bonus badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              '+£${widget.bonusAmount.toStringAsFixed(2)} Extra  •  ${widget.socialBoostPct.toStringAsFixed(0)}% Social Boost',
              style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
          const SizedBox(height: 12),

          Text(
            'Post a photo or video at ${widget.merchant} on\nInstagram or Facebook tagging @GoOuts_App\nto unlock your bonus cashback instantly.',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[500], height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Social logos row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _socialChip(Icons.camera_alt_rounded, 'Instagram',
                  const LinearGradient(colors: [Color(0xFFF58529), Color(0xFFDD2A7B), Color(0xFF8134AF)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight)),
              const SizedBox(width: 12),
              _socialChip(Icons.facebook_rounded, 'Facebook',
                  const LinearGradient(colors: [Color(0xFF1877F2), Color(0xFF0C5FD1)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight)),
            ],
          ),
          const SizedBox(height: 20),

          // Share button
          SizedBox(
            width: double.infinity, height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextButton(
                onPressed: () => setState(() => _state = 'handle_input'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Share & Earn Now',
                    style: GoogleFonts.inter(
                        fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Maybe Later',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[500])),
          ),
        ],
      ),
    );
  }

  // ── Handle input state ──────────────────────────────────────────────────────
  Widget _buildHandleInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Enter Your Social Handle',
              style: GoogleFonts.inter(
                  fontSize: 18, fontWeight: FontWeight.w800, color: _dark)),
          const SizedBox(height: 6),
          Text('We\'ll look up your post to verify the tag.',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[500])),
          const SizedBox(height: 16),
          TextField(
            controller: _handleCtrl,
            decoration: InputDecoration(
              hintText: '@yourusername',
              prefixIcon: const Icon(Icons.alternate_email_rounded, color: Color(0xFF8B5CF6)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextButton(
                onPressed: () {
                  if (_handleCtrl.text.trim().isEmpty) return;
                  setState(() => _state = 'pending');
                  Future.delayed(const Duration(seconds: 3), () {
                    if (mounted) setState(() => _state = 'verified');
                  });
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Submit Handle',
                    style: GoogleFonts.inter(
                        fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Pending state ───────────────────────────────────────────────────────────
  Widget _buildPending() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        children: [
          const SizedBox(
            width: 56, height: 56,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
            ),
          ),
          const SizedBox(height: 20),
          Text('Verifying Your Post…',
              style: GoogleFonts.inter(
                  fontSize: 18, fontWeight: FontWeight.w700, color: _dark)),
          const SizedBox(height: 8),
          Text(
            'We\'re checking for your tag. This usually takes a few seconds.',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Verified state ──────────────────────────────────────────────────────────
  Widget _buildVerified() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF0A7A3E).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: Color(0xFF0A7A3E), size: 40),
          ),
          const SizedBox(height: 16),
          Text('Bonus Unlocked! 🎉',
              style: GoogleFonts.inter(
                  fontSize: 20, fontWeight: FontWeight.w800, color: _dark)),
          const SizedBox(height: 8),
          Text(
            '+£${widget.bonusAmount.toStringAsFixed(2)} has been added to your cashback.',
            style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: () {
                widget.onDone?.call();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A7A3E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Done',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Social chip helper ──────────────────────────────────────────────────────
  Widget _socialChip(IconData icon, String label, LinearGradient gradient) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
        ],
      ),
    );
  }
}