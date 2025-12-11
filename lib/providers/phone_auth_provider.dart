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
          try {
            await _service.signInWithCredential(credential);
            step = PhoneAuthStep.verified;
          } catch (e) {
            errorMessage = 'Auto-verification failed: $e';
            step = PhoneAuthStep.error;
          }
          isLoading = false;
          notifyListeners();
        },
        onVerificationFailed: (exception) {
          errorMessage = exception.message ?? 'Verification failed';
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
      errorMessage = e.message ?? 'Invalid code';
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
