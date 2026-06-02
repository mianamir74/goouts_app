import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Send OTP to a UK mobile number (e.g. +447911123456)
  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function() onAutoVerified,
    required void Function(String message) onError,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
        onAutoVerified();
      },
      verificationFailed: (FirebaseAuthException e) {
        onError(e.message ?? 'Failed to send OTP. Please try again.');
      },
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId, resendToken);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
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
  }

  /// Current signed-in user
  User? get currentUser => _auth.currentUser;

  /// Sign out
  Future<void> signOut() => _auth.signOut();

  /// Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
