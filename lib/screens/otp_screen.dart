import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../utils/pin_hasher.dart';
import '../widgets/goouts_sheet.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen>
    with SingleTickerProviderStateMixin {
  // ── Brand colours ──────────────────────────────────────────────────────────
  static const Color _primary = Color(0xFF0392CA);
  static const Color _dark = Color(0xFF0D1B3E);
  static const Color _errorRed = Color(0xFFD32F2F);

  // ── OTP fields ─────────────────────────────────────────────────────────────
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  // CRITICAL FIX: separate FocusNodes for the KeyboardListener wrappers.
  // A FocusNode can only be attached to one widget at a time. Previously
  // _focusNodes[index] was passed to BOTH the KeyboardListener and the
  // TextField it wraps, so the two fought over attaching the same node in
  // the focus tree — each reattach fired a notification, rebuilt, and
  // reattached again, unbounded. With 6 boxes built at once this allocated
  // GBs within seconds and got the app killed by iOS as out-of-memory (an
  // uncatchable kernel SIGKILL — no try/catch or timeout can stop it).
  // This is the same bug that crashed driver_app's OTP flow.
  // skipTraversal keeps these out of tab order so they never steal focus.
  final List<FocusNode> _keyEventFocusNodes =
      List.generate(6, (_) => FocusNode(skipTraversal: true));

  // ── State ──────────────────────────────────────────────────────────────────
  bool _isLoading = false;
  bool _canResend = false;
  bool _hasError = false;
  int _secondsLeft = 60;
  Timer? _timer;
  final _authService = AuthService();

  // ── Route args ─────────────────────────────────────────────────────────────
  String _verificationId = '';
  String _phone = '';
  int? _resendToken;
  String _mode = 'signup'; // 'signup' or 'login'
  String _enteredPin = ''; // PIN passed from login screen

  // ── Shake animation ────────────────────────────────────────────────────────
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _startTimer();

    // Auto-focus first box so keyboard opens immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[0].requestFocus();
    });

    // Shake animation setup
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -12), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12, end: 12), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 12, end: -8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _verificationId = args['verificationId'] ?? '';
      _phone = args['phone'] ?? '';
      _resendToken = args['resendToken'] as int?;
      _mode = args['mode'] ?? 'signup';
      _enteredPin = args['pin'] ?? '';
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shakeCtrl.dispose();
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    for (final f in _keyEventFocusNodes) f.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Timer
  // ─────────────────────────────────────────────────────────────────────────
  void _startTimer() {
    _secondsLeft = 60;
    _canResend = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        if (mounted) setState(() => _canResend = true);
      } else {
        if (mounted) setState(() => _secondsLeft--);
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Input handling
  // ─────────────────────────────────────────────────────────────────────────
  void _onChanged(String value, int index) {
    if (_hasError) setState(() => _hasError = false);

    if (value.length == 6) {
      // Full paste OR iOS autofill into box 0 — distribute across all boxes
      _fillFromString(value);
      return;
    }

    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }

    setState(() {});

    if (index == 5 && value.isNotEmpty && _isComplete) {
      Future.delayed(const Duration(milliseconds: 100), _verify);
    }
  }

  void _fillFromString(String code) {
    final digits = code.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 6) return;
    for (int i = 0; i < 6; i++) {
      _controllers[i].text = digits[i];
    }
    _focusNodes[5].requestFocus();
    setState(() {});
    Future.delayed(const Duration(milliseconds: 150), _verify);
  }

  void _onKeyEvent(KeyEvent event, int index) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
      setState(() {});
    }
  }

  String get _otp => _controllers.map((c) => c.text).join();
  bool get _isComplete => _otp.length == 6;

  // ─────────────────────────────────────────────────────────────────────────
  // Resend OTP
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _resendOtp() async {
    if (_phone.isEmpty) return;
    _startTimer();
    await _authService.resendOtp(
      phoneNumber: _phone,
      resendToken: _resendToken,
      onCodeSent: (newVerificationId, newResendToken) {
        if (!mounted) return;
        setState(() {
          _verificationId = newVerificationId;
          _resendToken = newResendToken;
        });
        GoOutsSheet.success(context,
          title: 'Code Resent',
          message: 'A new verification code has been sent to your phone.',
        );
      },
      onError: (message) {
        if (!mounted) return;
        GoOutsSheet.error(context, title: 'Resend Failed', message: message);
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Verify
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _verify() async {
    if (!_isComplete || _isLoading) return;
    setState(() => _isLoading = true);
    try {
      if (_verificationId.isNotEmpty) {
        final credential = PhoneAuthProvider.credential(
          verificationId: _verificationId,
          smsCode: _otp,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
      }
      if (mounted) {
        if (_mode == 'login') {
          // Login flow: verify PIN against Firestore, then check profile
          final userData = await UserService().getCurrentUser();
          if (!mounted) return;

          if (userData != null && _enteredPin.isNotEmpty) {
            final storedPin = userData['pin'] as String? ?? '';
            final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
            final pinMatches = PinHasher.verify(_enteredPin, storedPin, uid);
            if (!pinMatches) {
              // Wrong PIN — sign out and send back to login
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              setState(() {
                _isLoading = false;
                _hasError = true;
              });
              for (final c in _controllers) c.clear();
              _focusNodes[0].requestFocus();
              _shakeCtrl.forward(from: 0);
              GoOutsSheet.error(context,
                title: 'Incorrect PIN',
                message: 'The PIN you entered is wrong. Please try again.',
              );
              return;
            }
          }

          // PIN correct (or no PIN stored yet) — check profile exists
          final exists = userData != null;
          // Refresh has_signed_up so splash knows this is a returning user
          // even if app cache was cleared
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('has_signed_up', true);
          if (!mounted) return;
          if (exists) {
            Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
          } else {
            Navigator.pushReplacementNamed(context, '/create-profile');
          }
        } else {
          // Signup flow: always go to create profile
          Navigator.pushReplacementNamed(context, '/create-profile');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
        // Clear boxes and shake
        for (final c in _controllers) c.clear();
        _focusNodes[0].requestFocus();
        _shakeCtrl.forward(from: 0);
      }
    } finally {
      if (mounted && !_hasError) setState(() => _isLoading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F4F7),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.black87, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Verify OTP',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _primary,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // ── Compact logo ───────────────────────────────────────────
              Image.asset(
                'assets/images/goouts_logo_blue.webp',
                height: 72,
                width: 72,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stack) => Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F4FB),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.lock_rounded,
                      size: 36, color: _primary),
                ),
              ),

              const SizedBox(height: 20),

              // ── Title ──────────────────────────────────────────────────
              Text(
                'Check Your Messages',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),

              const SizedBox(height: 8),

              // ── Subtitle ───────────────────────────────────────────────
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  text: 'We sent a 6-digit code to\n',
                  style: GoogleFonts.inter(
                      fontSize: 14, color: Colors.grey[600], height: 1.5),
                  children: [
                    TextSpan(
                      text: _phone,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── OTP boxes with shake ───────────────────────────────────
              AutofillGroup(
                child: AnimatedBuilder(
                animation: _shakeAnim,
                builder: (context, child) => Transform.translate(
                  offset: Offset(_shakeAnim.value, 0),
                  child: child,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (index) {
                    final filled = _controllers[index].text.isNotEmpty;
                    return SizedBox(
                      width: 48,
                      height: 56,
                      child: KeyboardListener(
                        focusNode: _keyEventFocusNodes[index],
                        onKeyEvent: (event) => _onKeyEvent(event, index),
                        child: TextField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          autofillHints: index == 0
                              ? const [AutofillHints.oneTimeCode]
                              : null,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          // box 0 accepts 6 chars so iOS autofill can insert full code
                          // _onChanged immediately distributes to all 6 boxes
                          maxLength: index == 0 ? 6 : 1,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (v) => _onChanged(v, index),
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: _hasError ? _errorRed : _dark,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            contentPadding: EdgeInsets.zero,
                            hintText: '·',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 28,
                              color: Colors.grey[300],
                            ),
                            filled: true,
                            // Light blue fill when digit entered, red tint on error
                            fillColor: _hasError
                                ? _errorRed.withOpacity(0.06)
                                : filled
                                    ? const Color(0xFFE8F4FB)
                                    : Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: Colors.grey[300]!, width: 1.5),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _hasError
                                    ? _errorRed
                                    : filled
                                        ? _primary
                                        : Colors.grey[300]!,
                                width: _hasError || filled ? 2 : 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _hasError ? _errorRed : _primary,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              ), // AutofillGroup

              const SizedBox(height: 14),

              // ── Error message ──────────────────────────────────────────
              AnimatedOpacity(
                opacity: _hasError ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: _errorRed, size: 14),
                    const SizedBox(width: 5),
                    Text(
                      'Incorrect code. Please try again.',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: _errorRed,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Resend row ─────────────────────────────────────────────
              Center(
                child: GestureDetector(
                  onTap: _canResend ? _resendOtp : null,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Didn't receive?  ",
                        style: GoogleFonts.inter(
                            fontSize: 13, color: Colors.grey[600]),
                      ),
                      Text(
                        _canResend
                            ? 'Resend'
                            : 'Resend (${_secondsLeft}s)',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _canResend ? _primary : Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // ── Verify button ──────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: (_isComplete && !_isLoading) ? _verify : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    disabledBackgroundColor: _primary.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Verify Code',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Secure verification badge ──────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shield_outlined,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'SECURE VERIFICATION',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[500],
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}
