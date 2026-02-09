abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class LoginSuccess extends AuthState {}

class RegisterSuccess extends AuthState {}

class Unauthenticated extends AuthState {}

class Authenticated extends AuthState {}

class ChangePasswordSuccess extends AuthState {}

class AuthFailure extends AuthState {
  final String message;

  AuthFailure(this.message);
}
