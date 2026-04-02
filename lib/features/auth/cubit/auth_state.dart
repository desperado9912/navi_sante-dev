part of 'auth_cubit.dart';

sealed class AuthState {
  const AuthState();
}

final class AuthInitial extends AuthState {
  const AuthInitial();
}

final class AuthLoading extends AuthState {
  const AuthLoading();
}

final class AuthSuccess extends AuthState {
  const AuthSuccess();
}

final class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
}

final class AuthEmailNotVerified extends AuthState {
  const AuthEmailNotVerified();
}