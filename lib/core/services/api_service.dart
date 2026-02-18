import 'package:dio/dio.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:logger/logger.dart';
import 'package:location_tracker/core/constants/api_constants.dart';
import 'package:location_tracker/core/constants/storage_keys.dart';
import 'package:location_tracker/data/models/location_point.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static final _log = Logger();

  final Dio _dio;
  final SharedPreferences _prefs;

  ApiService(this._dio, this._prefs);

  Future<Map<String, dynamic>> _handleRequest(Future<Response> request) async {
    try {
      final response = await request;
      return {
        'success': true,
        'data': response.data,
        'statusCode': response.statusCode,
      };
    } on DioException catch (e) {
      _log.w('API ERROR [${e.response?.statusCode}]: ${e.requestOptions.path}');
      return {
        'success': false,
        'statusCode': e.response?.statusCode,
        'message': e.response?.data?['message'] ?? 'Network error',
      };
    }
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String username,
    required String password,
  }) => _handleRequest(
    _dio.post(
      ApiConstants.register,
      data: {'name': name, 'username': username, 'password': password},
    ),
  );

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

    if (response['success'] == true) {
      final data = response['data']?['data'] as Map<String, dynamic>?;
      if (data != null) {
        await Future.wait([
          _prefs.setString(StorageKeys.accessToken, data['accessToken'] ?? ''),
          _prefs.setString(
            StorageKeys.refreshToken,
            data['refreshToken'] ?? '',
          ),
          _prefs.setString(StorageKeys.username, username),
        ]);
        _log.i('LOGIN: Tokens saved.');
      }
    }

    return response;
  }

  Future<Map<String, dynamic>> logout() async {
    try {
      final refreshToken = _prefs.getString(StorageKeys.refreshToken);
      final accessToken = _prefs.getString(StorageKeys.accessToken);

      return await _handleRequest(
        _dio.post(
          ApiConstants.logout,
          data: {'refreshToken': refreshToken},
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        ),
      );
    } catch (e) {
      return {'success': true};
    } finally {
      await _prefs.clear();
      _log.i('LOGOUT: Local data cleared.');
    }
  }

  Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
    required String confirmNewPassword,
  }) => _handleRequest(
    _dio.patch(
      ApiConstants.changePassword,
      data: {
        'oldPassword': oldPassword,
        'newPassword': newPassword,
        'confirmNewPassword': confirmNewPassword,
      },
    ),
  );

  Future<Map<String, dynamic>> startTrackingSession() =>
      _handleRequest(_dio.post(ApiConstants.startTracking));

  Future<Map<String, dynamic>> stopTrackingSession() =>
      _handleRequest(_dio.post(ApiConstants.stopTracking));

  Future<Map<String, dynamic>> sendLocationData(List<LocationPoint> points) =>
      _handleRequest(
        _dio.post(
          ApiConstants.updateLocation,
          data: {'points': points.map((p) => p.toJson()).toList()},
        ),
      );

  /// Returns true when a non-expired access token is stored locally.
  bool isTokenValid() {
    final token = _prefs.getString(StorageKeys.accessToken);
    if (token == null || token.isEmpty) return false;
    try {
      return !JwtDecoder.isExpired(token);
    } catch (_) {
      return false;
    }
  }

  String? getSavedRole() => _prefs.getString(StorageKeys.userRole);

  Future<void> saveRole(String role) =>
      _prefs.setString(StorageKeys.userRole, role);

  String? getUsername() => _prefs.getString(StorageKeys.username);
}
