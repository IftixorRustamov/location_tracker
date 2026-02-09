import 'package:dio/dio.dart';
import 'package:location_tracker/core/di/injection_container.dart';
import 'package:location_tracker/core/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthInterceptor extends Interceptor {
  final Dio _dio;
  final SharedPreferences _prefs;

  bool _isRefreshing = false;

  final List<Map<String, dynamic>> _failedRequests = [];

  AuthInterceptor(this._dio, this._prefs);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.path.contains('/auth/')) {
      return handler.next(options);
    }

    final token = _prefs.getString('accessToken');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401 ||
        err.requestOptions.path.contains('/auth/refresh')) {
      return handler.next(err);
    }

    if (_isRefreshing) {
      _failedRequests.add({'options': err.requestOptions, 'handler': handler});
      return;
    }

    _isRefreshing = true;

    try {
      final success = await sl<ApiService>().refreshToken();

      if (success) {
        await _prefs.reload();
        final newToken = _prefs.getString('accessToken');
        _retry(err.requestOptions, handler, newToken!);
        for (var req in _failedRequests) {
          _retry(req['options'], req['handler'], newToken);
        }
      } else {
        _failAll(err, handler);
      }
    } catch (_) {
      _failAll(err, handler);
    } finally {
      _isRefreshing = false;
      _failedRequests.clear();
    }
  }

  // --- Helpers ---
  Future<void> _retry(
    RequestOptions requestOptions,
    ErrorInterceptorHandler handler,
    String newToken,
  ) async {
    final opts = Options(
      method: requestOptions.method,
      headers: Map.of(requestOptions.headers)
        ..['Authorization'] = 'Bearer $newToken',
    );

    try {
      final response = await _dio.request(
        requestOptions.path,
        options: opts,
        data: requestOptions.data,
        queryParameters: requestOptions.queryParameters,
      );
      handler.resolve(response);
    } catch (e) {
      if (e is DioException) handler.next(e);
    }
  }

  void _failAll(DioException err, ErrorInterceptorHandler handler) {
    handler.next(err);
    for (var req in _failedRequests) {
      req['handler'].next(err);
    }
  }
}
