import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:location_tracker/core/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    if (token != null && token.isNotEmpty) {
      emit(Authenticated());
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

      if (result['success']) {
        emit(LoginSuccess());
      } else {
        emit(AuthFailure(result['message'] ?? 'Login failed'));
      }
    } catch (e) {
      emit(AuthFailure('A network error occurred: $e'));
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

      if (result['success']) {
        emit(RegisterSuccess());
      } else {
        emit(AuthFailure(result['message'] ?? 'Registration failed'));
      }
    } catch (e) {
      emit(AuthFailure('A network error occurred: $e'));
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _apiService.logout();
      emit(Unauthenticated());
    } catch (e) {
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

      if (result['success']) {
        emit(ChangePasswordSuccess());
      } else {
        emit(AuthFailure(result['message'] ?? 'Failed to change password'));
      }
    } catch (e) {
      emit(AuthFailure('An error occurred: $e'));
    }
  }
}
