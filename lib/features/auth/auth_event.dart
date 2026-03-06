import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object> get props => [];
}

class LoginRequested extends AuthEvent {
  final String email;
  final String password;

  const LoginRequested({required this.email, required this.password});

  @override
  List<Object> get props => [email, password];
}

class GoogleLoginRequested extends AuthEvent {}

class PhoneLoginRequested extends AuthEvent {
  final String phone;

  const PhoneLoginRequested({required this.phone});

  @override
  List<Object> get props => [phone];
}

class VerifyOtpRequested extends AuthEvent {
  final String verificationId;
  final String otp;

  const VerifyOtpRequested({required this.verificationId, required this.otp});

  @override
  List<Object> get props => [verificationId, otp];
}
