import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/user_service.dart';
import '../services/transaction_service.dart';
import '../services/visit_verifier.dart';

enum _StepState { passed, failed, loading, waiting }

/// Counter-service (QR required) vs table-service (GPS only).
/// Mirrors the same logic in partner_details_screen.dart.
bool _isCounterService(String category) {
  final c = category.toLowerCase();
  const counterKeywords = [
    'café', 'cafe', 'coffee', 'fast food', 'fastfood', 'takeaway',
    'take away', 'bakery', 'street food', 'retail', 'shop', 'store',
    'pharmacy', 'supermarket', 'grocery', 'deli', 'sandwich', 'juice',
    'smoothie', 'bubble tea', 'ice cream', 'dessert', 'food court',
  ];
  return counterKeywords.any((kw) => c.contains(kw));
}

class PartnerOfferScreen extends StatelessWidget {
  const PartnerOfferScreen({super.key});

  static const Color _primary = Color(0xFF0392CA);
  static const Color _dark = Color(0xFF191C1E);
  static const Color _grey = Color(0xFF42474E);

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final name = args?['name'] as String? ?? 'Artisan Brews';
    final address = args?['address'] as String? ?? '12 Baker Street, London';
    final rating = args?['rating'] as String? ?? '4.8';
    final imagePath = args?['imagePath'] as String? ??
        'assets/images/special offers/working_table.webp';
    final tag = args?['tag'] as String? ?? '20% OFF';
    final promoCode = args?['promoCode'] as String? ?? 'BREW20';
    final offerTitle = args?['offerTitle'] as String? ?? 'Total Bill Reward';
    final cashback = args?['cashback'] as String? ?? '15% Cashback';
    final category = args?['category'] as String? ?? '\$\$ • Coffee';

