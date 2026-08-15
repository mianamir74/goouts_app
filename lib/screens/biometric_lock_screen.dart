import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import '../services/biometric_service.dart';

class BiometricLockScreen extends StatefulWidget {
  /// Route to push after successful authentication.
  final String nextRoute;
  final Object? nextArguments;

  const BiometricLockScreen({
    super.key,
    required this.nextRoute,
    this.nextArguments,
  });

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  static const Color _blue = Color(0xFF0392CA);

  bool _isAuthenticating = false;
  String? _errorMsg;
  List<BiometricType> _types = [];

  @override
  void initState() {
    super.initState();
    _loadTypes();
    // Auto-prompt on open
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  Future<void> _loadTypes() async {
    final t = await BiometricService.instance.availableTypes();
    if (mounted) setState(() => _types = t);
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;
    setState(() { _isAuthenticating = true; _errorMsg = null; });

    final ok = await BiometricService.instance.authenticate(
      reason: 'Use biometrics to access your GoOuts account',
    );

    if (!mounted) return;
    if (ok) {
      Navigator.pushReplacementNamed(
        context,
        widget.nextRoute,
        arguments: widget.nextArguments,
      );
    } else {
      setState(() {
        _isAuthenticating = false;
        _errorMsg = 'Authentication failed. Please try again.';
      });
    }
  }

  bool get _hasFace => _types.contains(BiometricType.face);
  // Suppressed 14 August 2026, not deleted.
  // Pairs with _hasFace above, which IS used. Kept so the capability set reads
  // as a whole — a device with strong biometrics but no face unlock is a case
  // this screen will need.
  // ignore: unused_element
  bool get _hasStrong => _types.contains(BiometricType.strong);

  IconData get _biometricIcon =>
      _hasFace ? Icons.face_rounded : Icons.fingerprint_rounded;

  String get _biometricLabel =>
      _hasFace ? 'Face ID' : 'Fingerprint';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B3E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(),

              // Logo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(Icons.lock_rounded, color: _blue, size: 38),
              ),

              const SizedBox(height: 24),

              Text(
                'GoOuts',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Verify your identity to continue',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 56),

              // Biometric button
              GestureDetector(
                onTap: _isAuthenticating ? null : _authenticate,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: _isAuthenticating
                        ? _blue.withValues(alpha: 0.3)
                        : _blue.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isAuthenticating
                          ? _blue
                          : _blue.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                  child: _isAuthenticating
                      ? const Center(
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(
                              color: Color(0xFF0392CA),
                              strokeWidth: 2.5,
                            ),
                          ),
                        )
                      : Icon(
                          _biometricIcon,
                          color: _blue,
                          size: 48,
                        ),
                ),
              ),

              const SizedBox(height: 20),

              Text(
                _isAuthenticating
                    ? 'Verifying...'
                    : 'Tap to use $_biometricLabel',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),

              if (_errorMsg != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _errorMsg!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.red[300],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              const Spacer(),

              // Use PIN instead link
              TextButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                child: Text(
                  'Use PIN instead',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
