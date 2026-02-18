import 'dart:async';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:location_tracker/core/constants/api_constants.dart';
import 'package:logger/logger.dart';

/// Admin API Service with improved live location streaming
class AdminApiService {
  static final _log = Logger();
  final Dio _dio;

  AdminApiService(this._dio);

  Future<dynamic> _handleRequest(Future<Response> request) async {
    try {
      final response = await request;
      final data = response.data;
      if (data is Map<String, dynamic> && data.containsKey('data')) {
        return data['data'];
      }
      return data;
    } on DioException catch (e) {
      _log.w("ADMIN API ERROR: ${e.response?.statusCode} - ${e.message}");
      return null;
    } catch (e) {
      _log.w("UNKNOWN ERROR: $e");
      return null;
    }
  }

  // ==========================================
  // REAL-TIME LIVE MAP (IMPROVED POLLING)
  // ==========================================

  /// Streams live location updates with improved error handling
  ///
  /// FIXES:
  /// 1. Better error recovery
  /// 2. Proper data extraction from API response
  /// 3. Handles both single and multiple users
  /// 4. Logs detailed debug info
  /// 5. Continues streaming even after errors
  Stream<LiveLocationUpdate> streamAllLiveLocations({
    Duration interval = const Duration(seconds: 2), // Reduced from 3s for better responsiveness
  }) async* {
    int pollCount = 0;
    int errorCount = 0;

    while (true) {
      pollCount++;

      try {
        final response = await _dio.get(
          '/api/v1/sessions/admin/live/users',
          options: Options(
            receiveTimeout: const Duration(seconds: 5),
            sendTimeout: const Duration(seconds: 5),
          ),
        );

        if (response.statusCode == 200) {
          // Reset error count on success
          errorCount = 0;

          // Extract data from response
          final responseData = response.data;
          List<dynamic> rawList = [];

          // Handle different response formats
          if (responseData is Map<String, dynamic>) {
            if (responseData.containsKey('data')) {
              final dataField = responseData['data'];
              if (dataField is List) {
                rawList = dataField;
              } else if (dataField is Map) {
                // Single user wrapped in data object
                rawList = [dataField];
              }
            } else if (responseData.containsKey('content')) {
              // Paginated response
              rawList = responseData['content'] ?? [];
            }
          } else if (responseData is List) {
            rawList = responseData;
          }

          // Yield each user update
          for (var item in rawList) {
            try {
              final update = LiveLocationUpdate.fromJson(item);
              yield update;
            } catch (_) {}
          }

        }
      } on DioException catch (e) {
        errorCount++;
        if (errorCount > 5) {
          _log.e('Live stream: too many errors (${e.type})');
        }
      } catch (e) {
        errorCount++;
      }

      // Wait before next poll
      await Future.delayed(interval);
    }
  }

