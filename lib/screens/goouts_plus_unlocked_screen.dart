import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';
import '../services/user_service.dart';
import '../services/family_service.dart';

class GoOutsPlusUnlockedScreen extends StatefulWidget {
  const GoOutsPlusUnlockedScreen({super.key});

  @override
  State<GoOutsPlusUnlockedScreen> createState() => _GoOutsPlusUnlockedScreenState();
}

class _GoOutsPlusUnlockedScreenState extends State<GoOutsPlusUnlockedScreen>
    with SingleTickerProviderStateMixin {
  static const Color _primary = Color(0xFF0392CA);
  static const Color _dark = Color(0xFF0D1B3E);
  static const Color _green = Color(0xFF0A7A3E);
  static const Color _gold = Color(0xFFFFBF00);

  late ConfettiController _confettiController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 4));
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    // Fire confetti and fade in on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _confettiController.play();
      _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _dark,
      body: Stack(
        children: [

          // ── Background gradient ──
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D1B3E), Color(0xFF0A3A6E)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // ── Confetti ──
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Color(0xFF0392CA),
                Color(0xFFFFBF00),
                Colors.white,
                Color(0xFF0A7A3E),
                Color(0xFFFF6B6B),
              ],
              numberOfParticles: 40,
              gravity: 0.3,
              emissionFrequency: 0.08,
              minimumSize: const Size(8, 8),
              maximumSize: const Size(18, 18),
              blastDirection: pi / 2,
            ),
          ),

          // ── Content ──
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                child: Column(
                  children: [

                    // ── Close button ──
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Star badge ──
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: _gold.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: _gold.withOpacity(0.4), width: 2),
                      ),
                      child: const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFFFBF00),
                        size: 48,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Headline ──
                    Text(
                      'You\'ve unlocked\nGoOuts Plus!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.25,
                      ),
                    ),

                    const SizedBox(height: 14),

                    Text(
                      'Your family earned £100 in cashback together.\nHere\'s what you get for just £10 a year.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                        height: 1.6,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Feature Cards ──
                    _buildFeatureCard(
                      icon: Icons.savings_rounded,
                      color: _green,
                      title: 'Bonus Cashback',
                      subtitle: 'Earn 1 to 2% more at every GoOuts partner — on top of the rate you already get.',
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureCard(
                      icon: Icons.local_offer_rounded,
                      color: const Color(0xFFE65100),
                      title: 'Member Discounts',
                      subtitle: 'Exclusive deals at selected partners, only available to GoOuts Plus members.',
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureCard(
                      icon: Icons.flash_on_rounded,
                      color: _gold,
                      title: 'Early Access',
                      subtitle: 'See brand new partner offers 24 hours before anyone else.',
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureCard(
                      icon: Icons.bar_chart_rounded,
                      color: _primary,
                      title: 'Family Dashboard',
                      subtitle: 'Track your whole family\'s cashback and spending in one beautiful view.',
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureCard(
                      icon: Icons.support_agent_rounded,
                      color: const Color(0xFF7B1FA2),
                      title: 'Priority Support',
                      subtitle: 'Any question, any issue — our team gets back to you within four hours.',
                    ),

                    const SizedBox(height: 32),

                    // ── Price pill ──
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Everything above, for your whole family ',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                          Text(
                            '— just £10/year',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _gold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Activate CTA ──
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _showConfirmationSheet(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _gold,
                          foregroundColor: _dark,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Activate GoOuts Plus — £10/year',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _dark,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Maybe later ──
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text(
                        'Maybe later',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.45),
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white.withOpacity(0.3),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Legal note ──
                    Text(
                      'Renews annually. Cancel any time in 3 taps.\nFull refund available within 14 days.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.3),
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Confirmation bottom sheet ──────────────────────────────
  void _showConfirmationSheet(BuildContext context) {
    bool _activating = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Handle bar
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title
              Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFBF00).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.star_rounded,
                        color: Color(0xFFFFBF00), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Before we activate',
                          style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0D1B3E))),
                      Text('Here is exactly what happens next',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.grey[500])),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // What will be charged
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F4F7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _confirmRow(
                      Icons.payments_rounded,
                      const Color(0xFF0392CA),
                      'Charge amount',
                      '£10.00 — one annual payment for your whole family',
                    ),
                    const SizedBox(height: 14),
                    _confirmRow(
                      Icons.account_balance_wallet_rounded,
                      const Color(0xFF0A7A3E),
                      'Charged from',
                      'Your GoOuts Wallet first. If your balance is low, the rest comes from your linked bank.',
                    ),
                    const SizedBox(height: 14),
                    _confirmRow(
                      Icons.autorenew_rounded,
                      const Color(0xFF0D1B3E),
                      'Renewal',
                      'Renews automatically in 12 months. We remind you 30 days before.',
                    ),
                    const SizedBox(height: 14),
                    _confirmRow(
                      Icons.cancel_outlined,
                      Colors.red[400]!,
                      'Cancellation',
                      'Cancel any time in 3 taps. Full refund if cancelled within 14 days.',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Legal note
              Text(
                'By tapping Confirm, you authorise GoOuts to charge £10.00 to your GoOuts Wallet or linked bank account. This charge will appear in your Activity screen as "GoOuts Plus — Annual Membership".',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.grey[500],
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _activating
                          ? null
                          : () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey[300]!),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Not Now',
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600])),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _activating
                          ? null
                          : () async {
                              setSheet(() => _activating = true);

                              final result =
                                  await UserService().chargeGoOutsPlus();

                              // If user is in a family group, activate for all
                              if (result['success'] == true) {
                                final userData =
                                    await UserService().getCurrentUser();
                                final groupId =
                                    userData?['familyGroupId'] as String?;
                                if (groupId != null) {
                                  await FamilyService()
                                      .activatePlusForGroup(groupId);
                                }
                              }

                              if (!ctx.mounted) return;
                              Navigator.pop(ctx); // close sheet

                              if (result['success'] == true) {
                                _showActivationSuccess(context, result);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      result['error'] ??
                                          'Something went wrong. Please try again.',
                                      style: GoogleFonts.inter(fontSize: 13),
                                    ),
                                    backgroundColor: Colors.red[700],
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFBF00),
                        foregroundColor: const Color(0xFF0D1B3E),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _activating
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  color: Color(0xFF0D1B3E), strokeWidth: 2),
                            )
                          : Text('Confirm — £10.00',
                              style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0D1B3E))),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Confirm row helper ─────────────────────────────────────
  Widget _confirmRow(
          IconData icon, Color color, String label, String value) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0D1B3E))),
                const SizedBox(height: 2),
                Text(value,
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[600],
                        height: 1.4)),
              ],
            ),
          ),
        ],
      );

  // ── Activation success dialog ──────────────────────────────
  void _showActivationSuccess(
      BuildContext context, Map<String, dynamic> result) {
    final double fromWallet =
        (result['chargedFromWallet'] as double?) ?? 0.0;
    final double fromBank =
        (result['chargedFromBank'] as double?) ?? 0.0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A7A3E).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF0A7A3E), size: 40),
              ),
              const SizedBox(height: 18),
              Text('GoOuts Plus is active!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0D1B3E))),
              const SizedBox(height: 10),
              Text(
                fromBank > 0
                    ? 'We charged £${fromWallet.toStringAsFixed(2)} from your wallet and £${fromBank.toStringAsFixed(2)} from your linked bank. All your Plus benefits are now active for you and your family.'
                    : 'We charged £10.00 from your GoOuts Wallet. All your Plus benefits are now active for you and your family.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey[600],
                    height: 1.6),
              ),
              const SizedBox(height: 8),
              Text(
                'The charge appears in your Activity screen as "GoOuts Plus — Annual Membership".',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.grey[400],
                    height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // close dialog
                    Navigator.pushNamedAndRemoveUntil(
                        context, '/home', (route) => false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0392CA),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Start enjoying Plus',
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.6),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
