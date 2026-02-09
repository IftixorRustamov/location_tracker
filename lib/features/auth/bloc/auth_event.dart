abstract class AuthEvent {}

class AppStarted extends AuthEvent {}

class LoginSubmitted extends AuthEvent {
  final String username;
  final String password;

  LoginSubmitted({required this.username, required this.password});
}

class LogoutRequested extends AuthEvent {}

class ChangePasswordRequested extends AuthEvent {
  final String oldPassword;
  final String newPassword;
  final String confirmPassword;

  ChangePasswordRequested({
    required this.oldPassword,
    required this.newPassword,
    required this.confirmPassword,
  });
}

class RegisterSubmitted extends AuthEvent {
  final String name;
  final String username;
  final String password;

  RegisterSubmitted({
    required this.name,
    required this.username,
    required this.password,
  });
}
