import 'package:firebase_auth/firebase_auth.dart';
import '../features/short_stay/services/stay_recently_viewed.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Send OTP to a UK mobile number (e.g. +447911123456)
  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function() onAutoVerified,
    required void Function(String message) onError,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await _auth.signInWithCredential(credential);
            onAutoVerified();
          } catch (e) {
            onError('Auto-verification failed. Please enter the code manually.');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(e.message ?? 'Failed to send OTP. Please try again.');
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId, resendToken);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      onError('Could not send verification code. Please check your connection and try again.');
    }
  }

  /// Verify the 6-digit OTP code entered by user
  Future<void> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    await _auth.signInWithCredential(credential);
  }

  /// Resend OTP using the resend token
  Future<void> resendOtp({
    required String phoneNumber,
    required int? resendToken,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String message) onError,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        forceResendingToken: resendToken,
        verificationCompleted: (_) {},
        verificationFailed: (FirebaseAuthException e) {
          onError(e.message ?? 'Failed to resend OTP.');
        },
        codeSent: (String verificationId, int? newResendToken) {
          onCodeSent(verificationId, newResendToken);
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) {
      onError('Could not resend code. Please check your connection and try again.');
    }
  }

  /// Current signed-in user
  User? get currentUser => _auth.currentUser;

  /// Sign out, and drop the device-local traces that belong to the person
  /// leaving rather than to the device.
  ///
  /// ── ⚠ TWO OTHER PLACES SIGN OUT WITHOUT COMING THROUGH HERE ──────────────
  ///
  ///     screens/profile_screen.dart:1466   FirebaseAuth.instance.signOut()
  ///     services/fresh_install_guard.dart  FirebaseAuth.instance.signOut()
  ///
  /// Both bypass this method, so anything added here is added for one of three
  /// exits. That is a pre-existing problem and it is bigger than this line —
  /// it is why "sign out then sign in as someone else" is worth testing on a
  /// shared handset. Flagged 27 August 2026, not fixed here because changing
  /// what the profile screen's sign-out does is its own change with its own
  /// blast radius.
  ///
  /// Clearing is best-effort and never blocks the sign-out itself.
  Future<void> signOut() async {
    try {
      await StayRecentlyViewed.instance.clear();
    } catch (_) {}
    await _auth.signOut();
  }

  /// Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
