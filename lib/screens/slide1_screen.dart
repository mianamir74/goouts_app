import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Slide1Screen extends StatelessWidget {
  const Slide1Screen({super.key});

  @override
  Widget build(BuildContext context) {
    final double h = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FC),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.black87, size: 22),
                      onPressed: () =>
                          Navigator.pushReplacementNamed(context, '/splash'),
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
                          'assets/images/slide1_illustration.webp',
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (context, error, stack) => Center(
                            child: Icon(
                              Icons.contactless_rounded,
                              size: 80,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 20,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 28, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '+£24.50',
                                  style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Earned',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.85),
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

            SizedBox(height: h * 0.03),

            // Headline
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Tap. Pay. Earn.\nAutomatically.',
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

            SizedBox(height: h * 0.016),

            // Body text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                'Your GoOuts Virtual Card is ready the moment you sign up. Add it to Apple Pay or Google Pay, tap any partner terminal to pay, and cashback lands in your wallet automatically.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                  height: 1.6,
                ),
              ),
            ),

            const Spacer(),

            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _dot(true),
                const SizedBox(width: 6),
                _dot(false),
                const SizedBox(width: 6),
                _dot(false),
                const SizedBox(width: 6),
                _dot(false),
                const SizedBox(width: 6),
                _dot(false),
                const SizedBox(width: 6),
                _dot(false),
              ],
            ),

            SizedBox(height: h * 0.025),

            // Next button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, '/slide2'),
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
              : Colors.grey.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(4),
        ),
      );
}
