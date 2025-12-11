import 'package:firebase_auth/firebase_auth.dart';

typedef CodeSent = void Function(String verificationId, int? resendToken);
typedef VerificationCompleted = Future<void> Function(
    PhoneAuthCredential credential);
typedef VerificationFailed = void Function(FirebaseAuthException exception);
typedef AutoRetrievalTimeout = void Function(String verificationId);

class PhoneAuthService {
  PhoneAuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Future<void> startVerification({
    required String phoneNumber,
    Duration timeout = const Duration(seconds: 60),
    required CodeSent onCodeSent,
    required VerificationCompleted onVerificationCompleted,
    required VerificationFailed onVerificationFailed,
    required AutoRetrievalTimeout onAutoRetrievalTimeout,
    int? forceResendingToken,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: timeout,
      forceResendingToken: forceResendingToken,
      verificationCompleted: onVerificationCompleted,
      verificationFailed: onVerificationFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: onAutoRetrievalTimeout,
    );
  }

  Future<UserCredential> signInWithCredential(
    PhoneAuthCredential credential, {
    bool linkToCurrentUser = false,
  }) async {
    if (linkToCurrentUser && _auth.currentUser != null) {
      return _auth.currentUser!.linkWithCredential(credential);
    }
    return _auth.signInWithCredential(credential);
  }

  Future<UserCredential> confirmSmsCode({
    required String verificationId,
    required String smsCode,
    bool linkToCurrentUser = false,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    return signInWithCredential(
      credential,
      linkToCurrentUser: linkToCurrentUser,
    );
  }
}
