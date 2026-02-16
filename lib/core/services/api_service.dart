import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:location_tracker/core/constants/api_constants.dart';
import 'package:location_tracker/core/constants/secondary.dart';
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
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      _log.w(
        "API ERROR [${e.response?.statusCode}]: ${e.requestOptions.path}",
      );
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Xatolik yuz berdi',
      };
    }
  }

  //* tested
  Future<Map<String, dynamic>> register({
    required String name,
    required String username,
    required String password,
  }) async => _handleRequest(
    _dio.post(
      ApiConstants.register,
      data: {'name': name, 'username': username, 'password': password},
    ),
  );

  //* tested
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
          _prefs.setString(
            SecondaryConstants.accessToken,
            data['accessToken'] ?? '',
          ),
          _prefs.setString(
            SecondaryConstants.refreshToken,
            data['refreshToken'] ?? '',
          ),
          _prefs.setString(SecondaryConstants.username, username),
        ]);
        _log.i("LOGIN: Tokens saved.");
      }
    }
    return response;
  }

  //* tested
  Future<Map<String, dynamic>> logout() async {
    try {
      final refreshToken = _prefs.getString(SecondaryConstants.refreshToken);
      final accessToken = _prefs.getString(SecondaryConstants.accessToken);

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
      _log.i("LOGOUT: Local data cleared.");
    }
  }

  Future<bool> refreshToken() async {
    final refreshToken = _prefs.getString(SecondaryConstants.refreshToken);

    if (refreshToken == null || refreshToken.isEmpty) {
      _log.w("REFRESH: No token found.");
      return false;
    }

    try {
      final tempDio = Dio(
        BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          headers: {'Content-Type': 'application/json'},
        ),
      );

      _log.i("REFRESH: Requesting new token...");

      final response = await tempDio.post(
        ApiConstants.refresh,
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200) {
        final responseData = response.data['data'] ?? response.data;
        final newAccess = responseData['accessToken'];
        final newRefresh = responseData['refreshToken'];

        if (newAccess != null) {
          await _prefs.setString(SecondaryConstants.accessToken, newAccess);
          if (newRefresh != null) {
            await _prefs.setString(SecondaryConstants.refreshToken, newRefresh);
          }
          _log.i("TOKEN REFRESH: Success!");
          return true;
        }
      }
    } catch (e) {
      _log.w("REFRESH FAILED: $e");
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

  //* tested
  Future<Map<String, dynamic>> startTrackingSession() async {
    try {
      final response = await _dio.post(ApiConstants.startTracking);

      return {
        'success': true,
        'data': response.data,
        'statusCode': response.statusCode,
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'statusCode': e.response?.statusCode,
        'message': e.response?.data['message'] ?? 'Connection failed',
      };
    }
  }

  //* tested
  Future<Map<String, dynamic>> stopTrackingSession() =>
      _handleRequest(_dio.post(ApiConstants.stopTracking));

  Future<Map<String, dynamic>> sendLocationData(
    List<LocationPoint> points,
  ) async {
    try {
      return await _handleRequest(
        _dio.post(
          ApiConstants.updateLocation,
          data: {"points": points.map((p) => p.toJson()).toList()},
        ),
      );
    } on DioException catch (e) {
      return {
        'success': false,
        'statusCode': e.response?.statusCode,
        'message': e.response?.data['message'] ?? 'Failed to sync',
      };
    }
  }

  bool isLoggedIn() {
    final token = _prefs.getString(SecondaryConstants.accessToken);
    return token != null && token.isNotEmpty;
  }

  String? getUsername() => _prefs.getString(SecondaryConstants.username);
}
