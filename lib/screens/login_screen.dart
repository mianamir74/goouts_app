import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../widgets/pre_auth_support_sheet.dart';
import '../widgets/goouts_sheet.dart';
import '../widgets/goouts_loading_overlay.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isPinVisible = false;
  bool _isLoading = false;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final _authService = AuthService();

  static const Color _primary = Color(0xFF0392CA);
  static const Color _navy = Color(0xFF0D1B3E);

  @override
  void dispose() {
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _showForgotPinSheet() {
    final phoneCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: kIsWeb && MediaQuery.of(context).size.width >= 900
          ? const BoxConstraints(maxWidth: 560)
          : null,
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F4FB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.lock_reset_rounded,
                        color: _primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Forgot PIN?',
                          style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0D1B3E))),
                      Text('We\'ll send a reset code to your number.',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: Colors.grey[500])),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('MOBILE NUMBER',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                      letterSpacing: 1.0)),
              const SizedBox(height: 8),
              Container(
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F6FA),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    const Icon(Icons.flag_rounded, size: 18, color: _primary),
                    const SizedBox(width: 6),
                    Text('+44',
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0D1B3E))),
                    const SizedBox(width: 10),
                    Container(width: 1, height: 24, color: Colors.grey[300]),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        autofocus: true,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          filled: false,
                          hintText: '07xxxxxxxxx',
                          hintStyle: GoogleFonts.inter(
                              color: Colors.grey[400], fontSize: 16),
                        ),
                        style: GoogleFonts.inter(
                            fontSize: 16, color: const Color(0xFF0D1B3E)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    final num = phoneCtrl.text.trim();
                    if (num.length < 10) {
                      GoOutsSheet.warning(context,
                        title: 'Invalid Number',
                        message: 'Please enter a valid UK mobile number.',
                      );
                      return;
                    }
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/otp');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Send Reset Code',
                      style: GoogleFonts.inter(
                          fontSize: 16,
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

  Future<void> _login() async {
    final number = _phoneController.text.trim();
    final pin = _pinController.text.trim();
    if (number.length < 10) {
      GoOutsSheet.warning(context,
        title: 'Invalid Number',
        message: 'Please enter a valid UK mobile number.',
      );
      return;
    }
    if (pin.length < 4) {
      GoOutsSheet.warning(context,
        title: 'PIN Required',
        message: 'Please enter your 4-digit PIN.',
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
          'mode': 'login',
          'pin': pin,
        });
      },
      onAutoVerified: () {
        if (!mounted) return;
        setState(() => _isLoading = false);
        Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
      },
      onError: (message) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        GoOutsSheet.error(context,
          title: 'Login Failed',
          message: message,
        );
      },
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────
  //
  // ⚠ ADDED 10 September 2026. This screen only ever had its original
  // mobile-app layout (full-bleed blue background, everything stretched
  // edge to edge) — every OTHER page that reaches the web build went
  // through a "professional desktop redesign" pass (see food_delivery_
  // screen.dart, 01_short_stay_home_screen.dart) that adds a LayoutBuilder
  // + kIsWeb branch for a proper desktop layout above ~900px. This one was
  // missed, so on the web build it just showed the phone UI stretched full
  // width — reported as "still using the old format". Mobile app behaviour
  // (below 900px, or not web) is completely untouched: _mobileBody() is the
  // exact original build() body, unchanged.
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool desktop = kIsWeb && constraints.maxWidth >= 900;
        return Scaffold(
          backgroundColor: desktop ? Colors.white : _primary,
          body: Stack(
            children: [
              desktop ? _desktopBody(context) : _mobileBody(context),
              if (_isLoading) const GoOutsLoadingOverlay(),
            ],
          ),
        );
      },
    );
  }

  // ── Original mobile/app layout — unchanged ─────────────────────────────────
  Widget _mobileBody(BuildContext context) {
    const Color inputBackgroundColor = Color(0x33FFFFFF);
    const Color textColor = Colors.white;

    return SafeArea(
        child: SingleChildScrollView(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 14),

                // Brand Header - Centered
                Center(
                  child: Text(
                    'GoOuts',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      letterSpacing: -0.5,
                    ),
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

                // Welcome Section
                Text(
                  'Welcome Back!',
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Welcome back to GoOuts.',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: textColor.withValues(alpha: 0.9),
                  ),
                ),

                const SizedBox(height: 20),

                // Mobile Number Label
                Text(
                  'MOBILE NUMBER',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 12),

                // Mobile Input Field Row
                Row(
                  children: [
                    // UK Flag + +44
                    Container(
                      height: 60,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: inputBackgroundColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: textColor.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.flag_rounded, size: 20, color: textColor),
                          const SizedBox(width: 8),
                          Text(
                            '+44',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Phone Number Input
                    Expanded(
                      child: Container(
                        height: 60,
                        clipBehavior: Clip.hardEdge,
                        decoration: BoxDecoration(
                          color: inputBackgroundColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: textColor.withValues(alpha: 0.2)),
                        ),
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          maxLength: 11,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          style: GoogleFonts.inter(
                            color: Colors.black,
                            fontSize: 18,
                            letterSpacing: 1.2,
                          ),
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
                                horizontal: 20, vertical: 18),
                            hintText: '07xxxxxxxxx',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 18,
                              color: Colors.black38,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // PIN Number Label
                Text(
                  'PIN NUMBER',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 12),

                // PIN Input Field
                Container(
                  height: 60,
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    color: inputBackgroundColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: textColor.withValues(alpha: 0.2)),
                  ),
                  child: TextField(
                    controller: _pinController,
                    obscureText: !_isPinVisible,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    style: GoogleFonts.inter(
                      color: Colors.black,
                      fontSize: 18,
                      letterSpacing: 4.0,
                    ),
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
                          horizontal: 20, vertical: 18),
                      hintText: '••••',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 18,
                        color: Colors.black38,
                        letterSpacing: 4.0,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPinVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: _primary,
                          size: 22,
                        ),
                        onPressed: () =>
                            setState(() => _isPinVisible = !_isPinVisible),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Login Button
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: _primary),
                          )
                        : Text(
                      'Login',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Forgot PIN
                Center(
                  child: GestureDetector(
                    onTap: () => _showForgotPinSheet(),
                    child: Text(
                      'Forgot PIN?',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Signup Footer
                Center(
                  child: GestureDetector(
                    onTap: () =>
                        Navigator.pushReplacementNamed(context, '/signup'),
                    child: RichText(
                      text: TextSpan(
                        style:
                            GoogleFonts.inter(fontSize: 16, color: textColor),
                        children: [
                          const TextSpan(text: "Don't have an account? "),
                          TextSpan(
                            text: 'Sign Up',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              color: textColor,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
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

  // ── Desktop web layout ──────────────────────────────────────────────────────
  // Split screen: brand/photo panel on the left (primary colour, matches the
  // mobile app's identity), a plain white card with the same form on the
  // right — the standard pattern for a booking-site sign-in page, instead of
  // the phone screen stretched edge to edge across a wide browser window.
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
                    Text('Welcome back',
                        style: GoogleFonts.inter(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.15)),
                    const SizedBox(height: 12),
                    Text(
                      'Sign in to order food, book a stay, and pick up '
                      'where you left off with your GoOuts cashback.',
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
        // Right form panel
        Expanded(
          flex: 4,
          child: Container(
            color: Colors.white,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Sign in',
                          style: GoogleFonts.inter(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: _navy)),
                      const SizedBox(height: 6),
                      Text('Enter your mobile number and PIN to continue.',
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
                                const Icon(Icons.flag_rounded,
                                    size: 16, color: _primary),
                                const SizedBox(width: 6),
                                Text('+44',
                                    style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: _navy)),
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
                                    fontSize: 15, color: _navy),
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
                      Text('PIN NUMBER',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600],
                              letterSpacing: 1.0)),
                      const SizedBox(height: 8),
                      Container(
                        height: 52,
                        clipBehavior: Clip.hardEdge,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F6FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: TextField(
                          controller: _pinController,
                          obscureText: !_isPinVisible,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          style: GoogleFonts.inter(
                              fontSize: 15, color: _navy, letterSpacing: 4.0),
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
                            hintText: '••••',
                            hintStyle: GoogleFonts.inter(
                                fontSize: 15,
                                color: Colors.grey[400],
                                letterSpacing: 4.0),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPinVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: _primary,
                                size: 20,
                              ),
                              onPressed: () => setState(
                                  () => _isPinVisible = !_isPinVisible),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () => _showForgotPinSheet(),
                          child: Text('Forgot PIN?',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _primary)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5, color: Colors.white),
                                )
                              : Text('Login',
                                  style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: GestureDetector(
                          onTap: () => Navigator.pushReplacementNamed(
                              context, '/signup'),
                          child: RichText(
                            text: TextSpan(
                              style: GoogleFonts.inter(
                                  fontSize: 14, color: Colors.grey[700]),
                              children: [
                                const TextSpan(text: "Don't have an account? "),
                                TextSpan(
                                  text: 'Sign Up',
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      color: _primary),
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
                          child: Text('Having trouble? Get help',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                  decoration: TextDecoration.underline)),
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
