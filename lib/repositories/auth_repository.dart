import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  String? _lastPhone;
  DateTime? _lastOtpTime;

  /// ==============================
  /// EMAIL LOGIN
  /// ==============================
  Future<String> login(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final uid = credential.user?.uid;

      if (uid == null) {
        throw Exception("User not found");
      }

      final doc = await _firestore.collection('users').doc(uid).get();

      if (!doc.exists) {
        throw Exception("User data not found. Please signup again.");
      }

      final data = doc.data();

      if (data == null || !data.containsKey('role')) {
        throw Exception("User role missing");
      }

      if (data['role'] == 'owner' && data['isApproved'] == false) {
        throw Exception("Owner account pending admin approval");
      }

      return data['role'];
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw Exception("No account found");
        case 'wrong-password':
          throw Exception("Incorrect password");
        case 'invalid-email':
          throw Exception("Invalid email");
        case 'too-many-requests':
          throw Exception("Too many attempts. Try later");
        default:
          throw Exception(e.message ?? "Login failed");
      }
    }
  }

  /// ==============================
  /// GOOGLE LOGIN
  /// ==============================
  Future<String> signInWithGoogle() async {
    try {
      GoogleSignInAccount? googleUser = _googleSignIn.currentUser;

      googleUser ??= await _googleSignIn.signInSilently();
      googleUser ??= await _googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception("Google sign-in cancelled");
      }

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      final uid = userCredential.user!.uid;

      final docRef = _firestore.collection('users').doc(uid);
      final doc = await docRef.get();

      if (!doc.exists) {
        await docRef.set({
          'email': userCredential.user!.email,
          'role': 'customer',
          'isApproved': true,
          'createdAt': FieldValue.serverTimestamp(),
        });

        return "customer";
      }

      final data = doc.data();

      if (data!['role'] == 'owner' && data['isApproved'] == false) {
        throw Exception("Owner account pending admin approval");
      }

      return data['role'];
    } catch (e) {
      throw Exception("Google login failed");
    }
  }

  Future<String> googleLogin() async {
    return await signInWithGoogle();
  }

  /// ==============================
  /// SEND OTP
  /// ==============================
  Future<void> sendOtp({
    required String phone,
    required Function(String verificationId) onCodeSent,
  }) async {
    try {
      if (_lastPhone == phone && _lastOtpTime != null) {
        final diff = DateTime.now().difference(_lastOtpTime!).inSeconds;

        if (diff < 30) {
          throw Exception(
            "Please wait ${30 - diff}s before requesting OTP again",
          );
        }
      }

      _lastPhone = phone;
      _lastOtpTime = DateTime.now();

      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),

        /// AUTO VERIFY ANDROID
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            final userCredential = await _auth.signInWithCredential(credential);

            final uid = userCredential.user!.uid;

            final docRef = _firestore.collection("users").doc(uid);
            final doc = await docRef.get();

            if (!doc.exists) {
              await docRef.set({
                "phone": userCredential.user!.phoneNumber,
                "role": "customer",
                "isApproved": true,
                "createdAt": FieldValue.serverTimestamp(),
              });
            }

            onCodeSent("AUTO_VERIFIED");
          } catch (e) {
            debugPrint("Auto verification error: $e");
          }
        },

        /// OTP SENT
        codeSent: (verificationId, resendToken) {
          onCodeSent(verificationId);
        },

        verificationFailed: (FirebaseAuthException e) {
          switch (e.code) {
            case "invalid-phone-number":
              throw Exception("Invalid phone number");

            case "too-many-requests":
              throw Exception("Too many requests. Try later.");

            case "quota-exceeded":
              throw Exception("SMS quota exceeded");

            default:
              throw Exception(e.message ?? "OTP verification failed");
          }
        },

        codeAutoRetrievalTimeout: (verificationId) {
          onCodeSent(verificationId);
        },
      );
    } catch (e) {
      rethrow;
    }
  }

  /// ==============================
  /// VERIFY OTP
  /// ==============================
  Future<String> verifyOtp({
    required String verificationId,
    required String otp,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      final uid = userCredential.user!.uid;

      final docRef = _firestore.collection('users').doc(uid);
      final doc = await docRef.get();

      if (!doc.exists) {
        await docRef.set({
          'phone': userCredential.user!.phoneNumber,
          'role': 'customer',
          'isApproved': true,
          'createdAt': FieldValue.serverTimestamp(),
        });

        return "customer";
      }

      final data = doc.data();

      if (data!['role'] == 'owner' && data['isApproved'] == false) {
        throw Exception("Owner account pending admin approval");
      }

      return data['role'];
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case "invalid-verification-code":
          throw Exception("Invalid OTP");

        case "session-expired":
          throw Exception("OTP expired");

        default:
          throw Exception("OTP verification failed");
      }
    }
  }
}
