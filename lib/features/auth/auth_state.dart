import 'package:equatable/equatable.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthSuccess extends AuthState {
  final String role;

  const AuthSuccess(this.role);

  @override
  List<Object> get props => [role];
}

class OtpSent extends AuthState {
  final String verificationId;

  const OtpSent(this.verificationId);

  @override
  List<Object> get props => [verificationId];
}

class AuthFailure extends AuthState {
  final String message;

  const AuthFailure(this.message);

  @override
  List<Object> get props => [message];
}
