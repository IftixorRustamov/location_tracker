import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:location_tracker/core/constants/api_constants.dart';
import 'package:logger/logger.dart';

/// PERFORMANCE OPTIMIZATIONS:
/// 1. ✅ Better SSE stream error handling
/// 2. ✅ Automatic reconnection logic
/// 3. ✅ Memory leak prevention
/// 4. ✅ Proper stream disposal
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
      _log.w(
        "ADMIN API ERROR: ${e.response?.statusCode} - ${e.message}",
      );
      return null;
    } catch (e) {
      _log.w("UNKNOWN ERROR: $e");
      return null;
    }
  }

  // ==========================================
  // REAL-TIME LIVE MAP (SSE) - OPTIMIZED
  // ==========================================

  /// Stream live location updates with automatic reconnection
  Stream<LiveLocationUpdate> streamAllLiveLocations() {
    return _createSseStream();
  }

  /// OPTIMIZATION: Separate stream creation for better error handling
  Stream<LiveLocationUpdate> _createSseStream() async* {
    int reconnectAttempts = 0;
    const maxReconnectAttempts = 5;
    const reconnectDelay = Duration(seconds: 3);

    while (reconnectAttempts < maxReconnectAttempts) {
      try {
        _log.i("Connecting to SSE Stream (attempt ${reconnectAttempts + 1})...");

        final response = await _dio.get(
          '/api/v1/sessions/admin/live/all',
          options: Options(
            responseType: ResponseType.stream,
            headers: {
              'Accept': 'text/event-stream',
              'Cache-Control': 'no-cache',
              'Connection': 'keep-alive',
            },
            // OPTIMIZATION: Add timeout to prevent hanging
            receiveTimeout: const Duration(seconds: 30),
          ),
        );

        _log.i("SSE Stream connected");
        reconnectAttempts = 0; // Reset on successful connection

        // OPTIMIZATION: Better stream handling with proper error recovery
        final stream = (response.data.stream as Stream<List<int>>)
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .handleError((error) {
          _log.w("Stream error: $error");
        });

        await for (final line in stream) {
          if (line.startsWith('data:')) {
            try {
              final jsonStr = line.substring(5).trim();
              if (jsonStr.isNotEmpty && jsonStr != 'ping') {
                final json = jsonDecode(jsonStr);
                yield LiveLocationUpdate.fromJson(json);
              }
            } catch (e) {
              _log.w("Parse Error: $e");
              // Continue processing other events
            }
          } else if (line.startsWith(':')) {
            // Ignore SSE comments (heartbeat)
            continue;
          }
        }

        // Stream ended normally, break the loop
        _log.i("SSE Stream ended normally");
        break;

      } on DioException catch (e) {
        reconnectAttempts++;
        _log.w(
          "SSE Connection failed (attempt $reconnectAttempts): ${e.message}",
        );

        if (reconnectAttempts >= maxReconnectAttempts) {
          _log.w("Max reconnection attempts reached");
          throw Exception("SSE connection failed after $maxReconnectAttempts attempts");
        }

        // Wait before reconnecting
        await Future.delayed(reconnectDelay * reconnectAttempts);

      } catch (e) {
        reconnectAttempts++;
        _log.w("SSE Stream Error: $e");

        if (reconnectAttempts >= maxReconnectAttempts) {
          throw Exception("SSE connection failed: $e");
        }

        await Future.delayed(reconnectDelay);
      }
    }
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
      if (result is Map<String, dynamic>) return result;
      return null;
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
      _log.i("User $userId updated successfully");
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
      _log.i("User $userId deleted successfully");
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
        data: {
          "userId": userId,
          "roleIds": [roleId],
        },
      );
      _log.i("Role $roleId assigned to user $userId");
      return null; // Success
    } on DioException catch (e) {
      final errorMsg = e.response?.data['message'] ??
          "Server Error: ${e.response?.statusCode}";
      _log.w("Assign role failed: $errorMsg");
      return errorMsg;
    } catch (e) {
      _log.w("Assign role failed: $e");
      return "Connection failed";
    }
  }
}

// ==========================================
// MODELS
// ==========================================

class LiveLocationUpdate {
  final String sessionId;
  final double lat;
  final double lon;
  final double speed;
  final double accuracy;
  final String timestamp;

  LiveLocationUpdate({
    required this.sessionId,
    required this.lat,
    required this.lon,
    this.speed = 0.0,
    this.accuracy = 0.0,
    required this.timestamp,
  });

  factory LiveLocationUpdate.fromJson(Map<String, dynamic> json) {
    try {
      return LiveLocationUpdate(
        sessionId: json['sessionId']?.toString() ?? '',
        lat: (json['lat'] as num).toDouble(),
        lon: (json['lon'] as num).toDouble(),
        speed: (json['speed'] as num?)?.toDouble() ?? 0.0,
        accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0.0,
        timestamp: json['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
      );
    } catch (e) {
      debugPrint('❌ Failed to parse LiveLocationUpdate: $e');
      rethrow;
    }
  }

  @override
  String toString() => 'LiveLocationUpdate(session: $sessionId, lat: $lat, lon: $lon)';
}

class AdminSessionResponse {
  final List<AdminSession> content;
  final int totalPages;

  AdminSessionResponse({required this.content, required this.totalPages});

  factory AdminSessionResponse.fromJson(Map<String, dynamic> json) {
    try {
      return AdminSessionResponse(
        content: (json['content'] as List?)
            ?.map((e) => AdminSession.fromJson(e))
            .toList() ??
            [],
        totalPages: json['totalPages'] as int? ?? 0,
      );
    } catch (e) {
      debugPrint('❌ Failed to parse AdminSessionResponse: $e');
      rethrow;
    }
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
    try {
      return AdminUserResponse(
        content: (json['content'] as List?)
            ?.map((e) => AdminUser.fromJson(e))
            .toList() ??
            [],
        totalPages: json['totalPages'] as int? ?? 0,
      );
    } catch (e) {
      debugPrint('❌ Failed to parse AdminUserResponse: $e');
      rethrow;
    }
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

    try {
      if (json['roles'] != null && json['roles'] is List) {
        roles = (json['roles'] as List).map((r) {
          if (r is Map) return r['name'].toString();
          return r.toString();
        }).toList();
      }
    } catch (e) {
      debugPrint('⚠️ Failed to parse user roles: $e');
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