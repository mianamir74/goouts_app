import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/user_service.dart';
import '../services/biometric_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();

    // Auth gate — check login state after animation starts
    Future.delayed(const Duration(milliseconds: 1200), () async {
      if (!mounted) return;
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Already logged in
        final exists = await UserService().userProfileExists();
        if (!mounted) return;
        if (exists) {
          // Check if user completed onboarding (link card, bonus screen, etc.)
          final profile = await UserService().getCurrentUser();
          if (!mounted) return;
          // null = existing user before this flag was added → treat as done
          // false = explicitly mid-onboarding (new registrations only)
          final onboardingComplete = profile?['onboardingComplete'];
          if (onboardingComplete == false) {
            // Crashed or closed mid-onboarding — resume from safe point
            Navigator.pushReplacementNamed(context, '/registration-success');
          } else {
            // Check biometric lock
            final biometricEnabled = await BiometricService.instance.isEnabled();
            if (!mounted) return;
            if (biometricEnabled) {
              Navigator.pushReplacementNamed(context, '/biometric-lock');
            } else {
              Navigator.pushReplacementNamed(context, '/home');
            }
          }
        } else {
          Navigator.pushReplacementNamed(context, '/create-profile');
        }
      } else {
        // Not logged in — check if they've signed up before
        final prefs = await SharedPreferences.getInstance();
        final hasSignedUp = prefs.getBool('has_signed_up') ?? false;
        if (!mounted) return;
        if (hasSignedUp) {
          // Returning user who logged out → go straight to login
          Navigator.pushReplacementNamed(context, '/login');
        }
        // Brand new user → stays on splash, taps "Ready for Takeoff"
      }
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Color(0xFF0392CA),
              Color(0xFF0392CA),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Diagonal light streaks
            CustomPaint(
              size: Size(MediaQuery.of(context).size.width,
                  MediaQuery.of(context).size.height),
              painter: _DiagonalStreaksPainter(),
            ),
            // Decorative bars - right side
            Positioned(
              right: 16,
              bottom: 120,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _bar(48),
                  const SizedBox(height: 6),
                  _bar(32),
                  const SizedBox(height: 6),
                  _bar(20),
                ],
              ),
            ),
            // Main content
            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  // Glass card
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: ScaleTransition(
                      scale: _pulseAnim,
                      child: SlideTransition(
                      position: _slideAnim,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 52),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 22),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.22),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Logo
                              Image.asset(
                                'assets/images/goouts_logo_white.png',
                                height: 160,
                                width: 160,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                                errorBuilder: (context, error, stack) =>
                                    const Icon(
                                  Icons.cloud_outlined,
                                  size: 100,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'GoOuts',
                                style: GoogleFonts.inter(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Fueling your urban momentum\nthrough social finance.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.95),
                                  height: 1.55,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  ),
                  const SizedBox(height: 28),
                  // Shop || Earn tagline
                  Text(
                    'SHOP || EARN || REDEEM || SHARE',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'INSTANT CASHBACK POINTS',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.90),
                      letterSpacing: 2.0,
                    ),
                  ),
                  const Spacer(flex: 2),
                  // 3 dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _dot(false),
                      const SizedBox(width: 8),
                      _dot(true),
                      const SizedBox(width: 8),
                      _dot(false),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Ready for Takeoff button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pushReplacementNamed(
                            context, '/slide1'),
                        icon: const Icon(Icons.bolt_rounded,
                            color: Colors.white, size: 20),
                        label: Text(
                          'READY FOR TAKEOFF',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            letterSpacing: 1.8,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.55),
                              width: 1.5),
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ── Already have an account link ──────────────────────────
                  TextButton(
                    onPressed: () =>
                        Navigator.pushReplacementNamed(context, '/login'),
                    child: RichText(
                      text: TextSpan(
                        text: 'Already have an account? ',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                        children: [
                          TextSpan(
                            text: 'Sign In',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(bool active) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: active ? 14 : 8,
        height: 8,
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.white.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(4),
        ),
      );

  Widget _bar(double height) => Container(
        width: 4,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(2),
        ),
      );
}

class _DiagonalStreaksPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // --- Wave bands (thick diagonal streaks) ---
    final bandPaint = Paint()..style = PaintingStyle.stroke;

    final bands = [
      // [startX%, startY%, endX%, endY%, controlX%, controlY%, width, opacity]
      [0.6, 0.0, -0.1, 0.7, 0.55, 0.35, 60.0, 0.06],
      [0.65, 0.0, -0.05, 0.75, 0.60, 0.38, 30.0, 0.09],
      [0.70, 0.0, 0.0, 0.80, 0.65, 0.40, 12.0, 0.15],
      [0.75, 0.0, 0.05, 0.85, 0.70, 0.42, 5.0, 0.20],
      [0.80, 0.0, 0.10, 0.90, 0.75, 0.45, 2.5, 0.12],
    ];

    for (final b in bands) {
      final path = Path();
      path.moveTo(w * b[0], h * b[1]);
      path.quadraticBezierTo(w * b[4], h * b[5], w * b[2], h * b[3]);
      bandPaint
        ..color = Colors.white.withValues(alpha: b[7])
        ..strokeWidth = b[6];
      canvas.drawPath(path, bandPaint);
    }

    // --- Bubble dots scattered across screen ---
    final bubblePaint = Paint()..style = PaintingStyle.fill;

    final bubbles = [
      // [x%, y%, radius, opacity]
      [0.08, 0.05, 18.0, 0.10],
      [0.22, 0.12, 12.0, 0.08],
      [0.55, 0.08, 22.0, 0.09],
      [0.80, 0.15, 14.0, 0.10],
      [0.92, 0.04, 10.0, 0.07],
      [0.05, 0.25, 10.0, 0.08],
      [0.35, 0.22, 16.0, 0.07],
      [0.68, 0.28, 12.0, 0.09],
      [0.88, 0.32, 18.0, 0.08],
      [0.15, 0.42, 14.0, 0.07],
      [0.48, 0.38, 10.0, 0.10],
      [0.78, 0.45, 16.0, 0.08],
      [0.92, 0.50, 10.0, 0.07],
      [0.05, 0.55, 20.0, 0.08],
      [0.28, 0.58, 12.0, 0.09],
      [0.60, 0.55, 18.0, 0.07],
      [0.82, 0.62, 12.0, 0.10],
      [0.12, 0.70, 10.0, 0.08],
      [0.42, 0.72, 16.0, 0.07],
      [0.70, 0.75, 10.0, 0.09],
      [0.90, 0.78, 18.0, 0.08],
      [0.20, 0.85, 14.0, 0.07],
      [0.55, 0.88, 12.0, 0.09],
      [0.78, 0.92, 10.0, 0.08],
      [0.35, 0.95, 16.0, 0.07],
    ];

    for (final b in bubbles) {
      bubblePaint.color = Colors.white.withValues(alpha: b[3]);
      canvas.drawCircle(Offset(w * b[0], h * b[1]), b[2], bubblePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
