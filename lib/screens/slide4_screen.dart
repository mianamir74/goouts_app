import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Slide4Screen extends StatelessWidget {
  const Slide4Screen({super.key});

  @override
  Widget build(BuildContext context) {
    final double h = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FC),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.black87, size: 22),
                      onPressed: () =>
                          Navigator.pushReplacementNamed(context, '/slide3'),
                    ),
                  ),
                  Text(
                    'GoOuts',
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0392CA),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: h * 0.02),

            // Illustration container
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1B3E),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/images/slide4_illustration.png',
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (context, error, stack) => Center(
                            child: Icon(
                              Icons.explore_rounded,
                              size: 80,
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                        ),
                      ),
                      // Badge
                      Positioned(
                        bottom: 20,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.25),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.card_giftcard_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Welcome Bonus Inside',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(height: h * 0.028),

            // Headline
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Your Welcome\nBonus Awaits',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0D1B3E),
                    height: 1.25,
                  ),
                ),
              ),
            ),

            SizedBox(height: h * 0.014),

            // Body text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                'Sign up today and we drop a welcome cashback bonus straight into your GoOuts wallet. No conditions, no waiting. Just a little gift from us to kick things off.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                  height: 1.6,
                ),
              ),
            ),

            SizedBox(height: h * 0.022),

            // Family caption
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0392CA).withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.people_alt_rounded,
                      color: Color(0xFF0392CA),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'The more family you add, the more you earn together. And if you feel generous, you can always share your cashback with friends and family too.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF0392CA),
                          height: 1.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Dots — 5th of 6 active
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _dot(false),
                const SizedBox(width: 6),
                _dot(false),
                const SizedBox(width: 6),
                _dot(false),
                const SizedBox(width: 6),
                _dot(false),
                const SizedBox(width: 6),
                _dot(true),
                const SizedBox(width: 6),
                _dot(false),
              ],
            ),

            SizedBox(height: h * 0.025),

            // Next button → signup
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushReplacementNamed(
                    context,
                    '/family-cashback-intro',
                    arguments: {'fromOnboarding': true},
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0392CA),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Next',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right_rounded,
                          color: Colors.white, size: 22),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(bool active) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: active ? 24 : 8,
        height: 8,
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF0392CA)
              : Colors.grey.withOpacity(0.35),
          borderRadius: BorderRadius.circular(4),
        ),
      );
}
