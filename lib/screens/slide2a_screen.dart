import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Slide2aScreen extends StatelessWidget {
  const Slide2aScreen({super.key});

  static const Color _primary = Color(0xFF0392CA);
  static const Color _surface = Color(0xFFF9F9FC);
  static const Color _dark = Color(0xFF0D1B3E);

  @override
  Widget build(BuildContext context) {
    final double h = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header — matches slide2 exactly
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
                          Navigator.pushReplacementNamed(context, '/slide2'),
                    ),
                  ),
                  Text(
                    'GoOuts',
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: _primary,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: h * 0.02),

            // Illustration — matches slide2 Expanded(flex:5) structure
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/slide2a_illustration.webp',
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (ctx, err, st) => Center(
                        child: Icon(
                          Icons.account_balance_rounded,
                          size: 80,
                          color: _primary.withOpacity(0.3),
                        ),
                      ),
                    ),
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
                  'Secure Bank Connection',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: _dark,
                    height: 1.2,
                  ),
                ),
              ),
            ),

            SizedBox(height: h * 0.014),

            // Body
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'To instantly earn cashback points, securely connect your bank and card to your GoOuts Wallet. You will receive your GoOuts Virtual Debit Card as part of setup. Use it the same way you tap your bank card when paying with your mobile.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _dark.withOpacity(0.7),
                  height: 1.55,
                ),
              ),
            ),

            const Spacer(),

            // Pagination dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _dot(false),
                const SizedBox(width: 6),
                _dot(false),
                const SizedBox(width: 6),
                _dot(true),
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
                      Navigator.pushReplacementNamed(context, '/slide3'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
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
          color: active ? _primary : Colors.grey.withOpacity(0.35),
          borderRadius: BorderRadius.circular(4),
        ),
      );
}
