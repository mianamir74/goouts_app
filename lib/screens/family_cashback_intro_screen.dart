import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FamilyCashbackIntroScreen extends StatelessWidget {
  /// fromOnboarding = true  → shown during signup flow,
  ///                          both buttons navigate to /signup
  /// fromOnboarding = false → shown after first cashback (Touch 2),
  ///                          Add Family goes to /family-plan,
  ///                          Maybe Later dismisses
  final bool fromOnboarding;

  const FamilyCashbackIntroScreen({
    super.key,
    this.fromOnboarding = false,
  });

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF0392CA);
    const Color surfaceColor = Color(0xFFF9F9FC);
    const Color onSurfaceColor = Color(0xFF191C1E);
    const Color onSurfaceVariant = Color(0xFF42474E);

    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primaryColor),
          onPressed: () => fromOnboarding
              ? Navigator.pushReplacementNamed(context, '/slide4')
              : Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Text(
          'GoOuts',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: primaryColor,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          if (fromOnboarding)
            TextButton(
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, '/signup'),
              child: Text(
                'Finish',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.arrow_forward, color: primaryColor),
              onPressed: () =>
                  Navigator.pushNamed(context, '/family-plan'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 20),

              // ── Illustration ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: AspectRatio(
                  aspectRatio: 1 / 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(32),
                      image: const DecorationImage(
                        image: AssetImage(
                            'assets/images/family_cashback.webp'),
                        fit: BoxFit.cover,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // ── Headline ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Text(
                  'Your family can earn cashback too.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: onSurfaceColor,
                    height: 1.2,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ── Body ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Text(
                  'The more family you add to your GoOuts account, the more you earn together. And if you feel generous, you can always share your cashback with friends and family too.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: onSurfaceVariant,
                    height: 1.55,
                  ),
                ),
              ),

              const SizedBox(height: 48),

              // ── Dots ──
              if (fromOnboarding)
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
                    _dot(false),
                    const SizedBox(width: 6),
                    _dot(true), // 6th slide active
                  ],
                ),

              const SizedBox(height: 24),

              // ── Buttons ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  children: [

                    // Maybe Later
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: OutlinedButton(
                          onPressed: () => fromOnboarding
                              ? Navigator.pushReplacementNamed(
                                  context, '/signup')
                              : Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: primaryColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            fromOnboarding ? 'Skip' : 'Maybe Later',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 14),

                    // Add Family / Get Started
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () => fromOnboarding
                              ? Navigator.pushReplacementNamed(
                                  context, '/signup')
                              : Navigator.pushNamed(
                                  context, '/family-plan'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            fromOnboarding ? 'Get Started' : 'Add Family',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Footer ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  'First year free. No charge until your family earns £100 together.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
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