    // Determine if QR scan is required (counter service) or GPS-only (table service)
    final partnerType = args?['partnerType'] as String?;
    // partnerType kept for future use; verification is GPS-first → code fallback
    // ignore: unused_local_variable
    final String? partnerTypeVal = partnerType;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _primary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Text(
          'GoOuts',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _primary,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: _primary),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Image + Overlapping Info Card
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Hero image
                SizedBox(
                  height: 260,
                  width: double.infinity,
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (ctx, err, st) => Container(
                      height: 260,
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(Icons.store_rounded,
                            color: Colors.white54, size: 64),
                      ),
                    ),
                  ),
                ),

                // Overlapping white info card
                Positioned(
                  bottom: -70,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      name,
                                      style: GoogleFonts.inter(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: _dark,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.verified_rounded,
                                      color: _primary, size: 18),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.star_rounded,
                                      color: Colors.white, size: 13),
                                  const SizedBox(width: 4),
                                  Text(
                                    rating,
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 14, color: _grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                address,
                                style: GoogleFonts.inter(
                                    color: _grey, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _chip('(1.2k reviews)', Colors.grey[100]!, _grey),
                            const SizedBox(width: 8),
                            _chip(category, Colors.grey[100]!, _grey),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Premium artisan coffee and handcrafted pastries in the heart of the city.',
                          style: GoogleFonts.inter(
                              color: _grey, fontSize: 13, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 90),

            // Exclusive Offers header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Exclusive Offers',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _dark,
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      'View All',
                      style: GoogleFonts.inter(
                          color: _primary, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Main offer card (blue)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.local_offer_outlined,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tag,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            offerTitle,
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'PROMO: $promoCode',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.bolt_rounded,
                        color: Colors.white, size: 32),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Two smaller benefit cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: _benefitCard(
                      icon: Icons.account_balance_wallet_rounded,
                      iconBg: const Color(0xFFE0F3FB),
                      iconColor: _primary,
                      title: cashback,
                      subtitle: 'Instant Cashback',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _benefitCard(
                      icon: Icons.calendar_today_rounded,
                      iconBg: const Color(0xFFFFF3E0),
                      iconColor: Colors.orange[700]!,
                      title: '2x',
                      subtitle: 'Points Multiplier',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 120),
          ],
        ),
      ),
      bottomSheet: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => _showVerifyVisit(context, name, tag, cashback, promoCode),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.qr_code_scanner_rounded, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Pay & Earn Cashback',
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Verify Visit: GPS first → if fails, show partner code fallback ────────
  void _showVerifyVisit(BuildContext context, String merchant, String tag,
      String cashback, String promoCode) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final partnerLat   = (args?['lat'] as num?)?.toDouble() ?? 0.0;
    final partnerLng   = (args?['lng'] as num?)?.toDouble() ?? 0.0;
    final verifyCode   = (args?['verificationCode'] as String? ?? '').toUpperCase().trim();

    // ── state ──
    bool gpsChecked   = false;
    bool gpsPassed    = false;
    bool gpsRunning   = true;
    String gpsMessage = 'Checking your location…';

    bool showCodeEntry = false;   // flip to true when GPS fails
    bool codePassed    = false;
    bool codeChecking  = false;
    String codeError   = '';
    final codeCtrl     = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {

          // ── Auto-run GPS when sheet opens ──────────────────────────────
          if (!gpsChecked) {
            gpsChecked = true;
            VisitVerifier.checkGps(partnerLat, partnerLng).then((result) {
              if (!ctx.mounted) return;
              setSheet(() {
                gpsRunning = false;
                gpsPassed  = result.withinRange;
                if (result.error != null) {
                  gpsMessage = result.error!;
                } else if (result.withinRange) {
                  final dist = result.distanceMetres != null
                      ? ' (${result.distanceMetres!.toStringAsFixed(0)}m)'
                      : '';
                  gpsMessage = 'You\'re at $merchant$dist ✓';
                } else {
                  final dist = result.distanceMetres != null
                      ? '${result.distanceMetres!.toStringAsFixed(0)}m away'
                      : 'location not confirmed';
                  gpsMessage = 'GPS shows you\'re $dist.';
                  showCodeEntry = true;   // GPS failed → show code fallback
                }
              });
            });
          }

          // ── Auto-proceed when GPS passes ───────────────────────────────
          if (gpsPassed) {
            Future.microtask(() {
              if (ctx.mounted) {
                Navigator.pop(ctx);
                _showPayConfirmation(context, merchant, tag, cashback, promoCode);
              }
            });
          }

          // ── Verify partner code ────────────────────────────────────────
          Future<void> checkCode() async {
            final entered = codeCtrl.text.trim().toUpperCase();
            if (entered.isEmpty) {
              setSheet(() => codeError = 'Please enter the partner code.');
              return;
            }
            setSheet(() { codeChecking = true; codeError = ''; });
            await Future.delayed(const Duration(milliseconds: 600));
            if (!ctx.mounted) return;
            if (verifyCode.isNotEmpty && entered == verifyCode) {
              setSheet(() { codeChecking = false; codePassed = true; });
              await Future.delayed(const Duration(milliseconds: 500));
              if (ctx.mounted) {
                Navigator.pop(ctx);
                _showPayConfirmation(context, merchant, tag, cashback, promoCode);
              }
            } else {
              setSheet(() {
                codeChecking = false;
                codeError = 'Incorrect code. Please ask staff for the partner code.';
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
                  // Handle
                  const SizedBox(height: 12),
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 20),

                  // Title
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
                                      color: _dark)),
                              Text(
                                showCodeEntry
                                    ? 'Enter partner code to unlock payment'
                                    : 'Checking your location…',
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
                        // ── Step 1: GPS ──────────────────────────────────
                        _verifyStep(
                          step: '1',
                          icon: Icons.location_on_rounded,
                          title: 'GPS Location Check',
                          message: gpsMessage,
                          state: gpsRunning
                              ? _StepState.loading
                              : gpsPassed
                                  ? _StepState.passed
                                  : _StepState.failed,
                        ),

                        // ── Step 2: Partner code — only if GPS failed ────
                        if (showCodeEntry) ...[
                          const SizedBox(height: 12),
                          _verifyStep(
                            step: '2',
                            icon: Icons.pin_rounded,
                            title: 'Partner Code',
                            message: codePassed
                                ? 'Code verified ✓'
                                : 'GPS couldn\'t confirm your location. Enter the code from staff.',
                            state: codePassed
                                ? _StepState.passed
                                : _StepState.waiting,
                          ),
                          const SizedBox(height: 16),

                          // Code input field
                          TextFormField(
                            controller: codeCtrl,
                            textCapitalization: TextCapitalization.characters,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 6,
                                color: _dark),
                            decoration: InputDecoration(
                              hintText: 'ENTER CODE',
                              hintStyle: GoogleFonts.inter(
                                  fontSize: 16,
                                  letterSpacing: 4,
                                  color: Colors.grey[350]),
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

                          // Verify button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
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
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Demo bypass (long-press)
                  const SizedBox(height: 16),
                  GestureDetector(
                    onLongPress: () {
                      setSheet(() {
                        gpsRunning = false;
                        gpsPassed  = true;
                        gpsMessage = 'Demo: location verified ✓';
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Demo mode: long-press here to simulate GPS pass',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                            fontSize: 11, color: Colors.grey[400]),
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
    ).whenComplete(() => codeCtrl.dispose());
  }

  // ── Verify step card ───────────────────────────────────────────────────────
  Widget _verifyStep({
    required String step,
    required IconData icon,
    required String title,
    required String message,
    required _StepState state,
  }) {
    Color bg;
    Color iconColor;
    Widget trailing;

    switch (state) {
      case _StepState.passed:
        bg = const Color(0xFFE6F4EC);
        iconColor = const Color(0xFF0A7A3E);
        trailing = const Icon(Icons.check_circle_rounded,
            color: Color(0xFF0A7A3E), size: 22);
        break;
      case _StepState.failed:
        bg = const Color(0xFFFFEBEE);
        iconColor = Colors.red[700]!;
        trailing = Icon(Icons.cancel_rounded, color: Colors.red[700], size: 22);
        break;
      case _StepState.loading:
        bg = const Color(0xFFF0F6FA);
        iconColor = _primary;
        trailing = const SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: _primary));
        break;
      case _StepState.waiting:
        bg = const Color(0xFFF0F6FA);
        iconColor = Colors.grey;
        trailing = const Icon(Icons.radio_button_unchecked_rounded,
            color: Colors.grey, size: 22);
        break;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Step $step — $title',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _dark)),
                const SizedBox(height: 2),
                Text(message,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: Colors.grey[600], height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }

  void _showPayConfirmation(BuildContext context, String merchant, String tag,
      String cashback, String promoCode) {
    final amountCtrl = TextEditingController();
    bool isProcessing = false;
    double walletBalance = 0.0;
    bool walletLoaded = false;

    // Parse cashback % from string like "10% Cashback" or "15% Cashback"
    double cashbackPct = 0.0;
    final pctMatch = RegExp(r'(\d+)').firstMatch(cashback);
    if (pctMatch != null) {
      cashbackPct = double.tryParse(pctMatch.group(1)!) ?? 0.0;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final spendAmount = double.tryParse(amountCtrl.text) ?? 0.0;
          final cashbackAmount = spendAmount * (cashbackPct / 100);

          // Split payment calculation
          final walletCovers = walletBalance >= spendAmount
              ? spendAmount
              : walletBalance;
          final bankCovers = spendAmount > walletBalance
              ? spendAmount - walletBalance
              : 0.0;
          final hasWallet = walletCovers > 0;
          final hasBank = bankCovers > 0;

          String payMethodLabel;
          if (spendAmount <= 0) {
            payMethodLabel = '—';
          } else if (hasWallet && !hasBank) {
            payMethodLabel = 'GoOuts Wallet';
          } else if (hasWallet && hasBank) {
            payMethodLabel = 'Wallet + Bank Card';
          } else {
            payMethodLabel = 'Bank Card';
          }

          // Load wallet balance once on first build
          if (!walletLoaded) {
            walletLoaded = true;
            UserService().getCurrentUser().then((data) {
              final bal = (data?['walletBalance'] as num?)?.toDouble() ?? 0.0;
              setSheet(() => walletBalance = bal);
            });
          }

          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Icon
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.local_offer_rounded,
                        color: _primary, size: 30),
                  ),
                  const SizedBox(height: 14),

                  Text('Confirm & Pay',
                      style: GoogleFonts.inter(
                          fontSize: 20, fontWeight: FontWeight.w800, color: _dark)),
                  const SizedBox(height: 4),
                  Text(merchant,
                      style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[500])),

                  const SizedBox(height: 20),

                  // Amount input
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F4F7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        Text('£', style: GoogleFonts.inter(
                            fontSize: 22, fontWeight: FontWeight.w700, color: _dark)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: amountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                            style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: _dark),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: '0.00',
                              hintStyle: GoogleFonts.inter(fontSize: 22, color: Colors.grey[400]),
                            ),
                            onChanged: (_) => setSheet(() {}),
                          ),
                        ),
                        Text('spent', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[500])),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),

                  _payRow(Icons.account_balance_wallet_rounded, 'Payment Method', payMethodLabel),
                  const SizedBox(height: 12),

                  // Split breakdown — only when amount entered
                  if (spendAmount > 0) ...[
                    if (hasWallet)
                      _payRow(Icons.account_balance_wallet_rounded,
                          '  GoOuts Wallet', '£${walletCovers.toStringAsFixed(2)}',
                          valueColor: _primary),
                    if (hasBank)
                      _payRow(Icons.credit_card_rounded,
                          '  Bank Card (remaining)', '£${bankCovers.toStringAsFixed(2)}',
                          valueColor: Colors.orange[700]!),
                    const SizedBox(height: 4),
                  ],

                  _payRow(Icons.bolt_rounded, 'Cashback Rate', '$cashbackPct% back'),
                  const SizedBox(height: 12),
                  _payRow(Icons.savings_rounded, 'Cashback Earned',
                      spendAmount > 0 ? '£${cashbackAmount.toStringAsFixed(2)}' : '—'),

                  if (spendAmount > 0) ...[
                    const SizedBox(height: 14),
                    // Split payment notice when bank involved
                    if (hasBank)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                color: Colors.orange[700], size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                hasWallet
                                    ? 'GoOuts Wallet covers £${walletCovers.toStringAsFixed(2)}. '
                                      'Remaining £${bankCovers.toStringAsFixed(2)} will be charged to your linked bank card.'
                                    : 'No wallet balance. Full £${bankCovers.toStringAsFixed(2)} will be charged to your linked bank card.',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.orange[800],
                                    height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6F4EC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.celebration_rounded,
                              color: Color(0xFF0A7A3E), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'You will earn £${cashbackAmount.toStringAsFixed(2)} cashback instantly!',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xFF0A7A3E),
                                  fontWeight: FontWeight.w600,
                                  height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Confirm button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: (isProcessing || spendAmount <= 0)
                          ? null
                          : () async {
                              setSheet(() => isProcessing = true);
                              try {
                                // 1. Get current balances
                                final userData = await UserService().getCurrentUser();
                                final currentWallet = (userData?['walletBalance'] as num?)?.toDouble() ?? 0.0;
                                final currentCashback = (userData?['cashbackBalance'] as num?)?.toDouble() ?? 0.0;

                                // Calculate split
                                final wPortion = currentWallet >= spendAmount
                                    ? spendAmount
                                    : currentWallet;
                                final bPortion = spendAmount > currentWallet
                                    ? spendAmount - currentWallet
                                    : 0.0;

                                final newWallet = currentWallet - wPortion;
                                final newCashback = currentCashback + cashbackAmount;

                                // 2. Spending transaction label
                                final payLabel = bPortion > 0
                                    ? (wPortion > 0
                                        ? 'Paid at $merchant (Wallet + Bank)'
                                        : 'Paid at $merchant (Bank Card)')
                                    : 'Spent at $merchant';

                                await TransactionService().addTransaction(
                                  title: payLabel,
                                  amount: spendAmount,
                                  amountFormatted: '-£${spendAmount.toStringAsFixed(2)}',
                                  type: 'Spending',
                                  iconKey: 'store',
                                  positive: false,
                                  status: 'Completed',
                                  cashbackEarned: cashbackAmount,
                                );

                                // 3. Cashback transaction
                                await TransactionService().addTransaction(
                                  title: 'Cashback from $merchant',
                                  amount: cashbackAmount,
                                  amountFormatted: '+£${cashbackAmount.toStringAsFixed(2)}',
                                  type: 'Cashback',
                                  iconKey: 'store',
                                  positive: true,
                                  status: 'Completed',
                                );

                                // 4. Update wallet balance (only deduct what wallet covered)
                                await UserService().updateUser({
                                  'walletBalance': newWallet,
                                  'cashbackBalance': newCashback,
                                });

                                // Track lifetime cashback — returns true if £100 milestone just triggered
                                final bool plusUnlocked =
                                    await UserService().recordCashbackEarned(cashbackAmount);

                                if (ctx.mounted) {
                                  Navigator.pop(ctx); // close bottom sheet
                                  Navigator.pushNamed(
                                    context,
                                    '/payment-review',
                                    arguments: {
                                      'merchant': merchant,
                                      'amount': spendAmount,
                                      'cashback': cashbackAmount,
                                      'cashbackPct': cashbackPct,
                                      'walletPortion': wPortion,
                                      'bankPortion': bPortion,
                                    },
                                  );

                                  // If £100 milestone just triggered — show GoOuts Plus celebration
                                  if (plusUnlocked) {
                                    Future.delayed(const Duration(seconds: 2), () {
                                      if (context.mounted) {
                                        Navigator.pushNamed(
                                            context, '/goouts-plus-unlocked');
                                      }
                                    });
                                  }
                                }
                              } catch (_) {
                                setSheet(() => isProcessing = false);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Payment failed. Please try again.')),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        disabledBackgroundColor: _primary.withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: isProcessing
                          ? const SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : Text(
                              spendAmount > 0
                                  ? 'Confirm & Pay £${spendAmount.toStringAsFixed(2)}'
                                  : 'Enter Amount to Pay',
                              style: GoogleFonts.inter(
                                  fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),

                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Cancel',
                        style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[500])),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _payRow(IconData icon, String label, String value, {Color? valueColor}) => Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: Colors.grey[500])),
                Text(value,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: valueColor ?? _dark)),
              ],
            ),
          ),
        ],
      );

  Widget _chip(String text, Color bg, Color textColor) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
              color: textColor, fontSize: 12, fontWeight: FontWeight.w500),
        ),
      );

  Widget _benefitCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 10),
            Text(title,
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF191C1E))),
            Text(subtitle,
                style: GoogleFonts.inter(
                    fontSize: 12, color: const Color(0xFF42474E))),
          ],
        ),
      );
}
