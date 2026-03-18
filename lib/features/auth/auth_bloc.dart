import 'dart:async';

import 'package:bizora/features/auth/auth_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bizora/features/auth/auth_event.dart';
import 'package:bizora/repositories/auth_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository repo;

  AuthBloc(this.repo) : super(AuthInitial()) {
    /// EMAIL LOGIN
    on<LoginRequested>((event, emit) async {
      emit(AuthLoading());

      try {
        final role = await repo.login(event.email, event.password);
        emit(AuthSuccess(role));
      } catch (e) {
        emit(AuthFailure(e.toString()));
      }
    });

    /// GOOGLE LOGIN
    on<GoogleLoginRequested>((event, emit) async {
      emit(AuthLoading());

      try {
        // Get the current user after successful Google login
        final user = FirebaseAuth.instance.currentUser;

        if (user != null) {
          // Save user data to Firestore
          await _saveUserToFirestore(user);

          // Get user role from repository or set default
          String role = "customer"; // Default role

          // You can fetch role from Firestore if needed
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          if (userDoc.exists && userDoc.data()!.containsKey('role')) {
            role = userDoc.data()!['role'] as String;
          }

          emit(AuthSuccess(role));
        } else {
          emit(const AuthFailure('Google Sign-In failed'));
        }
      } catch (e) {
        emit(AuthFailure(e.toString()));
      }
    });

    /// SEND OTP
    on<PhoneLoginRequested>((event, emit) async {
      emit(AuthLoading());

      try {
        final completer = Completer<String>();

        await repo.sendOtp(
          phone: event.phone,
          onCodeSent: (verificationId) {
            if (!completer.isCompleted) {
              completer.complete(verificationId);
            }
          },
        );

        final verificationId = await completer.future;

        if (verificationId == "AUTO_VERIFIED") {
          // Auto-verified - save user data
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            await _saveUserToFirestore(user);
          }
          emit(AuthSuccess("customer"));
        } else {
          emit(
            OtpSent(verificationId: verificationId, phoneNumber: event.phone),
          );
        }
      } catch (e) {
        emit(AuthFailure(e.toString()));
      }
    });

    /// VERIFY OTP
    on<VerifyOtpRequested>((event, emit) async {
      emit(AuthLoading());

      try {
        final role = await repo.verifyOtp(
          verificationId: event.verificationId,
          otp: event.otp,
        );

        // After successful OTP verification, save user data
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await _saveUserToFirestore(user);
        }

        emit(AuthSuccess(role));
      } catch (e) {
        emit(AuthFailure(e.toString()));
      }
    });
  }

  /// Helper method to save user data to Firestore
  Future<void> _saveUserToFirestore(User user) async {
    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      final userDoc = await userRef.get();

      if (!userDoc.exists) {
        // Create new user document
        await userRef.set({
          'uid': user.uid,
          'email': user.email,
          'displayName':
              user.displayName ?? user.email?.split('@')[0] ?? 'User',
          'photoURL': user.photoURL,
          'role': 'customer',
          'isApproved': true,
          'provider': user.providerData.first.providerId,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
          'emailVerified': user.emailVerified,
        });
      } else {
        // Update existing user
        await userRef.update({
          'lastLogin': FieldValue.serverTimestamp(),
          'photoURL': user.photoURL,
          'displayName': user.displayName ?? user.email?.split('@')[0],
          'emailVerified': user.emailVerified,
        });
      }
    } catch (e) {
      // Log error but don't throw - we don't want to break the auth flow
      print('Error saving user to Firestore: $e');
    }
  }
}
