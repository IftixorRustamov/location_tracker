import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:location_tracker/core/services/api_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final ApiService _apiService;

  AuthBloc(this._apiService) : super(AuthInitial()) {
    on<AppStarted>(_onAppStarted);
    on<LoginSubmitted>(_onLoginSubmitted);
    on<RegisterSubmitted>(_onRegisterSubmitted);
    on<LogoutRequested>(_onLogoutRequested);
    on<ChangePasswordRequested>(_onChangePasswordRequested);
  }

  Future<void> _onAppStarted(AppStarted event, Emitter<AuthState> emit) async {
    if (_apiService.isTokenValid()) {
      final role = _apiService.getSavedRole() ?? 'USER';
      emit(Authenticated(token: '', role: role));
    } else {
      emit(Unauthenticated());
    }
  }

  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final result = await _apiService.login(
        username: event.username,
        password: event.password,
      );

      if (result['success'] == true) {
        final token =
            (result['data']?['data']?['accessToken'] as String?) ?? '';

        if (token.isEmpty) {
          emit(AuthFailure('Login succeeded but no token was returned.'));
          return;
        }

        // Decode role from JWT and persist it via ApiService.
        final role = _decodeRole(token);
        await _apiService.saveRole(role);

        emit(Authenticated(token: token, role: role));
      } else {
        emit(AuthFailure(result['message'] ?? 'Login failed'));
      }
    } catch (e) {
      debugPrint('AuthBloc login error: $e');
      emit(AuthFailure('A network error occurred.'));
    }
  }

  Future<void> _onRegisterSubmitted(
    RegisterSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final result = await _apiService.register(
        name: event.name,
        username: event.username,
        password: event.password,
      );

      if (result['success'] == true) {
        emit(RegisterSuccess());
      } else {
        emit(AuthFailure(result['message'] ?? 'Registration failed'));
      }
    } catch (e) {
      emit(AuthFailure('A network error occurred.'));
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _apiService.logout();
    } finally {
      emit(Unauthenticated());
    }
  }

  Future<void> _onChangePasswordRequested(
    ChangePasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final result = await _apiService.changePassword(
        oldPassword: event.oldPassword,
        newPassword: event.newPassword,
        confirmNewPassword: event.confirmPassword,
      );

      if (result['success'] == true) {
        emit(ChangePasswordSuccess());
      } else {
        emit(AuthFailure(result['message'] ?? 'Failed to change password'));
      }
    } catch (e) {
      emit(AuthFailure('An error occurred.'));
    }
  }

  String _decodeRole(String token) {
    try {
      final decoded = JwtDecoder.decode(token);
      final auths = decoded['authorities'] ?? decoded['roles'] ?? [];
      if (auths is List &&
          (auths.contains('ROLE_ADMIN') || auths.contains('ADMIN'))) {
        return 'ADMIN';
      }
    } catch (e) {
      debugPrint('AuthBloc: token decode failed: $e');
    }
    return 'USER';
  }
}