  /// Get a snapshot of current live users (one-time fetch)
  Future<List<LiveLocationUpdate>> getLiveUsersSnapshot() async {
    try {
      final response = await _dio.get(
        '/api/v1/sessions/admin/live/users',
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

      if (response.statusCode == 200) {
        final responseData = response.data;
        List<dynamic> rawList = [];

        if (responseData is Map<String, dynamic> && responseData.containsKey('data')) {
          rawList = responseData['data'] ?? [];
        } else if (responseData is List) {
          rawList = responseData;
        }

        final users = rawList
            .map((item) {
          try {
            return LiveLocationUpdate.fromJson(item);
          } catch (e) {
            _log.w('Failed to parse user: $e');
            return null;
          }
        })
            .whereType<LiveLocationUpdate>()
            .toList();

        return users;
      }
    } on DioException catch (e) {
      _log.w('Failed to get snapshot: ${e.message}');
    }

    return [];
  }

  // ==========================================
  // DASHBOARD & SESSIONS
  // ==========================================

  Future<AdminSessionResponse?> getSessions({
    required DateTime date,
    int page = 0,
    int size = 20,
  }) async {
    try {
      final String dateStr = DateFormat('yyyy-MM-dd').format(date);
      final result = await _handleRequest(
        _dio.get(
          ApiConstants.getSessions,
          queryParameters: {'date': dateStr, 'page': page, 'size': size},
        ),
      );
      return result != null ? AdminSessionResponse.fromJson(result) : null;
    } catch (e) {
      _log.w("Failed to get sessions: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> getLiveSessionData(String sessionId) async {
    try {
      final result = await _handleRequest(
        _dio.get(
          ApiConstants.getLiveSessionData,
          queryParameters: {'sessionId': sessionId},
        ),
      );
      return result is Map<String, dynamic> ? result : null;
    } catch (e) {
      _log.w("Failed to get live session data: $e");
      return null;
    }
  }

  // ==========================================
  // USER MANAGEMENT
  // ==========================================

  Future<AdminUserResponse?> getUsers({int page = 0, int size = 20}) async {
    try {
      final result = await _handleRequest(
        _dio.get(
          ApiConstants.getUsers,
          queryParameters: {'page': page, 'size': size},
        ),
      );
      return result != null ? AdminUserResponse.fromJson(result) : null;
    } catch (e) {
      _log.w("Failed to get users: $e");
      return null;
    }
  }

  Future<bool> updateUser(int userId, String name, String username) async {
    try {
      await _dio.patch(
        '/api/users/$userId/update',
        data: {"name": name, "username": username},
      );
      return true;
    } catch (e) {
      _log.w("Update User Failed: $e");
      return false;
    }
  }

  Future<List<AdminRole>> getRoles() async {
    try {
      final result = await _handleRequest(_dio.get('/api/roles/all'));
      if (result != null) {
        if (result is Map && result.containsKey('content')) {
          return (result['content'] as List)
              .map((e) => AdminRole.fromJson(e))
              .toList();
        } else if (result is List) {
          return result.map((e) => AdminRole.fromJson(e)).toList();
        }
      }
      return [];
    } catch (e) {
      _log.w("Failed to get roles: $e");
      return [];
    }
  }

  Future<bool> deleteUser(int userId) async {
    try {
      await _dio.delete('/api/users/$userId/delete');
      return true;
    } catch (e) {
      _log.w("Delete User Failed: $e");
      return false;
    }
  }

  Future<String?> assignRoleToUser(int userId, int roleId) async {
    try {
      await _dio.post(
        ApiConstants.assignRoleToUser,
        data: {"userId": userId, "roleIds": [roleId]},
      );
      return null;
    } on DioException catch (e) {
      return e.response?.data['message'] ??
          "Server Error: ${e.response?.statusCode}";
    } catch (e) {
      return "Connection failed";
    }
  }
}

// ==========================================
// MODELS (Improved with better defaults)
// ==========================================

class LiveLocationUpdate {
  final String sessionId;
  final int userId;
  final String username;
  final double lat;
  final double lon;
  final String timestamp;
  final double speed;
  final double accuracy;

  LiveLocationUpdate({
    required this.sessionId,
    required this.userId,
    required this.username,
    required this.lat,
    required this.lon,
    required this.timestamp,
    this.speed = 0.0,
    this.accuracy = 0.0,
  });

  factory LiveLocationUpdate.fromJson(Map<String, dynamic> json) {
    return LiveLocationUpdate(
      sessionId: json['sessionId']?.toString() ??
          json['session_id']?.toString() ??
          '',
      userId: json['userId'] as int? ??
          json['user_id'] as int? ??
          0,
      username: json['username']?.toString() ??
          json['user_name']?.toString() ??
          json['name']?.toString() ??
          'Unknown',
      lat: (json['lat'] as num?)?.toDouble() ??
          (json['latitude'] as num?)?.toDouble() ??
          0.0,
      lon: (json['lon'] as num?)?.toDouble() ??
          (json['longitude'] as num?)?.toDouble() ??
          0.0,
      timestamp: json['timestamp']?.toString() ??
          json['updatedAt']?.toString() ??
          DateTime.now().toIso8601String(),
      speed: (json['speed'] as num?)?.toDouble() ?? 0.0,
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Check if this update has valid coordinates
  bool get hasValidCoordinates {
    return lat != 0.0 && lon != 0.0 &&
        lat.abs() <= 90 && lon.abs() <= 180;
  }

  /// Check if timestamp is recent (within last 5 minutes)
  bool get isRecent {
    try {
      final date = DateTime.parse(timestamp);
      final diff = DateTime.now().toUtc().difference(date);
      return diff.inMinutes < 5;
    } catch (e) {
      return false;
    }
  }

  @override
  String toString() {
    return 'LiveLocationUpdate(user: $username, session: $sessionId, '
        'coords: ($lat, $lon), time: $timestamp)';
  }
}

class AdminSessionResponse {
  final List<AdminSession> content;
  final int totalPages;

  AdminSessionResponse({required this.content, required this.totalPages});

  factory AdminSessionResponse.fromJson(Map<String, dynamic> json) {
    return AdminSessionResponse(
      content: (json['content'] as List?)
          ?.map((e) => AdminSession.fromJson(e))
          .toList() ??
          [],
      totalPages: json['totalPages'] as int? ?? 0,
    );
  }
}

class AdminSession {
  final String id;
  final String name;

  AdminSession({required this.id, required this.name});

  factory AdminSession.fromJson(Map<String, dynamic> json) {
    return AdminSession(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Session',
    );
  }
}

class AdminUserResponse {
  final List<AdminUser> content;
  final int totalPages;

  AdminUserResponse({required this.content, required this.totalPages});

  factory AdminUserResponse.fromJson(Map<String, dynamic> json) {
    return AdminUserResponse(
      content: (json['content'] as List?)
          ?.map((e) => AdminUser.fromJson(e))
          .toList() ??
          [],
      totalPages: json['totalPages'] as int? ?? 0,
    );
  }
}

class AdminUser {
  final int id;
  final String name;
  final String username;
  final List<String> roleNames;

  AdminUser({
    required this.id,
    required this.name,
    required this.username,
    required this.roleNames,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    List<String> roles = [];
    if (json['roles'] != null && json['roles'] is List) {
      roles = (json['roles'] as List).map((r) {
        if (r is Map) return r['name'].toString();
        return r.toString();
      }).toList();
    }
    return AdminUser(
      id: json['id'] as int? ?? 0,
      name: json['name']?.toString() ?? 'No Name',
      username: json['username']?.toString() ?? 'No Username',
      roleNames: roles,
    );
  }
}

class AdminRole {
  final int id;
  final String name;

  AdminRole({required this.id, required this.name});

  factory AdminRole.fromJson(Map<String, dynamic> json) {
    return AdminRole(
      id: json['id'] as int? ?? 0,
      name: json['name']?.toString() ?? 'Unknown',
    );
  }
}