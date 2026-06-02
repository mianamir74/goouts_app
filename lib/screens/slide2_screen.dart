import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Slide2Screen extends StatelessWidget {
  const Slide2Screen({super.key});

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
                          Navigator.pushReplacementNamed(context, '/slide1'),
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
                    color: const Color(0xFFD6EEF8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/images/slide2_illustration.png',
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (context, error, stack) => Center(
                            child: Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 80,
                              color: const Color(0xFF0392CA).withOpacity(0.4),
                            ),
                          ),
                        ),
                      ),
                      // Redemption badge
                      Positioned(
                        bottom: 20,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.75),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.9),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0392CA)
                                        .withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.account_balance_wallet_rounded,
                                    color: Color(0xFF0392CA),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '-£4.20',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF0392CA),
                                      ),
                                    ),
                                    Text(
                                      'Redemption',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
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

            SizedBox(height: h * 0.025),

            // Headline
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Universal Redemption',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0D1B3E),
                    height: 1.2,
                  ),
                ),
              ),
            ),

            SizedBox(height: h * 0.014),

            // Body text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Use your points anywhere. Your cashback is as flexible as cash.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0D1B3E).withOpacity(0.7),
                  height: 1.55,
                ),
              ),
            ),

            SizedBox(height: h * 0.012),

            // Disclaimer text — improved contrast & size
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                'Redeeming cashback Points internationally is subject to exchange rates and fees. Use your GoOuts virtual debit card for these transactions.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                  height: 1.55,
                ),
              ),
            ),

            const Spacer(),

            // Dots — second active
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _dot(false),
                const SizedBox(width: 6),
                _dot(true),
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
                      Navigator.pushReplacementNamed(context, '/slide2a'),
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
