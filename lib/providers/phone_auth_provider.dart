import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/phone_auth_service.dart';

enum PhoneAuthStep {
  enterPhone,
  codeSent,
  verifyingCode,
  verified,
  error,
}

class PhoneAuthProvider extends ChangeNotifier {
  PhoneAuthProvider(this._service);

  final PhoneAuthService _service;

  PhoneAuthStep step = PhoneAuthStep.enterPhone;
  bool isLoading = false;
  String? verificationId;
  int? resendToken;
  String? errorMessage;
  String? phoneNumber;

  Future<void> sendCode(String phone) async {
    _resetError();
    phoneNumber = phone;
    isLoading = true;
    notifyListeners();

    try {
      await _service.startVerification(
        phoneNumber: phone,
        onCodeSent: (id, token) {
          verificationId = id;
          resendToken = token;
          step = PhoneAuthStep.codeSent;
          isLoading = false;
          notifyListeners();
        },
        onVerificationCompleted: (credential) async {
          // This callback is invoked in two situations:
          // 1 - Instant verification: phone number can be instantly verified
          // 2 - Auto-retrieval: Google Play services automatically detected the SMS
          try {
            await _service.signInWithCredential(credential);
            step = PhoneAuthStep.verified;
            isLoading = false;
            notifyListeners();
          } catch (e) {
            if (e is FirebaseAuthException) {
              // Handle specific error codes
              switch (e.code) {
                case 'invalid-verification-code':
                case 'invalid-credential':
                  errorMessage = 'The verification code entered was invalid.';
                  break;
                case 'too-many-requests':
                  errorMessage = 'Too many requests. Please try again later.';
                  break;
                default:
                  errorMessage = e.message ?? 'Auto-verification failed. Please try again.';
              }
            } else {
              errorMessage = 'Auto-verification failed: $e';
            }
            step = PhoneAuthStep.error;
            isLoading = false;
            notifyListeners();
          }
        },
        onVerificationFailed: (exception) {
          // Handle specific Firebase error codes as per the guide
          switch (exception.code) {
            case 'invalid-phone-number':
            case 'invalid-verification-code':
            case 'invalid-credential':
              errorMessage = 'Invalid phone number format. Please check and try again.';
              break;
            case 'too-many-requests':
              errorMessage = 'Too many requests. Please try again later.';
              break;
            case 'missing-activity-for-recaptcha':
            case 'missing-recaptcha-token':
              errorMessage = 'reCAPTCHA verification requires an activity. Please try again.';
              break;
            default:
              errorMessage = exception.message ?? 'Verification failed. Please try again.';
          }
          step = PhoneAuthStep.error;
          isLoading = false;
          notifyListeners();
        },
        onAutoRetrievalTimeout: (id) {
          verificationId = id;
          isLoading = false;
          notifyListeners();
        },
        forceResendingToken: resendToken,
      );
    } catch (e) {
      errorMessage = 'Failed to start verification: $e';
      step = PhoneAuthStep.error;
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> confirmCode(
    String smsCode, {
    bool linkToCurrentUser = false,
  }) async {
    if (verificationId == null) {
      errorMessage = 'No verificationId. Please request a code first.';
      step = PhoneAuthStep.error;
      notifyListeners();
      return;
    }
    _resetError();
    isLoading = true;
    step = PhoneAuthStep.verifyingCode;
    notifyListeners();

    try {
      await _service.confirmSmsCode(
        verificationId: verificationId!,
        smsCode: smsCode,
        linkToCurrentUser: linkToCurrentUser,
      );
      step = PhoneAuthStep.verified;
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase error codes
      switch (e.code) {
        case 'invalid-verification-code':
        case 'invalid-credential':
          errorMessage = 'The verification code entered was invalid.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many requests. Please try again later.';
          break;
        default:
          errorMessage = e.message ?? 'Invalid code. Please try again.';
      }
      step = PhoneAuthStep.error;
    } catch (e) {
      errorMessage = 'Something went wrong: $e';
      step = PhoneAuthStep.error;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void reset() {
    step = PhoneAuthStep.enterPhone;
    isLoading = false;
    verificationId = null;
    resendToken = null;
    errorMessage = null;
    phoneNumber = null;
    notifyListeners();
  }

  void _resetError() {
    errorMessage = null;
  }
}
