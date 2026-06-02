import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';

class RegistrationSuccessScreen extends StatefulWidget {
  const RegistrationSuccessScreen({super.key});

  @override
  State<RegistrationSuccessScreen> createState() =>
      _RegistrationSuccessScreenState();
}

class _RegistrationSuccessScreenState extends State<RegistrationSuccessScreen> {
  late ConfettiController _confettiController;
  bool _step02Done = false;

  static const Color _primary = Color(0xFF0392CA);
  static const Color _dark = Color(0xFF0D1B3E);

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 4));
    // Auto-play on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _confettiController.play();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final prefix = args?['prefix'] as String? ?? '';
    final firstName = args?['name'] as String? ?? '';
    final greeting = [prefix, firstName].where((s) => s.isNotEmpty).join(' ');

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      body: Stack(
        children: [
          // Main content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 16),

                  // GoOuts header
                  Text(
                    'GoOuts',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _primary,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Checkmark circle
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: _primary,
                      size: 40,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Title
                  Text(
                    greeting.isNotEmpty
                        ? 'Congratulations,\n$greeting!'
                        : 'Congratulations!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: _dark,
                      height: 1.2,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Subtitle
                  Text(
                    "Your GoOuts account is ready. Link a payment method below and start earning cashback every time you spend.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.55,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Step 01 - Account Created card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.black.withOpacity(0.07)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STEP 01',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _primary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                color: _primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                'Virtual Debit Card Generated',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: _dark,
                                ),
                              ),
                            ),
                            Text(
                              'Done',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Next Step label
                  Text(
                    'One small step left',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[500],
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Link Debit/Credit/Bank Account
                  _paymentOption(
                    context,
                    stepLabel: 'STEP 02',
                    icon: Icons.credit_card_rounded,
                    title: 'Link Your Payment Method',
                    subtitle: 'Smart Pay, wallet top up or card',
                    trailingIcon: _step02Done
                        ? Icons.check_circle_rounded
                        : Icons.chevron_right_rounded,
                    trailingColor: _step02Done ? _primary : Colors.grey,
                    onTap: () {
                      Navigator.pushNamed(context, '/link-card')
                          .then((result) {
                        if (result == true) setState(() => _step02Done = true);
                      });
                    },
                  ),

                  const SizedBox(height: 20),

                  // Start Connecting button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/add-to-wallet'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: Text(
                        'Add to Wallet',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Skip — goes to bonus added with reminder ticket
                  TextButton(
                    onPressed: () =>
                        Navigator.pushReplacementNamed(context, '/bonus-added'),
                    child: Text(
                      'Maybe later',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[500],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Security note
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_outline_rounded,
                          size: 13, color: Colors.grey),
                      const SizedBox(width: 5),
                      Text(
                        'Your information is always safe with us.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Text(
                    "Your data is secure and encrypted via our industry-leading payment gateway partner.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.grey[500],
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Confetti — fires from top centre
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi / 2, // straight down
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.08,
              numberOfParticles: 20,
              maxBlastForce: 40,
              minBlastForce: 15,
              gravity: 0.3,
              shouldLoop: false,
              colors: const [
                Color(0xFF0392CA),
                Color(0xFFFFD700),
                Color(0xFFFF6B6B),
                Color(0xFF6BCB77),
                Color(0xFFFF922B),
                Colors.white,
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _paymentOption(
    BuildContext context, {
    required String stepLabel,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    IconData trailingIcon = Icons.chevron_right_rounded,
    Color trailingColor = Colors.grey,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black.withOpacity(0.07)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stepLabel,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _primary,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: _primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _dark,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(trailingIcon, color: trailingColor, size: 24),
                ],
              ),
            ],
          ),
        ),
      );
}
