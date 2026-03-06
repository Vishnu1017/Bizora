import 'dart:async';

import 'package:bizora/features/auth/auth_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bizora/features/auth/auth_event.dart';
import 'package:bizora/repositories/auth_repository.dart';

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
        final role = await repo.googleLogin();
        emit(AuthSuccess(role));
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
          emit(AuthSuccess("customer"));
        } else {
          emit(OtpSent(verificationId));
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

        emit(AuthSuccess(role));
      } catch (e) {
        emit(AuthFailure(e.toString()));
      }
    });
  }
}
