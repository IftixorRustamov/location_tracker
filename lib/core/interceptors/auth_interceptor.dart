import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:location_tracker/core/constants/api_constants.dart';
import 'package:location_tracker/core/constants/storage_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthInterceptor extends Interceptor {
  final Dio _dio;
  final SharedPreferences _prefs;

  // Singleton completer ensures only one refresh happens at a time
  Completer<bool>? _refreshCompleter;

  // Safety valve to prevent infinite refresh loops
  int _refreshAttempts = 0;
  static const int _maxRefreshAttempts = 3;

  AuthInterceptor(this._dio, this._prefs);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_isAuthEndpoint(options.path)) {
      return handler.next(options);
    }

    final token = _prefs.getString(StorageKeys.accessToken);
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401 ||
        _isAuthEndpoint(err.requestOptions.path)) {
      return handler.next(err);
    }

    //  If a refresh is already running, wait for it
    if (_refreshCompleter != null && !_refreshCompleter!.isCompleted) {
      final success = await _refreshCompleter!.future;
      if (success) {
        return _retryRequest(err.requestOptions, handler);
      } else {
        return handler.next(err);
      }
    }

    if (_refreshAttempts >= _maxRefreshAttempts) {
      debugPrint("❌ Max refresh attempts reached. Logging out.");
      _refreshAttempts = 0;
      await _clearSession();
      return handler.next(err);
    }

    _refreshCompleter = Completer<bool>();
    _refreshAttempts++;

    try {
      final success = await _performTokenRefresh();
      _refreshCompleter?.complete(success);

      if (success) {
        _refreshAttempts = 0;
        await _retryRequest(err.requestOptions, handler);
      } else {
        _failAll(err, handler);
      }
    } catch (e) {
      _failAll(err, handler);
    } finally {
      Future.delayed(const Duration(milliseconds: 50), () {
        _refreshCompleter = null;
      });
    }
  }

  Future<bool> _performTokenRefresh() async {
    final refreshToken = _prefs.getString(StorageKeys.refreshToken);
    if (refreshToken == null) return false;

    final tempDio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        headers: {'Content-Type': 'application/json'},
        connectTimeout: const Duration(seconds: 10),
      ),
    );

    try {
      debugPrint("🔄 Refreshing Token...");
      final response = await tempDio.post(
        ApiConstants.refresh,
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200) {
        final data = response.data['data'] ?? response.data;
        final newAccess = data['accessToken'];
        final newRefresh = data['refreshToken'];

        if (newAccess != null) {
          await _prefs.setString(StorageKeys.accessToken, newAccess);
          if (newRefresh != null) {
            await _prefs.setString(StorageKeys.refreshToken, newRefresh);
          }
          return true;
        }
      }
      await _clearSession();
      return false;
    } catch (e) {
      debugPrint("Refresh failed: $e");
      return false;
    }
  }

  Future<void> _retryRequest(
    RequestOptions requestOptions,
    ErrorInterceptorHandler handler,
  ) async {
    final token = _prefs.getString(StorageKeys.accessToken);

    final opts = Options(
      method: requestOptions.method,
      headers: {...requestOptions.headers, 'Authorization': 'Bearer $token'},
    );

    try {
      final response = await _dio.request(
        requestOptions.path,
        data: requestOptions.data,
        queryParameters: requestOptions.queryParameters,
        options: opts,
      );
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  void _failAll(DioException err, ErrorInterceptorHandler handler) {
    if (_refreshCompleter != null && !_refreshCompleter!.isCompleted) {
      _refreshCompleter!.complete(false);
    }
    handler.next(err);
  }

  bool _isAuthEndpoint(String path) {
    return path.contains('/auth/login') ||
        path.contains('/auth/register') ||
        path.contains('/auth/refresh');
  }

  Future<void> _clearSession() async {
    await _prefs.clear();
  }
}
