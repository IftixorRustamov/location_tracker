import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
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
    final role = prefs.getString('userRole') ?? 'USER';

    if (token != null && !JwtDecoder.isExpired(token)) {
      emit(Authenticated(token: token, role: role));
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

      debugPrint("🔍 LOGIN RESULT DATA: $result");

      if (result['success'] == true) {
        String token = '';

        // --- FIX: Handle Double Nesting (data -> data -> accessToken) ---

        // 1. Check deeply nested path (Most likely based on your logs)
        if (result['data'] != null &&
            result['data']['data'] != null &&
            result['data']['data']['accessToken'] != null) {
          token = result['data']['data']['accessToken'];
        }

        // 2. Fallback: Standard path (data -> accessToken)
        else if (result['data'] != null && result['data']['accessToken'] != null) {
          token = result['data']['accessToken'];
        }

        // 3. Fallback: Direct root (accessToken)
        else if (result['accessToken'] != null) {
          token = result['accessToken'];
        }

        if (token.isNotEmpty) {
          // --- Role Logic ---
          String userRole = 'USER';
          try {
            Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
            final auths = decodedToken['authorities'] ?? decodedToken['roles'] ?? [];
            if (auths is List) {
              if (auths.contains('ROLE_ADMIN') || auths.contains('ADMIN')) {
                userRole = 'ADMIN';
              }
            }
          } catch (e) {
            debugPrint("⚠️ Token decode failed: $e");
          }

          // Save & Emit
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('accessToken', token);
          await prefs.setString('userRole', userRole);

          emit(Authenticated(token: token, role: userRole));
        } else {
          debugPrint("❌ ERROR: Token not found in any expected path.");
          emit(AuthFailure("Login successful, but token is missing."));
        }
      } else {
        emit(AuthFailure(result['message'] ?? 'Login failed'));
      }
    } catch (e) {
      debugPrint("🔥 EXCEPTION: $e");
      emit(AuthFailure('Login Error: $e'));
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
