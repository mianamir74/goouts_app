import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../widgets/pre_auth_support_sheet.dart';
import '../widgets/goouts_sheet.dart';
import '../widgets/goouts_loading_overlay.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _phoneController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  String? _termsFromDb;

  static const Color _primary = Color(0xFF0392CA);

  @override
  void initState() {
    super.initState();
    _loadTerms();
  }

  Future<void> _loadTerms() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('content_pages')
          .doc('terms_conditions')
          .get();
      final content = doc.data()?['content'] as String?;
      if (content != null && content.trim().isNotEmpty && mounted) {
        setState(() => _termsFromDb = content);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final number = _phoneController.text.trim();
    if (number.length < 10) {
      GoOutsSheet.warning(context,
        title: 'Invalid Number',
        message: 'Please enter a valid UK mobile number.',
      );
      return;
    }
    final fullPhone =
        '+44${number.startsWith('0') ? number.substring(1) : number}';

    setState(() => _isLoading = true);

    await _authService.sendOtp(
      phoneNumber: fullPhone,
      onCodeSent: (verificationId, resendToken) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        Navigator.pushNamed(context, '/otp', arguments: {
          'phone': fullPhone,
          'verificationId': verificationId,
          'resendToken': resendToken,
        });
      },
      onAutoVerified: () {
        if (!mounted) return;
        setState(() => _isLoading = false);
        Navigator.pushReplacementNamed(context, '/create-profile');
      },
      onError: (message) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        GoOutsSheet.error(context, title: 'Sign Up Failed', message: message);
      },
    );
  }

  void _showTerms(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: kIsWeb && MediaQuery.of(context).size.width >= 900
          ? const BoxConstraints(maxWidth: 640)
          : null,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Terms of Service',
                        style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0D1B3E))),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.black54, size: 24),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Text(
                  _termsFromDb ?? '''Last updated: June 2026

Welcome to GoOuts. By accessing or using the GoOuts application and services, you agree to be bound by these Terms of Service. Please read them carefully before proceeding.

1. ACCEPTANCE OF TERMS
By creating an account or using the GoOuts platform, you confirm that you are at least 16 years of age (18 for financial features), a UK resident, and that you accept these Terms of Service in full.

2. DESCRIPTION OF SERVICE
GoOuts is a cashback rewards and social finance platform that allows users to earn, collect, and redeem cashback at participating partner merchants across the United Kingdom. GoOuts operates a virtual debit card linked to your GoOuts wallet.

3. ACCOUNT REGISTRATION
You must provide accurate and complete information when registering. You are responsible for maintaining the confidentiality of your account credentials. You must notify GoOuts immediately of any unauthorised access to your account.

4. CASHBACK REWARDS
Cashback is awarded at the discretion of GoOuts and participating merchants and is subject to transaction verification via GPS proximity and QR code authentication.

5. VIRTUAL DEBIT CARD
The GoOuts Virtual Debit Card is issued subject to eligibility and identity verification (KYC). Card usage is subject to applicable spending limits and UK financial regulations.

6. PAYMENT SERVICES & TECHNICAL SERVICE PROVIDER STATUS
GoOuts Limited is a technology platform provider and does not hold, process, store, or control any user funds at any time. Your GoOuts Wallet is powered by Stripe. Funds you add are held in a Stripe account in your name. GoOuts does not hold your money. Stripe Payments Europe Ltd (FCA ref: 900461) is the authorised payment institution. All payment processing, card issuance, and fund management services are provided exclusively by our regulated third-party financial services partner(s), who are authorised and regulated by the Financial Conduct Authority (FCA) as Electronic Money Institutions under the UK Electronic Money Regulations 2011. Your funds are held by our regulated partner(s) and subject to their safeguarding obligations. Payment providers may be updated from time to time; any change will be notified to you in advance. GoOuts Limited accepts no liability for any act, omission, or failure of our regulated payment partner(s). GoOuts Limited operates solely as a technical service provider under Schedule 1, Part 2(j) of the UK Payment Services Regulations 2017.

7. USER CONDUCT
You agree not to use GoOuts for any unlawful purpose. Misuse of the platform will result in immediate account suspension.

8. PRIVACY & DATA
GoOuts collects and processes your personal data in accordance with our Privacy Policy and the UK GDPR. We do not sell your personal data to third parties.

9. LIMITATION OF LIABILITY
GoOuts shall not be liable for any indirect, incidental, or consequential damages arising from the use of our services. Our total aggregate liability shall not exceed the total Cashback credited to your account in the twelve months preceding any claim.

10. GOVERNING LAW
These Terms of Service are governed by the laws of England and Wales.

For questions: legal@goouts.co.uk''',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: Colors.grey[700], height: 1.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ⚠ ADDED 9 September 2026, found in a web audit. Signing up ends at
  // /create-profile, which is required-under-UK-AML-regulations KYC: a
  // profile photo and ID document, both picked via image_picker and then
  // rendered with Image.file(...) (create_profile_screen.dart). Image.file
  // throws UnimplementedError the moment it is built on web — there is no
  // web implementation of it at all. Same gap, same fix, as
  // goouts_host/lib/features/auth/signup_screen.dart: new sign-up stays
  // phone-only; signing IN (phone OTP only, no camera) keeps working here.
  //
  // ⚠ MOBILE-WIDTH VERSION. Kept exactly as before — full-width blue
  // single-column layout — for narrow web viewports (phones/tablets
  // browsing the web build). See _desktopWebNotSupported below for the
  // >=900px split-panel version added 11 September 2026, matching the
  // desktop treatment already given to login/food/stay pages.
  Widget _webNotSupported(BuildContext context) {
    return Scaffold(
      backgroundColor: _primary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(Icons.phone_iphone, color: Colors.white, size: 48),
              const SizedBox(height: 20),
              Text('Create your account on the app',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  )),
              const SizedBox(height: 12),
              Text(
                'Signing up needs a quick ID check, which only works in the '
                'GoOuts app on your phone. Once you are set up, come back '
                'here to book and order any time.',
                style: GoogleFonts.inter(fontSize: 15, color: Colors.white70),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                  ),
                  child: const Text('Already have an account? Sign in'),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: GestureDetector(
                  onTap: () => showPreAuthSupportSheet(context),
                  child: Text(
                    'Having trouble? Get help',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white70,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white54,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ⚠ ADDED 11 September 2026, requested directly — "still showing old web
  // app style need to change as well like we already worked out on food
  // and stay pages". Mirrors login_screen.dart's _desktopBody split-panel
  // pattern (brand panel left, content panel right) so the honest
  // phone-only message reads as a real product page rather than a
  // stretched mobile screen. The phone-only KYC constraint itself is
  // UNCHANGED — this is presentation only, per the note above.
  Widget _desktopWebNotSupported(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          Expanded(
            flex: 5,
            child: Container(
              color: _primary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 56, vertical: 48),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('GoOuts',
                          style: GoogleFonts.inter(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          )),
                      const SizedBox(height: 28),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          'assets/images/signup_hero.webp',
                          height: 320,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (context, error, stack) => Container(
                            height: 320,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFF026899),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Icon(Icons.local_cafe_rounded,
                                size: 60, color: Colors.white38),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text('Join GoOuts',
                          style: GoogleFonts.inter(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.15,
                          )),
                      const SizedBox(height: 12),
                      Text(
                        'Order food, book places to stay, and earn cashback '
                        'every time you do.',
                        style: GoogleFonts.inter(
                            fontSize: 15, color: Colors.white.withValues(alpha: 0.85)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Container(
              color: Colors.white,
              child: Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.phone_iphone, color: _primary, size: 40),
                        const SizedBox(height: 20),
                        Text('Create your account on the app',
                            style: GoogleFonts.inter(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0D1B3E),
                            )),
                        const SizedBox(height: 10),
                        Text(
                          'Signing up needs a quick ID check, which only '
                          'works in the GoOuts app on your phone. Download '
                          'the app, create your account there in a couple '
                          'of minutes, then come back here any time to book '
                          'and order from your browser.',
                          style: GoogleFonts.inter(
                              fontSize: 14.5, color: Colors.grey[700], height: 1.5),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text('Get the GoOuts app',
                                style: GoogleFonts.inter(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _primary,
                              side: BorderSide(color: _primary),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () =>
                                Navigator.of(context).pushReplacement(
                              MaterialPageRoute<void>(
                                  builder: (_) => const LoginScreen()),
                            ),
                            child: const Text('Already have an account? Sign in'),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: GestureDetector(
                            onTap: () => showPreAuthSupportSheet(context),
                            child: Text(
                              'Having trouble? Get help',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.grey[600],
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ⚠ WEB BLOCK REMOVED 13 September 2026. Signing up used to dead-end
    // here on web with "Create your account on the app", because the two
    // screens further down this flow - create_profile_screen.dart and
    // kyc_screen.dart - were dart:io File-based and would crash the moment
    // Image.file(...) built on web. Both are now bytes-based / have a
    // web-safe flow (see those files), so the real phone-entry form below
    // is safe to render on web too. _webNotSupported / _desktopWebNotSupported
    // are left defined below, unused, rather than deleted - they were a
    // correct, deliberate fix for a real crash at the time, and the next
    // person touching this file should be able to see what stood here and
    // why, not just that it is gone.
    //
    // ⚠ DESKTOP LAYOUT ADDED 14 September 2026. Removing the block above got
    // the real form onto the web build, but this screen still only had the
    // original mobile-app layout - full-bleed blue, everything stretched
    // edge to edge - which on an actual desktop window reads as a phone
    // screen someone stretched wide, reported directly ("i do not want any
    // page which is still showing web based"). Every other page reaching
    // the web build already went through this exact fix (see
    // login_screen.dart's _desktopBody, added 10 September 2026) - this one
    // was next. Mobile app behaviour (below 900px, or not web) is
    // _mobileBody(context) below, the untouched original build().
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool desktop = kIsWeb && constraints.maxWidth >= 900;
        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
            backgroundColor: desktop ? Colors.white : _primary,
            body: Stack(
              children: [
                desktop ? _desktopBody(context) : _mobileBody(context),
                if (_isLoading) const GoOutsLoadingOverlay(),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Original mobile/app layout — unchanged ─────────────────────────────────
  Widget _mobileBody(BuildContext context) {
    return SafeArea(
        child: SingleChildScrollView(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 14),

                // Brand Header
                Text(
                  'GoOuts',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 16),

                // Hero Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/images/signup_hero.webp',
                    width: double.infinity,
                    height: 190,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (context, error, stack) => Container(
                      width: double.infinity,
                      height: 190,
                      decoration: BoxDecoration(
                        color: const Color(0xFF026899),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(Icons.local_cafe_rounded,
                          size: 60, color: Colors.white38),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Heading
                Text(
                  'Enter your mobile number',
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),

                const SizedBox(height: 10),

                // Subtext
                Text(
                  "We'll send you a verification code to get you started on your journey.",
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 20),

                // Phone input row
                Row(
                  children: [
                    // UK Flag + +44
                    Container(
                      height: 64,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Text('🇬🇧',
                              style: TextStyle(fontSize: 22)),
                          const SizedBox(width: 8),
                          Text('+44',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              )),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Phone input
                    Expanded(
                      child: Container(
                        height: 64,
                        clipBehavior: Clip.hardEdge,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          maxLength: 11,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                            letterSpacing: 1.2,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: '07xxxxxxxxx',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 18,
                              color: Colors.black38,
                              letterSpacing: 1.2,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            filled: false,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 18),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Terms
                Center(
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      children: [
                        const TextSpan(
                            text: 'By continuing, you agree to our '),
                        TextSpan(
                          text: 'Terms of Service',
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => _showTerms(context),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Continue button
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _continue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            color: _primary, strokeWidth: 2)
                        : Text('Continue',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            )),
                  ),
                ),

                const SizedBox(height: 12),

                // Login footer
                Center(
                  child: GestureDetector(
                    onTap: () =>
                        Navigator.pushReplacementNamed(context, '/login'),
                    child: RichText(
                      text: TextSpan(
                        style: GoogleFonts.inter(
                            fontSize: 16, color: Colors.white),
                        children: [
                          const TextSpan(text: 'Already have an account? '),
                          TextSpan(
                            text: 'Login',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                // Pre-auth support link
                Center(
                  child: GestureDetector(
                    onTap: () => showPreAuthSupportSheet(context),
                    child: Text(
                      'Having trouble? Get help',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white70,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white54,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
    );
  }

  // ── Desktop web layout — split panel, mirrors login_screen.dart's
  // _desktopBody so the two pages feel like one product ───────────────────
  Widget _desktopBody(BuildContext context) {
    return Row(
      children: [
        // Left brand panel
        Expanded(
          flex: 5,
          child: Container(
            color: _primary,
            padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 48),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('GoOuts',
                        style: GoogleFonts.inter(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5)),
                    const SizedBox(height: 28),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        'assets/images/signup_hero.webp',
                        width: double.infinity,
                        height: 320,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (context, error, stack) => Container(
                          width: double.infinity,
                          height: 320,
                          decoration: BoxDecoration(
                            color: const Color(0xFF026899),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(Icons.local_cafe_rounded,
                              size: 60, color: Colors.white38),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text('Join GoOuts',
                        style: GoogleFonts.inter(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.15)),
                    const SizedBox(height: 12),
                    Text(
                      'Order food, book places to stay, and earn cashback '
                      'every time you do.',
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          color: Colors.white.withValues(alpha: 0.85),
                          height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Right form panel — the same _phoneController / _continue /
        // _showTerms the mobile body above uses, just laid out for a wide
        // screen instead of a narrow one.
        Expanded(
          flex: 4,
          child: Container(
            color: Colors.white,
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Create your account',
                          style: GoogleFonts.inter(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0D1B3E))),
                      const SizedBox(height: 6),
                      Text(
                          "Enter your mobile number and we'll send you a "
                          "verification code.",
                          style: GoogleFonts.inter(
                              fontSize: 14, color: Colors.grey[600])),
                      const SizedBox(height: 32),
                      Text('MOBILE NUMBER',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600],
                              letterSpacing: 1.0)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            height: 52,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F6FA),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('🇬🇧', style: TextStyle(fontSize: 16)),
                                const SizedBox(width: 6),
                                Text('+44',
                                    style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF0D1B3E))),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              height: 52,
                              clipBehavior: Clip.hardEdge,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F6FA),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                maxLength: 11,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                style: GoogleFonts.inter(
                                    fontSize: 15, color: const Color(0xFF0D1B3E)),
                                decoration: InputDecoration(
                                  counterText: '',
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                  filled: false,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 14),
                                  hintText: '07xxxxxxxxx',
                                  hintStyle: GoogleFonts.inter(
                                      fontSize: 15, color: Colors.grey[400]),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      RichText(
                        text: TextSpan(
                          style: GoogleFonts.inter(
                              fontSize: 12.5, color: Colors.grey[600]),
                          children: [
                            const TextSpan(
                                text: 'By continuing, you agree to our '),
                            TextSpan(
                              text: 'Terms of Service',
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => _showTerms(context),
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: _primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            const TextSpan(text: '.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _continue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5))
                              : Text('Continue',
                                  style: GoogleFonts.inter(
                                      fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: GestureDetector(
                          onTap: () => Navigator.pushReplacementNamed(
                              context, '/login'),
                          child: RichText(
                            text: TextSpan(
                              style: GoogleFonts.inter(
                                  fontSize: 14, color: Colors.grey[700]),
                              children: [
                                const TextSpan(
                                    text: 'Already have an account? '),
                                TextSpan(
                                  text: 'Login',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    color: _primary,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: GestureDetector(
                          onTap: () => showPreAuthSupportSheet(context),
                          child: Text(
                            'Having trouble? Get help',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.grey[600],
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
