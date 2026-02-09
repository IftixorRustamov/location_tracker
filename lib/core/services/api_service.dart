import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:location_tracker/core/constants/api_constants.dart';
import 'package:location_tracker/data/models/location_point.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  final Dio _dio;
  final SharedPreferences _prefs;

  static const String _kAccessToken = 'accessToken';
  static const String _kRefreshToken = 'refreshToken';
  static const String _kUsername = 'username';

  ApiService(this._dio, this._prefs);

  Future<Map<String, dynamic>> _handleRequest(Future<Response> request) async {
    try {
      final response = await request;
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      log(
        "API ERROR [${e.response?.statusCode}]: ${e.requestOptions.path}",
        name: "API",
      );
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Xatolik yuz berdi',
      };
    }
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String username,
    required String password,
  }) async {
    return _handleRequest(
      _dio.post(
        ApiConstants.register,
        data: {'name': name, 'username': username, 'password': password},
      ),
    );
  }

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final response = await _handleRequest(
      _dio.post(
        ApiConstants.login,
        data: {'username': username, 'password': password},
      ),
    );

    if (response['success']) {
      final data = response['data']['data'];
      if (data != null) {
        await Future.wait([
          _prefs.setString(_kAccessToken, data['accessToken'] ?? ''),
          _prefs.setString(_kRefreshToken, data['refreshToken'] ?? ''),
          _prefs.setString(_kUsername, username),
        ]);
        log("LOGIN: Tokens saved.", name: "API");
      }
    }
    return response;
  }

  Future<Map<String, dynamic>> logout() async {
    try {
      return await _handleRequest(_dio.post(ApiConstants.logout));
    } finally {
      await _prefs.clear();
      log("LOGOUT: Local data cleared.", name: "API");
    }
  }

  Future<bool> refreshToken() async {
    final refreshToken = _prefs.getString(_kRefreshToken);

    if (refreshToken == null || refreshToken.isEmpty) {
      log("REFRESH: No token found.", name: "API");
      return false;
    }

    try {
      final tempDio = Dio(
        BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          headers: {'Content-Type': 'application/json'},
        ),
      );

      log("REFRESH: Requesting new token...", name: "API");

      final response = await tempDio.post(
        ApiConstants.refresh,
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200) {
        final responseData = response.data['data'] ?? response.data;
        final newAccess = responseData['accessToken'];
        final newRefresh = responseData['refreshToken'];

        if (newAccess != null) {
          await _prefs.setString(_kAccessToken, newAccess);
          if (newRefresh != null) {
            await _prefs.setString(_kRefreshToken, newRefresh);
          }
          log("TOKEN REFRESH: Success!");
          return true;
        }
      }
    } catch (e) {
      log("REFRESH FAILED: $e", name: "API");
    }
    return false;
  }

  Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
    required String confirmNewPassword,
  }) async {
    return _handleRequest(
      _dio.patch(
        ApiConstants.changePassword,
        data: {
          'oldPassword': oldPassword,
          'newPassword': newPassword,
          'confirmNewPassword': confirmNewPassword,
        },
      ),
    );
  }

  Future<Map<String, dynamic>> startTrackingSession() =>
      _handleRequest(_dio.post(ApiConstants.startTracking));

  Future<Map<String, dynamic>> stopTrackingSession() =>
      _handleRequest(_dio.post(ApiConstants.stopTracking));

  Future<Map<String, dynamic>> sendLocationData(List<LocationPoint> points) {
    final data = {'points': points.map((p) => p.toJson()).toList()};

    return _handleRequest(_dio.post(ApiConstants.updateLocation, data: data));
  }

  bool isLoggedIn() {
    final token = _prefs.getString(_kAccessToken);
    return token != null && token.isNotEmpty;
  }

  String? getUsername() => _prefs.getString(_kUsername);
}
